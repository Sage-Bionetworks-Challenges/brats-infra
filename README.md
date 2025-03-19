## FeTS 2024 Evaluation Workflows

FeTS 2024 has one evaluation phase facilitated by this repo:

* **Validation phase:** participants submit <u>segmentation predictions</u> to be evaluated using the validation dataset

Metrics returned are: lesion-wise dice, lesions-wise Hausdorff 95% distance (HD95), full dice, full HD95, sensitivity, specificity

Code for the above computations are available in the `evaluation/lesionwise` folder of the repo.

The **Code submission phase** is handled by the [FeTS-AI Task 1 infrastructure].

[FeTS-AI Task 1 infrastructure]: https://github.com/FeTS-AI/Challenge/tree/main/Task_1

## Kudos 🍻

BraTS 2023 evaluation would not be possible without the work of:

* [@FelixSteinbauer](https://github.com/FelixSteinbauer) - inpainting metrics
* [@rachitsaluja](https://github.com/rachitsaluja) - segmentation metrics

In addition to:

* [CaPTk](https://github.com/CBICA/CaPTk)
* [MedPerf](https://github.com/mlcommons/medperf)
* [FeTS-AI](https://github.com/FeTS-AI/Challenge/tree/main)
