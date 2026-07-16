"""Convet MedPerf server results to CSV"""

import os
import argparse
import subprocess

import synapseclient
import pandas as pd

METRICS = [
    "LesionWise",
    "Legacy",
    "Sensitivity",
    "Specificity",
    "Volume",
    "Num",  # false negative, true/false positives
]


def get_args():
    """Set up command-line interface and get arguments."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--input_excel_file", type=str, required=True)
    parser.add_argument("--sheet_name", type=str, required=True)
    parser.add_argument("--scores_folder", type=str, default="syn52373522")
    return parser.parse_args()


def run_medperf(result_id, output_filename="tmp.json"):
    cmd = [
        "medperf",
        "result",
        "view",
        str(result_id),
        "--format=json",
        f"--output={output_filename}",
    ]
    subprocess.check_call(cmd)


def _extract_global_synthesis_results():
    result = pd.read_json("tmp.json")
    result = result[~result.index.str.contains("partial")]

    ssim_results = (
        pd.melt(pd.json_normalize(result.loc["ssim"]["results"]))
        .rename(columns={"variable": "scan_id", "value": "ssim"})
        .set_index("scan_id")
        .rename("BraTS-GLI-{}".format)
    )

    seg_results = pd.melt(
        pd.json_normalize(result.loc["segmentation"]["results"], max_level=0)
    )
    scan_ids = "BraTS-GLI-" + seg_results.variable.astype(str)
    scores = pd.json_normalize(seg_results["value"], sep="_").assign(scan_id=scan_ids)
    return pd.merge(ssim_results.reset_index(), scores).set_index("scan_id")


def _extract_other_results(label):
    result = pd.read_json("tmp.json").reset_index().rename(columns={"index": "scan_id"})
    result = result[~result.scan_id.str.contains("partial")]
    scan_ids = f"{label}-" + result.scan_id.astype(str)
    return (
        pd.json_normalize(result["results"], sep="_")
        .assign(scan_id=scan_ids)
        .set_index("scan_id")
    )


def extract_results(task, label):
    if task == "task7":
        return _extract_global_synthesis_results()
    else:
        return _extract_other_results(label)


def main():
    """Main function."""
    syn = synapseclient.Synapse()
    syn.login(silent=True)
    args = get_args()

    results = pd.read_excel(args.input_excel_file, sheet_name=args.sheet_name).fillna(
        ""
    )
    for _, row in results.iterrows():
        if row["notes"]:
            print(f"Results already uploaded: {row['submitter']} ({row['task']})")
        else:
            # Get and clean up results.
            result_id = row["UID"]
            run_medperf(result_id)
            scores = extract_results(row["task"], row["task_label"])

            # Get descriptive statistics.
            stats = (
                scores.describe()
                .rename(
                    index={"25%": "25quantile", "50%": "median", "75%": "75quantile"}
                )
                .drop(["count", "min", "max"])
            )
            scores = pd.concat([scores, stats])

            # Reformat then upload to Synapse.
            if row["task"] == "task8":
                cols = scores.columns
            else:
                cols = [
                    col for metric in METRICS for col in scores.columns if metric in col
                ]
                cols.sort()
                if row["task"] == "task7":
                    cols.insert(0, "ssim")

            # Output file, then upload to Synapse.
            scores_filename = (
                f"{row['task']}_"
                f"{row['submitter'].replace(' ', '-')}_"
                f"{row['sub_id']}.csv"
            )
            scores[cols].to_csv(scores_filename, index_label="scan_id")
            csv = synapseclient.File(scores_filename, parent=args.scores_folder)
            csv = syn.store(csv)

            # Clean up files.
            os.remove("tmp.json")
            os.remove(scores_filename)


if __name__ == "__main__":
    main()
