#!/usr/bin/env python3
"""Validation script for BraTS 2023.

Predictions file must be a tarball or zipped archive of NIfTI files
(*.nii.gz). Each NIfTI file must have an ID in its filename.
"""
import argparse
import json
import os
import re

import nibabel as nib
import utils

DIM = (240, 240, 155)
DIM_GLI_POSTOP = (182, 218, 182)


def get_args():
    """Set up command-line interface and get arguments."""
    parser = argparse.ArgumentParser()
    parser.add_argument("-p", "--predictions_file",
                        type=str, default="/predictions.zip")
    parser.add_argument("-g", "--goldstandard_file",
                        type=str, default="/goldstandard.zip")
    parser.add_argument("-g2", "--second_goldstandard_file",
                        type=str)
    parser.add_argument("-e", "--entity_type",
                        type=str, required=True)
    parser.add_argument("-t", "--tmp_dir",
                        type=str, default="tmpdir")
    parser.add_argument("-o", "--output", type=str)
    parser.add_argument("--pred_pattern", type=str,
                        default="(\d{5}-\d{3})")
    parser.add_argument("--gold_pattern", type=str,
                        default="(\d{5}-\d{3})-seg")
    parser.add_argument("-l", "--label",
                        type=str, default="BraTS-GLI")
    return parser.parse_args()


def _check_header(img, label):
    """Check if img has the correct dimensions and origin."""
    error = ""
    match label:
        case "BraTS-GLI":
            if img.header.get_data_shape() != DIM_GLI_POSTOP:
                error = ("One or more predictions is not a NIfTI file with "
                         "dimension of 182x218x182.")
        case "BraTS-MEN-RT":
            # MEN-RT doesn't have a set dimension and origin for all scans,
            # so don't perform any checks.
            pass
        case _:
            if img.header.get_data_shape() != DIM:
                error = ("One or more predictions is not a NIfTI file with "
                         "dimension of 240x240x155.")
    return error


def check_file_contents(img, parent, label):
    """Check that the file can be opened as NIfTI."""
    try:
        print(img)
        img = nib.load(os.path.join(parent, img))
        return _check_header(img, label)
    except nib.filebasedimages.ImageFileError:
        return ("One or more predictions cannot be opened as a "
                "NIfTI file.")


def validate_file_format(preds, parent, label):
    """Check that all files are NIfTI files (*.nii.gz)."""
    error = []
    if all(pred.endswith(".nii.gz") for pred in preds):
        # Ensure that all file contents are NIfTI with correct params.
        if not all((res := check_file_contents(pred, parent, label)) == "" for pred in preds):
            error = [res]
    else:
        error = ["Not all files in the archive are NIfTI files (*.nii.gz)."]
    return error


def validate_filenames(preds, golds, pred_pattern, gold_pattern):
    """Check that every NIfTI filename follows the given pattern."""
    error = []
    try:
        scan_ids = [
            re.search(fr"{pred_pattern}\.nii\.gz$", pred).group(1)
            for pred
            in preds
        ]

        # Check that all case IDs are unique.
        if len(set(scan_ids)) != len(scan_ids):
            error.append("Duplicate predictions found for one or more cases.")

        # Check that case IDs are known (e.g. has corresponding gold file).
        gold_case_ids = {
            re.search(fr"{gold_pattern}\.nii\.gz$", gold).group(1)
            for gold
            in golds
        }
        unknown_ids = set(scan_ids) - gold_case_ids
        if unknown_ids:
            error.append(
                f"Unknown scan IDs found: {', '.join(sorted(unknown_ids))}")
    except AttributeError:
        error = [("Not all filenames in the archive follow the expected "
                  "naming format. Please check the Submission Tutorial "
                  "of the task you're submitting to for more details.")]
    return error


def main():
    """Main function."""
    args = get_args()
    invalid_reasons = []

    entity_type = args.entity_type.split(".")[-1]
    if entity_type != "FileEntity":
        invalid_reasons.append(
            f"Submission must be a File, not {entity_type}."
        )
    else:
        preds = utils.inspect_zip(args.predictions_file, path=args.tmp_dir)
        golds = utils.inspect_zip(args.goldstandard_file, unzip=False)
        if args.second_goldstandard_file:
            golds.extend(
                utils.inspect_zip(args.second_goldstandard_file, unzip=False)
            )
        if preds:
            invalid_reasons.extend(validate_file_format(
                preds, args.tmp_dir, args.label
            ))
            invalid_reasons.extend(validate_filenames(
                preds, golds,
                args.pred_pattern, args.gold_pattern
            ))
        else:
            invalid_reasons.append(
                "Submission must be a tarball or zipped archive "
                "containing at least one NIfTI file."
            )
    status = "INVALID" if invalid_reasons else "VALIDATED"
    invalid_reasons = "\n".join(invalid_reasons)

    # truncate validation errors if >500 (character limit for sending email)
    if len(invalid_reasons) > 500:
        invalid_reasons = invalid_reasons[:496] + "..."
    res = json.dumps({
        "submission_status": status,
        "submission_errors": invalid_reasons
    })

    if args.output:
        with open(args.output, "w") as out:
            out.write(res)
    else:
        print(res)


if __name__ == "__main__":
    main()
