#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: CommandLineTool
label: Validate inpainting submission

requirements:
- class: InlineJavascriptRequirement

inputs:
- id: input_file
  type: File
- id: goldstandard
  type: File
- id: entity_type
  type: string
- id: pred_pattern
  type: string
- id: gold_pattern
  type: string

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
- id: invalid_reasons
  type: string
  outputBinding:
    glob: results.json
    outputEval: $(JSON.parse(self[0].contents)['submission_errors'])
    loadContents: true

baseCommand: /app/validate.py
arguments:
- prefix: -p
  valueFrom: $(inputs.input_file)
- prefix: -g
  valueFrom: $(inputs.goldstandard.path)
- prefix: -e
  valueFrom: $(inputs.entity_type)
- prefix: -o
  valueFrom: results.json
- prefix: --pred_pattern
  valueFrom: $(inputs.pred_pattern)
- prefix: --gold_pattern
  valueFrom: $(inputs.gold_pattern)

hints:
  DockerRequirement:
    dockerPull: docker.synapse.org/syn53708126/inpainting-evaluation:2023-v1.1.0

s:author:
- class: s:Person
  s:identifier: https://orcid.org/0000-0002-5622-7998
  s:email: verena.chung@sagebase.org
  s:name: Verena Chung

s:codeRepository: https://github.com/Sage-Bionetworks-Challenges/brats-infra
s:license: https://spdx.org/licenses/Apache-2.0

$namespaces:
  s: https://schema.org/
