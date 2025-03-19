# Evaluation Workflow for BraTS 2023+

The repository contains the evaluation workflows for the [BraTS 2023 Challenge and beyond],
including:

* BraTS 2023
* BraTS-GoAT 2024
* FeTS 2024
* BraTS 2024
* BraTS-Lighthouse 2025 🆕


Workflows are organized by task type, e.g. the `wf-augmentation` folder contains
the CWL workflows for the Augmentation task.  CWL scripts used by 1+ workflow
are located in the `shared` folder.

Source code of the metrics computations mentioned in the README are available
in the `evaluation` folder of this repo, organized into sub-folders by task.

[BraTS 2023 Challenge and beyond]: https://www.synapse.org/brats


## Metrics Overview

<details><summary><strong>BraTS 2023</strong></summary>
<br/>

Metrics returned and used for ranking will depend on the task:

**Task** | **Metrics** | **Ranking**
--|--|--
Segmentations | Lesion-wise dice, lesions-wise Hausdorff 95% distance (HD95), full dice, full HD95, sensitivity, specificity | Lesion-wise dice, lesion-wise HD95
Inpainting | Structural similarity index measure (SSIM), peak-signal-to-noise-ratio (PSNR), mean-square-error (MSE) | SSIM, PSNR, MSE
Augmentations | Full dice, full HD95, sensitivity, specificity | Dice mean, dice variance, HD95 mean, HD95 variance

---

</details>


<details><summary><strong>BraTS-GoAT 2024</strong></summary>
<br/>

Metrics returned and used for ranking are:

**Metrics** | **Ranking**
--|--
Lesion-wise dice, lesions-wise Hausdorff 95% distance (HD95), full dice, full HD95, sensitivity, specificity | Lesion-wise dice, lesion-wise HD95

---

</details>


<details><summary><strong>FeTS 2024</strong></summary>
<br/>


Metrics returned are: lesion-wise dice, lesions-wise Hausdorff 95% distance
(HD95), full dice, full HD95, sensitivity, specificity

**Note**: Code submission evaluations and ranking were handled by the 
[FeTS-AI Task 1 infrastructure](https://github.com/FeTS-AI/Challenge/tree/main/Task_1).

---

</details>


<details><summary><strong>BraTS 2024</strong></summary>
<br/>

Metrics returned and used for ranking will depend on the task:

**Task** | **Metrics** | **Ranking**
--|--|--
Segmentations | Lesion-wise dice, lesions-wise Hausdorff 95% distance (HD95), full dice, full HD95, sensitivity, specificity | Lesion-wise dice, lesion-wise HD95
Inpainting | Structural similarity index measure (SSIM), peak-signal-to-noise-ratio (PSNR), mean-square-error (MSE) | All 3 metrics
Augmentations | Full dice, full HD95, sensitivity, specificity | Dice mean, Dice GINI index, HD95 mean, HD95 GINI index
Pathology | Matthews correlation coefficient (MCC), F1, sensitivity, specificity | All 4 metrics

---

</details>


<details><summary><strong>BraTS-Lighthouse 2025</strong></summary>
<br/>

Metrics returned and used for ranking will depend on the task:

**Task** | **Metrics** | **Ranking**
--|--|--
Segmentations | _Under discussion_ | _Under discussion_
Inpainting | Structural similarity index measure (SSIM), peak-signal-to-noise-ratio (PSNR), mean-square-error (MSE) | All 3 metrics
Pathology | Matthews correlation coefficient (MCC), F1, sensitivity, specificity | All 4 metrics

---

</details>


## Kudos 🍻

BraTS 2023+ evaluation would not be possible without the work of:

* [@FelixSteinbauer](https://github.com/FelixSteinbauer) - inpainting metrics
* [@rachitsaluja](https://github.com/rachitsaluja) - lesionwise segmentation metrics
* [@sarthakpati](https://github.com/sarthakpati) - pathology metrics

In addition to:

* [CaPTk](https://github.com/CBICA/CaPTk)
* [MedPerf](https://github.com/mlcommons/medperf)
* [FeTS-AI](https://github.com/FeTS-AI/Challenge/tree/main)
* [GaNDLF](https://github.com/mlcommons/GaNDLF)
