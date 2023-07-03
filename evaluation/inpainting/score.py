#!/usr/bin/env python3
"""Scoring script for Task 8.

Compute the following metrics for the inpainted images:
  - Structural similarity index measure (SSIM)
  - Peak-signal-to-noise-ratio (PSNR)
  - Mean-square-error (MSE)
"""
import os
import re
import argparse
import json

import nibabel as nib
import torch
import pandas as pd
import synapseclient

import utils
import evaluation_utils

def get_args():
    """Set up command-line interface and get arguments."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--parent_id",
                        type=str, required=True)
    parser.add_argument("-s", "--synapse_config",
                        type=str, default="/.synapseConfig")
    parser.add_argument("-p", "--predictions_file",
                        type=str, default="/predictions.zip")
    parser.add_argument("-g", "--goldstandard_file",
                        type=str, default="/goldstandard.zip")
    parser.add_argument("-m", "--healthy_masks",
                        type=str, default="/masks.zip")
    parser.add_argument("-o", "--output",
                        type=str, default="results.json")
    parser.add_argument("-l", "--label",
                        type=str, default="BraTS-GLI")
    return parser.parse_args()


def calculate_metrics(result, mask, gold):
    """
    Run inpainting computation of prediction scan against
    goldstandard and healthy mask.
    """
    pred_img = nib.load(result)
    pred = torch.Tensor(pred_img.get_fdata()).unsqueeze(0).unsqueeze(0)

    # Inference mask
    mask_img = nib.load(mask)
    mask = torch.Tensor(mask_img.get_fdata()).bool().unsqueeze(0).unsqueeze(0)

    # Ground truth
    t1n_img = nib.load(gold)
    t1n = torch.Tensor(t1n_img.get_fdata()).unsqueeze(0).unsqueeze(0)

    # Compute metrics
    mse, psnr, ssim = evaluation_utils.compute_metrics(pred, t1n, mask)
    return pd.DataFrame({
        'MSE': [mse],
        'PSNR': [psnr],
        'SSIM': [ssim]
    })


def score(gold_dir, mask_dir, pred_lst, label):
    """Compute and return scores for each scan."""
    scores = []
    for pred in pred_lst:
        scan_id = re.search(r"\d{5}-\d{3}", pred).group()
        identifier = f"{label}-{scan_id}"
        mask = os.path.join(mask_dir, identifier, f"{identifier}-mask-healthy.nii.gz")
        gold = os.path.join(gold_dir, identifier, f"{identifier}-t1n.nii.gz")
        results = (
            calculate_metrics(pred, mask, gold)
            .assign(scan_id=identifier)
            .set_index("scan_id")
        )
        scores.append(results)
    return pd.concat(scores).sort_values(by="scan_id")


def main():
    """Main function."""
    args = get_args()
    preds = utils.unzip_file(args.predictions_file)
    golds = utils.unzip_file(args.goldstandard_file, pattern="t1n")
    masks = utils.unzip_file(args.healthy_masks)

    gold_dir = os.path.normpath(golds[0]).split(os.sep)[0]
    mask_dir = os.path.normpath(masks[0]).split(os.sep)[0]
    results = score(gold_dir, mask_dir, preds, args.label)
    cases_evaluated = len(results.index)

    results.loc["mean"] = results.mean()
    results.loc["sd"] = results.std()
    results.loc["median"] = results.median()
    results.loc["25quantile"] = results.quantile(q=0.25)
    results.loc["75quantile"] = results.quantile(q=0.75)

    # CSV file of scores for all scans.
    results.to_csv("all_scores.csv")
    syn = synapseclient.Synapse(configPath=args.synapse_config)
    syn.login(silent=True)
    csv = synapseclient.File("all_scores.csv", parent=args.parent_id)
    csv = syn.store(csv)

    # Results file for annotations.
    with open(args.output, "w") as out:
        res_dict = {**results.loc["mean"].to_dict(),
                    **results.loc["sd"].to_dict(),
                    "cases_evaluated": cases_evaluated,
                    "submission_scores": csv.id,
                    "submission_status": "SCORED"}
        res_dict = {k: v for k, v in res_dict.items() if not pd.isna(v)}
        out.write(json.dumps(res_dict))


if __name__ == "__main__":
    main()
