#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: Workflow
label: BraTS 2025 - Tasks 1-3, 5-6 workflow

requirements:
  - class: StepInputExpressionRequirement

inputs:
  adminUploadSynId:
    label: Synapse Folder ID accessible by an admin
    type: string
  submissionId:
    label: Submission ID
    type: int
  submitterUploadSynId:
    label: Synapse Folder ID accessible by the submitter
    type: string
  synapseConfig:
    label: filepath to .synapseConfig file
    type: File
  workflowSynapseId:
    label: Synapse File ID that links to the workflow
    type: string
  organizers:
    label: User or team ID for challenge organizers
    type: string
    default: "3466984"
  pred_pattern:
    label: Regex pattern for valid prediction filenames
    type: string
    default: "(\\d{4,5}-\\d{1,3})"
  gold_pattern:
    label: Regex pattern for valid prediction filenames
    type: string
    default: "(\\d{4,5}-\\d{1,3})[-_](seg|gtv)"

outputs: []

steps:
  organizers_log_access:
    doc: >
      Give challenge organizers `download` permissions to the submission logs
    run: |-
      https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v4.1/cwl/set_permissions.cwl
    in:
      - id: entityid
        source: "#submitterUploadSynId"
      - id: principalid
        source: "#organizers"
      - id: permissions
        valueFrom: "download"
      - id: synapse_config
        source: "#synapseConfig"
    out: []

  download_submission:
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

  get_task_entities:
    doc: Get goldstandard and label based on task number
    run: steps/get_task.cwl
    in:
      - id: queue
        source: "#download_submission/evaluation_id"
    out:
      - id: gt_synid
      - id: gt2_synid
      - id: label

  download_goldstandard:
    doc: Download goldstandard
    run: |-
      https://raw.githubusercontent.com/Sage-Bionetworks-Workflows/cwl-tool-synapseclient/v1.4/cwl/synapse-get-tool.cwl
    in:
      - id: synapseid
        source: "#get_task_entities/gt_synid"
      - id: synapse_config
        source: "#synapseConfig"
    out:
      - id: filepath

  download_second_goldstandard:
    doc: Download additional goldstandard (empty zipfile if not available)
    run: |-
      https://raw.githubusercontent.com/Sage-Bionetworks-Workflows/cwl-tool-synapseclient/v1.4/cwl/synapse-get-tool.cwl
    in:
      - id: synapseid
        source: "#get_task_entities/gt2_synid"
      - id: synapse_config
        source: "#synapseConfig"
    out:
      - id: filepath

  validate:
    doc: Validate submission, which should be a tar/zip of NIfTI files
    run: steps/validate.cwl
    in:
      - id: input_file
        source: "#download_submission/filepath"
      - id: goldstandard
        source: "#download_goldstandard/filepath"
      - id: second_goldstandard
        source: "#download_second_goldstandard/filepath"
      - id: entity_type
        source: "#download_submission/entity_type"
      - id: pred_pattern
        source: "#pred_pattern"
      - id: gold_pattern
        source: "#gold_pattern"
      - id: label
        source: "#get_task_entities/label"
    out:
      - id: results
      - id: status
      - id: invalid_reasons
  
  send_validation_results:
    doc: Send email of the validation results to the submitter
    run: |-
      https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v4.1/cwl/validate_email.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: synapse_config
        source: "#synapseConfig"
      - id: status
        source: "#validate/status"
      - id: invalid_reasons
        source: "#validate/invalid_reasons"
      # OPTIONAL: set `default` to `false` if email notification about valid submission is needed
      - id: errors_only
        default: true
    out: [finished]

  add_validation_annots:
    doc: >
      Add `submission_status` and `submission_errors` annotations to the
      submission
    run: |-
      https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v4.1/cwl/annotate_submission.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: annotation_values
        source: "#validate/results"
      - id: to_public
        default: true
      - id: force
        default: true
      - id: synapse_config
        source: "#synapseConfig"
    out: [finished]

  check_validation_status:
    doc: >
      Check the validation status of the submission; if 'INVALID', throw an
      exception to stop the workflow - this will prevent the attempt of
      scoring invalid predictions file (which will then result in errors)
    run: |-
      https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v4.1/cwl/check_status.cwl
    in:
      - id: status
        source: "#validate/status"
      - id: previous_annotation_finished
        source: "#add_validation_annots/finished"
      - id: previous_email_finished
        source: "#send_validation_results/finished"
    out: [finished]

  score:
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
        source: "#download_submission/filepath"
      - id: goldstandard
        source: "#download_goldstandard/filepath"
      - id: second_goldstandard
        source: "#download_second_goldstandard/filepath"
      - id: label
        source: "#get_task_entities/label"
      - id: check_validation_finished
        source: "#check_validation_status/finished"
    out:
      - id: results
      - id: status
      
  send_score_results:
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
        source: "#score/results"
      # OPTIONAL: add annotations to be withheld from participants to `[]`
      # - id: private_annotations
      #   default: []
    out: [finished]

  add_score_annots:
    doc: >
      Update `submission_status` and add the scoring metric annotations
    run: |-
      https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v4.1/cwl/annotate_submission.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: annotation_values
        source: "#score/results"
      - id: to_public
        default: true
      - id: force
        default: true
      - id: synapse_config
        source: "#synapseConfig"
      - id: previous_annotation_finished
        source: "#add_validation_annots/finished"
    out: [finished]

  check_score_status:
    doc: >
      Check the scoring status of the submission; if 'INVALID', throw an
      exception so that final status is 'INVALID' instead of 'ACCEPTED'
    run: |-
      https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v4.1/cwl/check_status.cwl
    in:
      - id: status
        source: "#score/status"
      - id: previous_annotation_finished
        source: "#add_score_annots/finished"
      - id: previous_email_finished
        source: "#send_score_results/finished"
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
