# BraTS Evaluation Infrastructure

Infrastructure for the [BraTS Challenge (2023 and beyond)], covering:

* BraTS 2023
* BraTS-GoAT 2024
* FeTS 2024
* BraTS 2024
* BraTS-Lighthouse 2025
* BraTS 2026 🆕

## Repository Structure

| Folder | Description |
|--------|-------------|
| `wf-segmentation/` | CWL workflows for segmentation tasks  |
| `wf-inpainting/` | CWL workflow for the inpainting task |
| `wf-pathology/` | CWL workflow for the pathology task |
| `wf-containers/` | CWL workflows for Docker/MLCube submission validation |
| `shared/` | CWL tools shared across workflows |
| `evaluation/` | Scoring scripts and Dockerfiles, organized by task type |

CWL workflows run on the [Synapse](https://www.synapse.org/brats) platform via
the SynapseWorkflowOrchestrator. Scoring scripts in `evaluation/` are packaged
as Docker images and invoked by the corresponding CWL step.

### Building Docker images

Docker images are built from the `evaluation/` directory using task-specific Dockerfiles:

```sh
cd evaluation/
docker build -f Dockerfile.inpainting  -t <image> .
docker build -f Dockerfile.pathology   -t <image> .
docker build -f Dockerfile.segmentation -t <image> .
```

> [!NOTE]
> If you are using a M1 chip, use `docker buildx build --platform linux/amd64,linux/arm64 ...` to
> target multiple platforms.

[BraTS Challenge (2023 and beyond)]: https://www.synapse.org/brats


## Metrics

<details><summary><strong>BraTS 2023</strong></summary>
<br/>

**Task** | **Metrics** | **Ranking**
--|--|--
Segmentation | Lesion-wise DSC, lesion-wise HD95, full DSC, full HD95, sensitivity, specificity | Lesion-wise DSC, lesion-wise HD95
Inpainting | SSIM, PSNR, MSE | SSIM, PSNR, MSE
Augmentation | Full DSC, full HD95, sensitivity, specificity | DSC mean, DSC variance, HD95 mean, HD95 variance

---

</details>

<details><summary><strong>BraTS-GoAT 2024</strong></summary>
<br/>

**Metrics** | **Ranking**
--|--
Lesion-wise DSC, lesion-wise HD95, full DSC, full HD95, sensitivity, specificity | Lesion-wise DSC, lesion-wise HD95

---

</details>

<details><summary><strong>FeTS 2024</strong></summary>
<br/>

Metrics returned: lesion-wise DSC, lesion-wise HD95, full DSC, full HD95, sensitivity, specificity.

**Note**: Code submission evaluations and ranking were handled by the
[FeTS-AI Task 1 infrastructure](https://github.com/FeTS-AI/Challenge/tree/main/Task_1).

---

</details>

<details><summary><strong>BraTS 2024</strong></summary>
<br/>

**Task** | **Metrics** | **Ranking**
--|--|--
Segmentation | Lesion-wise DSC, lesion-wise HD95, full DSC, full HD95, sensitivity, specificity | Lesion-wise DSC, lesion-wise HD95
Inpainting | SSIM, PSNR, MSE | All 3 metrics
Augmentation | Full DSC, full HD95, sensitivity, specificity | DSC mean, DSC GINI index, HD95 mean, HD95 GINI index
Pathology | MCC, F1, sensitivity, specificity | All 4 metrics

---

</details>

<details><summary><strong>BraTS-Lighthouse 2025</strong></summary>
<br/>

**Task** | **Metrics** | **Ranking**
--|--|--
Segmentation | Lesion-wise DSC, lesion-wise HD95, lesion-wise NSD (Panoptica) | Lesion-wise DSC
Inpainting | SSIM, PSNR, MSE | All 3 metrics
Pathology | MCC, F1, sensitivity, specificity | All 4 metrics

---

</details>

<details><summary><strong>BraTS 2026</strong></summary>
<br/>

**Task** | **Metrics** | **Ranking**
--|--|--
Segmentation | _TBD_ | _TBD_
Inpainting | SSIM, PSNR, MSE | All 3 metrics
Pathology | MCC, F1, sensitivity, specificity | All 4 metrics

---

</details>


## Acknowledgements 🍻

BraTS evaluation would not be possible without the contributions of:

* [@FelixSteinbauer](https://github.com/FelixSteinbauer) — inpainting metrics
* [@rachitsaluja](https://github.com/rachitsaluja) — lesion-wise segmentation metrics
* [@sarthakpati](https://github.com/sarthakpati) — pathology metrics

And the following projects:

* [CaPTk](https://github.com/CBICA/CaPTk)
* [MedPerf](https://github.com/mlcommons/medperf)
* [FeTS-AI](https://github.com/FeTS-AI/Challenge/tree/main)
* [GaNDLF](https://github.com/mlcommons/GaNDLF)
* [BraTS Evaluation](https://github.com/BraTS/BraTS_evaluation/tree/main)
