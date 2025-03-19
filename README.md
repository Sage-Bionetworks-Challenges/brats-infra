## BraTS 2023 Evaluation Workflows

BraTS 2023 is split into two evaluation phases:

* **Validation phase:** participants submit <u>predictions files</u> (segmentation masks, t1n inferences, etc.) to be evaluated using the validation dataset

* **Test phase:** participants submit <u>MLCube models</u> that will generate prediction files using the test dataset

Metrics returned and used for ranking will depend on the task:

**Task** | **Metrics** | **Ranking**
--|--|--
Segmentations | Lesion-wise dice, lesions-wise Hausdorff 95% distance (HD95), full dice, full HD95, sensitivity, specificity | Lesion-wise dice, lesion-wise HD95
Inpainting | Structural similarity index measure (SSIM), peak-signal-to-noise-ratio (PSNR), mean-square-error (MSE) | SSIM, PSNR, MSE
Augmentations | Full dice, full HD95, sensitivity, specificity | Dice mean, dice variance, HD95 mean, HD95 variance

Code for the above computations are available in the `evaluation` folder of the repo.


## Kudos 🍻

BraTS 2023 evaluation would not be possible without the work of:

* [@FelixSteinbauer](https://github.com/FelixSteinbauer) - inpainting metrics
* [@rachitsaluja](https://github.com/rachitsaluja) - lesionwise segmentation metrics

In addition to:

* [CaPTk](https://github.com/CBICA/CaPTk)
* [MedPerf](https://github.com/mlcommons/medperf)
* [FeTS-AI](https://github.com/FeTS-AI/Challenge/tree/main)
