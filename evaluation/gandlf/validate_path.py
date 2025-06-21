#!/usr/bin/env python3
"""Validation script for BraTS 2024 - Pathology.

Predictions file must be a 2-col CSV with two columns:
    - SubjectID: string
    - Target: integers [0, 5]
"""

import argparse
import json

import pandas as pd
from cnb_tools import validation_toolkit as vtk

EXPECTED_COLS = {"SubjectID": str, "Prediction": int}


def get_args():
    """Set up command-line interface and get arguments."""
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "-p", "--predictions_file", type=str, default="/predictions.csv"
    )
    parser.add_argument("-e", "--entity_type", type=str, required=True)
    parser.add_argument("-o", "--output", type=str)
    parser.add_argument("--subject_id_pattern", type=str, default="")
    parser.add_argument("--min_label", type=int, default=0)
    parser.add_argument("--max_label", type=int, default=5)
    return parser.parse_args()


def validate(pred_file, pattern, min_val, max_val):
    """Validate predictions file against goldstandard."""
    errors = []
    try:
        pred = pd.read_csv(
            pred_file,
            usecols=EXPECTED_COLS,
            dtype=EXPECTED_COLS
        )
    except ValueError:
        errors.append(
            "Submission must be a CSV file with the following "
            f"colnames and coltypes: {str(EXPECTED_COLS)}"
        )
    else:
        errors.append(vtk.check_duplicate_keys(pred["SubjectID"]))
        errors.append(vtk.check_values_range(
            pred["Prediction"],
            min_val=min_val,
            max_val=max_val,
        ))

        # Check that SubjectIDs contain the filename of the digitized
        # tissue, including the file extension.
        if not all(pred["SubjectID"].str.contains(pattern)):
            errors.append(
                "'SubjectID' values must be the filenames in the "
                f"validation dataset (regex pattern: {pattern})"
            )
    return errors


def main():
    """Main function."""
    args = get_args()

    entity_type = args.entity_type.split(".")[-1]
    if entity_type != "FileEntity":
        errors = [f"Submission must be a File, not {entity_type}."]
    else:
        errors = validate(
            pred_file=args.predictions_file,
            pattern=args.subject_id_pattern,
            min_val=args.min_label,
            max_val=args.max_label,
        )

    invalid_reasons = "\n".join(filter(None, errors))
    status = "INVALID" if invalid_reasons else "VALIDATED"

    # truncate validation errors if >500 (character limit for sending email)
    if len(invalid_reasons) > 500:
        invalid_reasons = invalid_reasons[:496] + "\n..."
    res = json.dumps(
        {"submission_status": status, "submission_errors": invalid_reasons}
    )

    if args.output:
        with open(args.output, "w", encoding="utf-8") as out:
            out.write(res)
    else:
        print(res)


if __name__ == "__main__":
    main()
