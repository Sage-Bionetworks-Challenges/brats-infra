#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: Workflow
label: BraTS 2026 - Task 4 workflow

requirements:
  - class: StepInputExpressionRequirement

inputs:
  # ------------------------------------------------------------------------------
  # SynapseWorkflowOrchestrator inputs - do not remove or modify.
  # ------------------------------------------------------------------------------
  adminUploadSynId:
    label: synID to folder on Synapse that is downloadable by admin only
    type: string
  submissionId:
    label: Submission ID
    type: int
  submitterUploadSynId:
    label: synID to folder on Synapse that is downloadable by submitter and admin
    type: string
  synapseConfig:
    label: Abstolute filepath to .synapseConfig file
    type: File
  workflowSynapseId:
    label: synID to workflow file
    type: string

  # ------------------------------------------------------------------------------
  # Core challenge configuration - specific to this challenge.
  # ------------------------------------------------------------------------------
  organizersId:
    label: User or team ID for challenge organizers
    type: string
    default: "3466984"
  groundtruthSynId:
    label: synID for the groundtruth file on Synapse
    type: string
    default: "syn51514110"
  healthyMasksSynId:
    label: synID for the healthy masks file on Synapse
    type: string
    default: "syn51685080"
  pred_pattern:
    label: Regex pattern for valid prediction filenames
    type: string
    default: "(\\d{5}-\\d{3})-t1n-inference"
  gold_pattern:
    label: Regex pattern for valid gold standard filenames
    type: string
    default: "(\\d{5}-\\d{3})-mask-healthy"
  
  # ------------------------------------------------------------------------------
  # Optional challenge configuration.
  # ------------------------------------------------------------------------------
  errors_only:
    label: Send email notifications only for errors (no notification for valid submissions)
    type: boolean
    default: true
  private_annotations:
    label: Annotations to be withheld from participants
    type: string[]
    default: ["PSNR_mean", "PSNR_sd"]

outputs: []

steps:
  01_set_submitter_folder_permissions:
    doc: >
      Give challenge organizers `download` permissions to the submission logs
    run: |-
      https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v4.1/cwl/set_permissions.cwl
    in:
      - id: entityid
        source: "#submitterUploadSynId"
      - id: principalid
        source: "#organizersId"
      - id: permissions
        valueFrom: "download"
      - id: synapse_config
        source: "#synapseConfig"
    out: []

  01_set_private_folder_permissions:
    doc: >
      Give challenge organizers `download` permissions to the score files
    run: |-
      https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v4.1/cwl/set_permissions.cwl
    in:
      - id: entityid
        source: "#adminUploadSynId"
      - id: principalid
        source: "#organizersId"
      - id: permissions
        valueFrom: "download"
      - id: synapse_config
        source: "#synapseConfig"
    out: []

  01_download_submission:
    doc: Download submission
    run: |-
      https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v4.1/cwl/get_submission.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: synapse_config
        source: "#synapseConfig"
    out:
      - id: filepath
      - id: entity_id
      - id: entity_type
      - id: evaluation_id
      - id: results

  02_download_masks:
    doc: Download healthy masks
    run: |-
      https://raw.githubusercontent.com/Sage-Bionetworks-Workflows/cwl-tool-synapseclient/v1.4/cwl/synapse-get-tool.cwl
    in:
      - id: synapseid
        source: "#healthyMasksSynId"
      - id: synapse_config
        source: "#synapseConfig"
    out:
      - id: filepath

  02_download_goldstandard:
    doc: Download goldstandard
    run: |-
      https://raw.githubusercontent.com/Sage-Bionetworks-Workflows/cwl-tool-synapseclient/v1.4/cwl/synapse-get-tool.cwl
    in:
      - id: synapseid
        source: "#groundtruthSynId"
      - id: synapse_config
        source: "#synapseConfig"
    out:
      - id: filepath

  03_validate:
    doc: Validate submission, which should be a tar/zip of NIfTI files
    run: steps/validate.cwl
    in:
      - id: input_file
        source: "#01_download_submission/filepath"
      - id: goldstandard
        source: "#02_download_masks/filepath"
      - id: entity_type
        source: "#01_download_submission/entity_type"
      - id: pred_pattern
        source: "#pred_pattern"
      - id: gold_pattern
        source: "#gold_pattern"
    out:
      - id: results
      - id: status
      - id: invalid_reasons
  
  04_send_validation_results:
    doc: Send email of the validation results to the submitter
    run: |-
      https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v4.1/cwl/validate_email.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: synapse_config
        source: "#synapseConfig"
      - id: status
        source: "#03_validate/status"
      - id: invalid_reasons
        source: "#03_validate/invalid_reasons"
      - id: errors_only
        source: "#errors_only"
    out: [finished]

  04_add_validation_annots:
    doc: >
      Add `submission_status` and `submission_errors` annotations to the
      submission
    run: |-
      https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v4.1/cwl/annotate_submission.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: annotation_values
        source: "#03_validate/results"
      - id: to_public
        default: true
      - id: force
        default: true
      - id: synapse_config
        source: "#synapseConfig"
    out: [finished]

  05_check_validation_status:
    doc: >
      Check the validation status of the submission; if 'INVALID', throw an
      exception to stop the workflow - this will prevent the attempt of
      scoring invalid predictions file (which will then result in errors)
    run: ../shared/check_status.cwl
    in:
      - id: status
        source: "#03_validate/status"
      - id: previous_annotation_finished
        source: "#04_add_validation_annots/finished"
      - id: previous_email_finished
        source: "#04_send_validation_results/finished"
    out: [finished]

  06_score:
    doc: >
      Score submission; individual case scores will be uploaded to Synapse in
      a CSV while aggregate (mean) scores will be returned to the submitter
    run: steps/score.cwl
    in:
      - id: parent_id
        source: "#submitterUploadSynId"
      - id: synapse_config
        source: "#synapseConfig"
      - id: input_file
        source: "#01_download_submission/filepath"
      - id: masks
        source: "#02_download_masks/filepath"
      - id: goldstandard
        source: "#02_download_goldstandard/filepath"
        # default:
        #   class: File
        #   location: "/home/vchung/gold.tar.gz"
      - id: check_validation_finished 
        source: "#05_check_validation_status/finished"
    out:
      - id: results
      - id: status
      
  07_send_score_results:
    doc: >
      Send email of the scores to the submitter, as well as the link to the
      all_scores CSV file on Synapse
    run: ../shared/email_results.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: synapse_config
        source: "#synapseConfig"
      - id: results
        source: "#06_score/results"
      - id: private_annotations
        source: "#private_annotations"
    out: [finished]

  07_add_score_annots:
    doc: >
      Update `submission_status` and add the scoring metric annotations
    run: |-
      https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v4.1/cwl/annotate_submission.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: annotation_values
        source: "#06_score/results"
      - id: to_public
        default: true
      - id: force
        default: true
      - id: synapse_config
        source: "#synapseConfig"
      - id: previous_annotation_finished
        source: "#04_add_validation_annots/finished"
    out: [finished]

  08_check_score_status:
    doc: >
      Check the scoring status of the submission; if 'INVALID', throw an
      exception so that final status is 'INVALID' instead of 'ACCEPTED'
    run: ../shared/check_status.cwl
    in:
      - id: status
        source: "#06_score/status"
      - id: previous_annotation_finished
        source: "#07_add_score_annots/finished"
      - id: previous_email_finished
        source: "#07_send_score_results/finished"
    out: [finished]
 
s:author:
- class: s:Person
  s:identifier: https://orcid.org/0000-0002-5622-7998
  s:email: verena.chung@sagebase.org
  s:name: Verena Chung

s:codeRepository: https://github.com/Sage-Bionetworks-Challenges/brats-infra
s:license: https://spdx.org/licenses/Apache-2.0

$namespaces:
  s: https://schema.org/
