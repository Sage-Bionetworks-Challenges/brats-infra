#!/usr/bin/env python3
"""Scoring script for BraTS pathology task.

Run classification computation and return:
  - Accuracy
  - AUROC
  - MCC
  - F1
  - Sensitivity
  - Specificity
"""

import argparse
import json
import subprocess

import pandas as pd
import synapseclient

METRICS_TO_RETURN = [
    "mcc",
    "f1_per_class_average",
    "accuracy_global",
    "specificity_per_class_weighted",
    "recall_per_class_average",
    "auroc_per_class_weighted",
]


def get_args():
    """Set up command-line interface and get arguments."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--parent_id", type=str, required=True)
    parser.add_argument(
        "-p", "--predictions_file", type=str, default="/predictions.csv"
    )
    parser.add_argument(
        "-g", "--goldstandard_file", type=str, default="/goldstandard.csv"
    )
    parser.add_argument(
        "-c", "--gandlf_config", type=str, default="/gandlf_config.yaml"
    )
    parser.add_argument("-o", "--output", type=str, default="results.json")
    parser.add_argument("--penalty_label", type=int, default=None)
    parser.add_argument("--subject_id_pattern", type=str, required=True)
    return parser.parse_args()


def run_gandlf(config_file, input_file, output_file):
    """
    Run GaNDLF classification metrics computations.
    """
    cmd = [
        "gandlf",
        "generate-metrics",
        "-c",
        config_file,
        "-i",
        input_file,
        "-o",
        output_file,
    ]
    subprocess.check_call(cmd)


def _extract_value_by_pattern(col, pattern_to_extract):
    """Return specific content from column, specified by pattern."""
    return col.str.extract(pattern_to_extract)


def create_gandlf_input(pred_file, gold_file, out_file, penalty_label, pattern):
    """
    Create 3-col CSV file to use as input to GaNDLF.
    """

    # Extract only the filename from SubjectID for easier joins.
    filename_pattern = rf"({pattern})"
    pred = pd.read_csv(pred_file)
    pred["SubjectID"] = _extract_value_by_pattern(
        pred.loc[:, "SubjectID"], filename_pattern
    )
    gold = pd.read_csv(gold_file).rename(columns={"Name": "SubjectID", "GT": "Target"})
    gold["SubjectID"] = _extract_value_by_pattern(
        gold.loc[:, "SubjectID"], filename_pattern
    )

    # If penalty needs to be applied, do a left join then assign
    # penalty label to any missing subject IDs in prediction.
    if penalty_label:
        res = gold.merge(pred, how="left", on="SubjectID").fillna(penalty_label)

        # Reassign coltype to int, since NaN values will convert
        # coltype to float.
        res["Prediction"] = res["Prediction"].astype(int)
    else:
        res = gold.merge(pred, on="SubjectID")
    res.to_csv(out_file, index=False)


def main():
    """Main function."""
    args = get_args()

    gandlf_input_file = "tmp.csv"
    create_gandlf_input(
        args.predictions_file,
        args.goldstandard_file,
        out_file=gandlf_input_file,
        penalty_label=args.penalty_label,
        pattern=args.subject_id_pattern,
    )

    gandlf_output_file = "gandlf_metrics.json"
    run_gandlf(args.gandlf_config, gandlf_input_file, gandlf_output_file)

    # Upload full GaNDLF metrics JSON to the private folder.
    syn = synapseclient.Synapse(configPath=args.gandlf_config)
    syn.login(silent=True)
    private_file = synapseclient.File(gandlf_output_file, parent=args.parent_id)
    private_file = syn.store(private_file)       

    with open(gandlf_output_file, encoding="utf-8") as f, \
         open(args.output, "w", encoding="utf-8") as out:
        metrics = json.load(f)
        results = {
            metric: score
            for metric, score in metrics.items()
            if metric in METRICS_TO_RETURN
        }
        json.dump(
            {
                **results,
                "submission_status": "SCORED",
                "summary_json": private_file.id,
            },
            out,
        )


if __name__ == "__main__":
    main()
