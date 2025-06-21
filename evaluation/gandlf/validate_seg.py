#!/usr/bin/env python3
"""Validation script for BraTS 2025.

Predictions file must be a tarball or zipped archive of NIfTI files
(*.nii.gz). Each NIfTI file must have an ID in its filename.
"""
import argparse
import json
import os
import re
import shutil

import nibabel as nib
import utils

PRED_TMP_DIR = "pred"


def get_args():
    """Set up command-line interface and get arguments."""
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "-p", "--predictions_file", type=str, default="/predictions.zip"
    )
    parser.add_argument(
        "-g", "--goldstandard_file", type=str, default="/goldstandard.zip"
    )
    parser.add_argument("-g2", "--second_goldstandard_file", type=str)
    parser.add_argument("-e", "--entity_type", type=str, required=True)
    parser.add_argument("-o", "--output", type=str)
    parser.add_argument("--pred_pattern", type=str, default="(\\d{5}-\\d{3})")
    parser.add_argument("--gold_pattern", type=str, default="(\\d{5}-\\d{3})-seg")
    parser.add_argument("-l", "--label", type=str, default="BraTS-GLI")
    return parser.parse_args()


def check_file_contents(img, parent, label):
    """Check that the file can be opened as NIfTI."""
    try:
        img = nib.load(os.path.join(parent, img))
        return ""
    except nib.filebasedimages.ImageFileError:
        return "One or more predictions cannot be opened as a " "NIfTI file."


def validate_file_format(preds, parent, label):
    """Check that all files are NIfTI files (*.nii.gz)."""
    error = []
    if all(pred.endswith(".nii.gz") for pred in preds):
        if not all(
            (res := check_file_contents(pred, parent, label)) == "" for pred in preds
        ):
            error = [res]
    else:
        error = ["Not all files in the archive are NIfTI files (*.nii.gz)."]
    return error


def validate_filenames(preds, golds, pred_pattern, gold_pattern):
    """Check that every NIfTI filename follows the given pattern."""
    error = []
    try:
        scan_ids = [
            re.search(rf"{pred_pattern}\.nii\.gz$", pred).group(1) for pred in preds
        ]

        # Check that all case IDs are unique.
        if len(set(scan_ids)) != len(scan_ids):
            error.append("Duplicate predictions found for one or more cases.")

        # Check that case IDs are known (e.g. has corresponding gold file).
        gold_case_ids = {
            re.search(rf"{gold_pattern}\.nii\.gz$", gold).group(1) for gold in golds
        }
        unknown_ids = set(scan_ids) - gold_case_ids
        if unknown_ids:
            error.append(f"Unknown scan IDs found: {', '.join(sorted(unknown_ids))}")
    except AttributeError:
        error = [
            (
                "Not all filenames in the archive follow the expected "
                "naming format. Please check the Submission Tutorial "
                "of the task you're submitting to for more details."
            )
        ]
    return error


def main():
    """Main function."""
    args = get_args()
    invalid_reasons = []

    entity_type = args.entity_type.split(".")[-1]
    if entity_type != "FileEntity":
        invalid_reasons.append(f"Submission must be a File, not {entity_type}.")
    else:
        preds = utils.inspect_archive(args.predictions_file, dest_path=PRED_TMP_DIR)
        golds = utils.inspect_archive(args.goldstandard_file, extract=False)
        if args.second_goldstandard_file:
            golds.extend(
                utils.inspect_archive(args.second_goldstandard_file, extract=False)
            )
        if preds:
            invalid_reasons.extend(
                validate_file_format(preds, PRED_TMP_DIR, args.label)
            )
            invalid_reasons.extend(
                validate_filenames(preds, golds, args.pred_pattern, args.gold_pattern)
            )
        else:
            invalid_reasons.append(
                "Submission must be a tarball or zipped archive "
                "containing at least one NIfTI file."
            )
    status = "INVALID" if invalid_reasons else "VALIDATED"
    errors = "\n".join(invalid_reasons)

    # truncate validation errors if >500 (character limit for sending email)
    if len(errors) > 500:
        errors = errors[:496] + "..."
    res = json.dumps({"submission_status": status, "submission_errors": errors})

    if args.output:
        with open(args.output, "w") as out:
            out.write(res)
    else:
        print(res)

    # Cleanup.
    try:
        shutil.rmtree(PRED_TMP_DIR)
    except OSError:
        print(f"Could not remove directory: {PRED_TMP_DIR}")


if __name__ == "__main__":
    main()
