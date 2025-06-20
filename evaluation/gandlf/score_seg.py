#!/usr/bin/env python3
"""Scoring script for Tasks 1-7 (segmentation).

Run Panoptica computation and return:
  - Dice
  - Normalized surface distance
"""
import argparse
import json
import os
import re
import subprocess

import pandas as pd
import synapseclient
import utils

PRED_PARENT_DIR = "pred"
GT_PARENT_DIR = "gt"


def get_args():
    """Set up command-line interface and get arguments."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--parent_id", type=str, required=True)
    parser.add_argument("-s", "--synapse_config", type=str, default="/.synapseConfig")
    parser.add_argument("-p", "--predictions_file",
                        type=str, default="/predictions.zip")
    parser.add_argument("-g", "--groundtruth_file",
                        type=str, default="/groundtruth.zip")
    parser.add_argument("-g2", "--second_groundtruth_file", type=str)
    parser.add_argument("-c", "--gandlf_config",
                        type=str, default="/gandlf_config.yaml")
    parser.add_argument("-o", "--output", type=str, default="results.json")
    parser.add_argument("-l", "--label", type=str, default="BraTS-GLI")
    parser.add_argument("--subject_id_pattern",
                        type=str, default=r"(BraTS.*\d{4,5}-\d{1,3})")
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
):
    """Create 3-col CSV file to use as input to GaNDLF."""
    preds_df = pd.DataFrame(pred_filepaths, columns=["Prediction"])
    preds_df["Prediction"] = f"{PRED_PARENT_DIR}/" + preds_df["Prediction"]
    preds_df["SubjectID"] = _extract_value_by_pattern(
        preds_df.loc[:, "Prediction"], subject_id_pattern
    )
    gt_df = pd.DataFrame(gt_filepaths, columns=["Target"])
    gt_df["Target"] = f"{GT_PARENT_DIR}/" + gt_df["Target"]
    gt_df["SubjectID"] = _extract_value_by_pattern(
        gt_df.loc[:, "Target"], subject_id_pattern
    )

    # Keep merge as "inner" join so that there is always 1:1 between
    # prediction filepath and gt filepath.
    res = gt_df.merge(preds_df, on="SubjectID")
    res.to_csv(out_file, index=False)


def extract_metrics(gandlf_results: str) -> pd.DataFrame:
    """Convert results in JSON format into dataframe."""
    with open(gandlf_results) as f:
        metrics = json.load(f)
    res = pd.json_normalize(metrics.values())
    res["scan_id"] = metrics.keys()
    res.columns = [col.replace(".", "_") for col in res.columns]
    return res.set_index("scan_id")


def upload_results(parent_id, results):
    """Upload individual scores as CSV files to Synapse."""
    results.to_csv("all_scores.csv")
    csv = synapseclient.File("all_scores.csv", parent=parent_id)
    csv = syn.store(csv)
    return csv.id


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
    if args.second_groundtruth_file:
        truths.extend(
            utils.inspect_archive(
                args.second_groundtruth_file,
                dest_path=GT_PARENT_DIR,
            )
        )

    gandlf_input_file = "tmp.csv"
    create_gandlf_input(
        preds,
        truths,
        out_file=gandlf_input_file,
        subject_id_pattern=args.subject_id_pattern,
    )

    gandlf_output_file = "tmp.json"
    run_gandlf(args.gandlf_config, gandlf_input_file, gandlf_output_file)
    results = extract_metrics(gandlf_output_file)

    # Get number of segmentations predicted by participant, as well as
    # descriptive statistics for results.
    cases_evaluated = len(results.index)
    metrics = (
        results.describe()
        .rename(index={"25%": "25quantile", "50%": "median", "75%": "75quantile"})
        .drop(["count", "min", "max"])
    )
    results = pd.concat([results, metrics])
    csv_id = upload_results(args.parent_id, results)

    # Filter for relevant metrics to annotate submission, since Synapse only
    # allows for max of 100 annotations per entity.
    filtered_cols = [
        colname
        for colname in results.columns
        if "dsc" in colname or "nsd" in colname
    ]
    res_dict = {
        **results.loc["mean", filtered_cols],
        "cases_evaluated": cases_evaluated,
        "submission_scores": csv_id,
        "submission_status": "SCORED",
    }
    res_dict = {k: v for k, v in res_dict.items() if not pd.isna(v)}
    with open(args.output, "w") as out:
        out.write(json.dumps(res_dict))


if __name__ == "__main__":
    args = get_args()

    syn = synapseclient.Synapse(configPath=args.synapse_config)
    syn.login(silent=True)

    main(args)
