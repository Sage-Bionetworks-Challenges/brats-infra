#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: Workflow
label: BraTS 2024 - MLCube workflow

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

outputs: []

steps:
  organizers_log_access:
    doc: >
      Give challenge organizers `download` permissions to the submission logs
    run: |-
      https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v4.0/cwl/set_permissions.cwl
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

  download_tarball:
    doc: Download MLCube tarball submission
    run: |-
      https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v4.0/cwl/get_submission.cwl
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

  unzip_tarball:
    doc: Unzip MLCube config tarball, then upload file(s) to Synapse.
    run: steps/extract_config.cwl
    in:
      - id: input_file
        source: "#download_tarball/filepath"
      - id: synapse_config
        source: "#synapseConfig"
      - id: parent_id
        source: "#submitterUploadSynId"
    out:
      - id: results
      - id: mlcube
      # - id: status

  add_tarball_annots:
    doc: >
      Update tarball submission with MLCube config files
    run: |-
      https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v4.0/cwl/annotate_submission.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: annotation_values
        source: "#unzip_tarball/results"
      - id: to_public
        default: true
      - id: force
        default: true
      - id: synapse_config
        source: "#synapseConfig"
    out: [finished]

  send_tarball_results:
    doc: Send email if submission is missing `mlcube.yaml`
    run: steps/email_invalid.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: synapse_config
        source: "#synapseConfig"
      - id: mlcube_id
        source: "#unzip_tarball/mlcube"
    out: [finished]

  end_wf_if_missing:
    doc: Stop the workflow if mlcube.yaml is missing from the submission
    run: steps/validate_mlcube_config.cwl
    in:
      - id: mlcube
        source: "unzip_tarball/mlcube"
      - id: previous_annotation_finished
        source: "#send_tarball_results/finished"
    out: [finished]

  get_corresponding_docker:
    doc: >
      Check that tarball is unique and contains all necessary scripts/files
    run: steps/get_docker_sub.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: synapse_config
        source: "#synapseConfig"
      - id: submission_view
        valueFrom: "syn61874407"
      - id: docker_evaluation_id
        default: 9615548
      - id: previous_annotation_finished
        source: "#end_wf_if_missing/finished"
    out:
      - id: results
      - id: status
      - id: docker_id
  
  send_docker_results:
    doc: Send email whether corresponding Docker image can be found
    run: steps/email_results.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: synapse_config
        source: "#synapseConfig"
      - id: status
        source: "#get_corresponding_docker/status"
    out: [finished]

  update_tarball_annots:
    doc: >
      Update tarball submission with MLCube config files
    run: |-
      https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v4.0/cwl/annotate_submission.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: annotation_values
        source: "#get_corresponding_docker/results"
      - id: to_public
        default: true
      - id: force
        default: true
      - id: synapse_config
        source: "#synapseConfig"
      - id: previous_annotation_finished
        source: "#add_tarball_annots/finished"
    out: [finished]

  set_invalid_status:
    doc: Set status to INVALID if corresponding Docker image not found
    run: |-
      https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v4.1/cwl/check_status.cwl
    in:
      - id: status
        source: "#get_corresponding_docker/status"
      - id: previous_annotation_finished
        source: "#update_tarball_annots/finished"
      - id: previous_email_finished
        source: "#send_docker_results/finished"
    out: [finished]
 
s:author:
- class: s:Person
  s:identifier: https://orcid.org/0000-0002-5622-7998
  s:email: verena.chung@sagebase.org
  s:name: Verena Chung

s:codeRepository: https://github.com/Sage-Bionetworks-Challenges/brats2023
s:license: https://spdx.org/licenses/Apache-2.0

$namespaces:
  s: https://schema.org/
