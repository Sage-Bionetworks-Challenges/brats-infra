#!/usr/bin/env python3
"""Scoring script for BraTS segmentation tasks.

Uses the BraTS-evaluation package (brats-evaluate + brats-parse-metrics)
to compute panoptica-based segmentation metrics:
  - Lesionwise DSC, HD95, NSD
  - Instance-level TP, FP, FN, F1
"""

import argparse
import json
import os
import subprocess
import tempfile

import pandas as pd
import synapseclient

import utils

PRED_PARENT_DIR = "pred"
GT_PARENT_DIR = "ref"

# Maps cohort label → config for brats-evaluate
EVALUATION_CONFIG = {
    "BraTS-MET": "mets",
    "BraTS-PED": "ped",
    "BraTS-GoAT": "GoAT",
}


def get_args():
    """Set up command-line interface and get arguments."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--parent_id", type=str, required=True)
    parser.add_argument("--private_parent_id", type=str, required=True)
    parser.add_argument("-s", "--synapse_config", type=str, default="/.synapseConfig")
    parser.add_argument(
        "-p", "--predictions_file", type=str, default="/predictions.zip"
    )
    parser.add_argument(
        "-g", "--goldstandard_file", type=str, default="/goldstandard.zip"
    )
    parser.add_argument("-l", "--label", type=str, required=True)
    parser.add_argument("-o", "--output", type=str, default="results.json")
    return parser.parse_args()


def run_evaluate(config, ref_path, pred_path, output_json):
    """Run brats-evaluate to produce raw panoptica metrics JSON."""
    subprocess.check_call(
        [
            "brats-evaluate",
            "--config",
            config,
            "--ref_path",
            ref_path,
            "--pred_path",
            pred_path,
            "--summary_json",
            output_json,
        ]
    )


def run_parse_metrics(cohort, json_path, output_csv):
    """Run brats-parse-metrics to produce per-subject summary CSV."""
    match cohort:
        case "BraTS-MET":
            subcommand = ["mets", "--vol_threshold", "27", "--overlap_threshold", "0.2"]
        case "BraTS-PED" | "BraTS-GoAT":
            subcommand = ["seg"]
        case _:
            raise ValueError(f"Unexpected cohort label: {cohort}")

    subprocess.check_call(
        [
            "brats-parse-metrics",
        ]
        + subcommand
        + [
            "--json_path",
            json_path,
            "--output_csv_path",
            output_csv,
        ]
    )


def main():
    """Main function."""
    args = get_args()
    eval_config = EVALUATION_CONFIG.get(args.label, args.label.lower())

    utils.inspect_archive(args.predictions_file, path=PRED_PARENT_DIR)
    utils.inspect_archive(args.goldstandard_file, path=GT_PARENT_DIR)

    metrics_json = "panoptica_metrics.json"
    summary_csv = "all_scores.csv"

    run_evaluate(eval_config, GT_PARENT_DIR, PRED_PARENT_DIR, metrics_json)
    run_parse_metrics(args.label, metrics_json, summary_csv)

    syn = synapseclient.Synapse(configPath=args.synapse_config)
    syn.login(silent=True)

    # Upload full panoptica metrics JSON to the private folder.
    private_file = synapseclient.File(metrics_json, parent=args.private_parent_id)
    private_file = syn.store(private_file)

    # Upload per-subject summary CSV to the submitter folder.
    csv_file = synapseclient.File(summary_csv, parent=args.parent_id)
    csv_file = syn.store(csv_file)

    df = pd.read_csv(summary_csv)
    mean_row = df[df.iloc[:, 0] == "mean"].iloc[0]
    mean_metrics = {
        col: float(mean_row[col])
        for col in df.columns[1:]  # skip subject_id column
        if pd.notna(mean_row[col])
    }

    with open(args.output, "w", encoding="utf-8") as out:
        json.dump(
            {
                **mean_metrics,
                "submission_scores": csv_file.id,
                "summary_json": private_file.id,
                "submission_status": "SCORED",
            },
            out,
        )


if __name__ == "__main__":
    main()
