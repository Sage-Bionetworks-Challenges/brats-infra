#!/usr/bin/env python3
"""Scoring script for BraTS 2025 Task 4 (BraTS-MET)

Run Panoptica computation and return:
  - Dice
  - Normalized surface distance
"""
import argparse
import json
import subprocess

import pandas as pd

import numpy as np
import synapseclient
import utils

PRED_PARENT_DIR = "pred"
GT_PARENT_DIR = "gt"


def get_args():
    """Set up command-line interface and get arguments."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--parent_id", type=str, required=True)
    parser.add_argument("--private_parent_id", type=str, required=True)
    parser.add_argument("-s", "--synapse_config", type=str, default="/.synapseConfig")
    parser.add_argument("-p", "--predictions_file",
                        type=str, default="/predictions.zip")
    parser.add_argument("-g", "--groundtruth_file",
                        type=str, default="/groundtruth.zip")
    parser.add_argument("-g2", "--second_goldstandard_file",
                        type=str)
    parser.add_argument("-c", "--gandlf_config",
                        type=str, default="/gandlf_config.yaml")
    parser.add_argument("-o", "--output", type=str, default="results.json")
    parser.add_argument("--subject_id_pattern",
                        type=str, default=r"((BraTS.*?)?-?\d{4,5}-\d{1,3})")
    parser.add_argument("-l", "--label", type=str, default="BraTS-GLI")
    return parser.parse_args()


def run_gandlf(config_file, input_file, output_file):
    """
    Run GanDLF BraTS segmentation metrics computations.
    https://docs.mlcommons.org/GaNDLF/usage/#special-cases
    """
    cmd = [
        "gandlf", "generate-metrics",
        "-c", config_file,
        "-i", input_file,
        "-o", output_file,
    ]
    subprocess.check_call(cmd)


def _extract_value_by_pattern(col, pattern_to_extract):
    """Return specific content from column, specified by pattern."""
    return col.str.extract(pattern_to_extract)


def create_gandlf_input(
    pred_filepaths: list,
    gt_filepaths: list,
    out_file: str,
    subject_id_pattern: str,
    add_missing_label: bool,
    cohort_label: str,
):
    """Create 3-col CSV file to use as input to GaNDLF."""
    preds_df = pd.DataFrame(pred_filepaths, columns=["Prediction"])
    preds_df["Prediction"] = f"{PRED_PARENT_DIR}/" + preds_df["Prediction"]
    preds_df["SubjectID"] = _extract_value_by_pattern(
        preds_df.loc[:, "Prediction"], subject_id_pattern
    )[0]

    if add_missing_label:
        # If missing, add cohort label to prediction SubjectID.
        missing_labels = ~preds_df["SubjectID"].str.contains(cohort_label)
        preds_df.loc[missing_labels, "SubjectID"] = f"{cohort_label}-" + \
            preds_df.loc[missing_labels, "SubjectID"]

    gt_df = pd.DataFrame(gt_filepaths, columns=["Target"])
    gt_df["Target"] = f"{GT_PARENT_DIR}/" + gt_df["Target"]
    gt_df["SubjectID"] = _extract_value_by_pattern(
        gt_df.loc[:, "Target"], subject_id_pattern
    )[0]

    # Keep merge as "inner" join so that there is always 1:1 between
    # prediction filepath and gt filepath.
    res = gt_df.merge(preds_df, on="SubjectID")
    res.to_csv(out_file, index=False)


def extract_metrics(gandlf_results: str) -> pd.DataFrame:
    """
    Convert results in JSON format into dataframe and get specific metrics
    for specific tissues.
    """
    select_cols = "|".join([
        "num_ref_instances",
        "num_pred_instances",
        "tp",
        "fp",
        "fn",
        "prec",
        "rec",
        "rq",
        "sq_dsc",
        "sq_dsc_std",
        "pq_dsc",
        "sq_hd95",
        "sq_hd95_std",
        "sq_nsd",
        "sq_nsd_std",
        "global_bin_dsc",
        "global_bin_hd95",
        "global_bin_nsd",
    ])
    # tissues = "|".join([
    #     "et",
    #     "rc",
    #     "tc",
    #     "wt",
    # ])
    with open(gandlf_results) as f:
        metrics = json.load(f)
    df = pd.json_normalize(metrics.values())
    df["scan_id"] = metrics.keys()
    res = (
        df.set_index("scan_id")
        .filter(regex=select_cols, axis=1)
        # .filter(regex=tissues, axis=1)
    )
    res.columns = [col.replace(".", "_") for col in res.columns]
    return res


def upload_results(parent_id, private_parent_id, results):
    """Upload individual scores as CSV files to Synapse."""

    # For participants, only output the subject-wise scores.
    results.filter(regex="_(global_bin_dsc|global_bin_nsd)$", axis=1).to_csv("all_scores.csv")
    csv = synapseclient.File("all_scores.csv", parent=parent_id)
    csv = syn.store(csv)

    # For organizers, output all scores.
    results.to_csv("panoptica_scores.csv")
    private_csv = synapseclient.File("panoptica_scores.csv", parent=private_parent_id)
    private_csv = syn.store(private_csv)

    return csv.id, private_csv.id


def main(args):
    """Main function."""
    preds = utils.inspect_archive(
        args.predictions_file,
        dest_path=PRED_PARENT_DIR,
    )
    truths = utils.inspect_archive(
        args.groundtruth_file,
        dest_path=GT_PARENT_DIR,
    )
    if args.second_goldstandard_file:
        truths.extend(
            utils.inspect_archive(
                args.second_goldstandard_file,
                dest_path=GT_PARENT_DIR,
            )
        )

    gandlf_input_file = "tmp.csv"
    create_gandlf_input(
        preds,
        truths,
        out_file=gandlf_input_file,
        subject_id_pattern=args.subject_id_pattern,
        add_missing_label=(args.label == "BraTS-MET"),
        cohort_label=args.label,
    )

    gandlf_output_file = "tmp.json"
    run_gandlf(args.gandlf_config, gandlf_input_file, gandlf_output_file)
    results = extract_metrics(gandlf_output_file)

    # Replace any NaN in DSC and NSD to 1, and HD95 to 0; Inf in DSC and NSD
    # to 0, and HD95 to 374.
    cols_dsc_nsd = results.filter(regex=r"(dsc|nsd)$").columns
    cols_hd95 = results.filter(regex=r"hd95$", axis=1).columns
    results[cols_dsc_nsd] = (
        results[cols_dsc_nsd]
        .fillna(1)  # Replace NaN with 1
        .replace([np.inf], 0)
    )
    results[cols_hd95] = (
        results[cols_hd95]
        .fillna(0)  # Replace NaN with 0
        .replace([np.inf], 374)
    )

    # Per organizer request: add penalty scores for cases where the
    # participant did not provide a prediction. The worst possible
    # scores are 337/374 for HD95 (task-dependent), and 0 for everything else.
    truth_labels = {filename.replace("-seg.nii.gz", "") for filename in truths}
    missing_scan_ids = truth_labels - set(results.index)
    if missing_scan_ids:
        penalty_scores = {
            col: (
                374
                if "hd95" in col 
                else 0
            )
            for col in results.columns
        }
        penalized_preds = pd.DataFrame(penalty_scores, index=list(missing_scan_ids))
        results = pd.concat([results, penalized_preds])

    # Get number of segmentations predicted by participant, as well as
    # descriptive statistics for results.
    cases_evaluated = len(results.index)
    metrics = (
        results.describe()
        .rename(index={"25%": "25quantile", "50%": "median", "75%": "75quantile"})
        .drop(["count", "min", "max"])
    )
    results = pd.concat([results, metrics])
    csv_id, private_csv_id = upload_results(
        args.parent_id,
        args.private_parent_id,
        results,
    )

    # Filter for relevant metrics to annotate submission, since Synapse only
    # allows for max of 100 annotations per entity.
    filtered_cols = [
        colname
        for colname in results.columns
        if "global_bin_dsc" in colname or "global_bin_nsd" in colname
    ]
    res_dict = {
        **results.loc["mean", filtered_cols],
        "cases_evaluated": cases_evaluated,
        "submission_scores": csv_id,
        "submission_status": "SCORED",
        "full_panoptica_scores": private_csv_id,
    }
    res_dict = {k: v for k, v in res_dict.items() if not pd.isna(v)}
    with open(args.output, "w") as out:
        out.write(json.dumps(res_dict))


if __name__ == "__main__":
    args = get_args()

    syn = synapseclient.Synapse(configPath=args.synapse_config)
    syn.login(silent=True)

    main(args)
