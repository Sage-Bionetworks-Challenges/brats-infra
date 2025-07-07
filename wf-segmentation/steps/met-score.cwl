#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: CommandLineTool
label: Score Segmentations with Panoptica

requirements:
- class: InlineJavascriptRequirement

inputs:
- id: private_parent_id
  type: string
- id: parent_id
  type: string
- id: synapse_config
  type: File
- id: input_file
  type: File
- id: goldstandard
  type: File
- id: gandlf_config
  type: File
- id: subject_id_pattern
  type: string?
  inputBinding:
    prefix: --subject_id_pattern
- id: check_validation_finished
  type: boolean?

outputs:
- id: results
  type: File
  outputBinding:
    glob: results.json
- id: status
  type: string
  outputBinding:
    glob: results.json
    outputEval: $(JSON.parse(self[0].contents)['submission_status'])
    loadContents: true

baseCommand: score_met.py
arguments:
- prefix: --parent_id
  valueFrom: $(inputs.parent_id)
- prefix: --private_parent_id
  valueFrom: $(inputs.private_parent_id)
- prefix: -s
  valueFrom: $(inputs.synapse_config.path)
- prefix: -p
  valueFrom: $(inputs.input_file.path)
- prefix: -g
  valueFrom: $(inputs.goldstandard.path)
- prefix: -c
  valueFrom: $(inputs.gandlf_config.path)
- prefix: -o
  valueFrom: results.json

hints:
  DockerRequirement:
    dockerPull: docker.synapse.org/syn53708126/gandlf-evaluation:v1.0.0-master-cpu

s:author:
- class: s:Person
  s:identifier: https://orcid.org/0000-0002-5622-7998
  s:email: verena.chung@sagebase.org
  s:name: Verena Chung

s:codeRepository: https://github.com/Sage-Bionetworks-Challenges/brats-infra
s:license: https://spdx.org/licenses/Apache-2.0

$namespaces:
  s: https://schema.org/
