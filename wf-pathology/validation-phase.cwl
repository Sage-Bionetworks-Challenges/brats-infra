#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: Workflow
label: BraTS 2026 - Task 5 workflow

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
    default: "syn75095491"
  configSynId:
    label: synID for the GaNDLF config file on Synapse
    type: string
    default: "syn68144257"
  pattern:
    label: Regex pattern for valid SubjectIDs
    type: string
    default: "^val_\\w+$"
  penalty_label:
    label: Label for the penalty region in the gold standard
    type: int
    default: 10
  
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
    default: []


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

  02_download_config:
    doc: Download GaNDLF config file for inference session
    run: |-
      https://raw.githubusercontent.com/Sage-Bionetworks-Workflows/cwl-tool-synapseclient/v1.4/cwl/synapse-get-tool.cwl
    in:
      - id: synapseid
        source: "#configSynId"
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
      - id: entity_type
        source: "#01_download_submission/entity_type"
      - id: subject_id_pattern
        source: "#pattern"
      - id: min_label
        default: 0
      - id: max_label
        default: 9
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
        default: true
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
    run: |-
      https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v4.1/cwl/check_status.cwl
    in:
      - id: status
        source: "#03_validate/status"
      - id: previous_annotation_finished
        source: "#04_add_validation_annots/finished"
      - id: previous_email_finished
        source: "#04_send_validation_results/finished"
    out: [finished]

  06_score:
    doc: Score submission
    run: steps/score.cwl
    in:
      - id: input_file
        source: "#01_download_submission/filepath"
      - id: goldstandard
        source: "#02_download_goldstandard/filepath"
      - id: gandlf_config
        source: "#02_download_config/filepath"
      - id: penalty_label
        source: "#penalty_label"
      - id: subject_id_pattern
        source: "#pattern"
      - id: check_validation_finished
        source: "#05_check_validation_status/finished"
    out:
      - id: results
      - id: status
      
  07_send_score_results:
    doc: Send email of the scores to the submitter
    run: |-
      https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v4.1/cwl/score_email.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: synapse_config
        source: "#synapseConfig"
      - id: results
        source: "#06_score/results"
      - id: private_annotations
        source: "#private_annotations"
    out: []

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
    run: |-
      https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v4.1/cwl/check_status.cwl
    in:
      - id: status
        source: "#06_score/status"
      - id: previous_annotation_finished
        source: "#07_add_score_annots/finished"
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
