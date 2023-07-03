#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: CommandLineTool

label: Validate segmentations

requirements:
- class: InlineJavascriptRequirement

inputs:
- id: input_file
  type: File
- id: goldstandard
  type: File
- id: entity_type
  type: string

outputs:
- id: results
  type: File
  outputBinding:
    glob: results.json
- id: status
  type: 
    type: enum
    symbols:
      - INVALID
      - VALIDATED
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

baseCommand: validate.py
arguments:
- prefix: -p
  valueFrom: $(inputs.input_file)
- prefix: -g
  valueFrom: $(inputs.goldstandard.path)
- prefix: -e
  valueFrom: $(inputs.entity_type)
- prefix: -o
  valueFrom: results.json

hints:
  DockerRequirement:
    dockerPull: docker.synapse.org/syn51156910/captk-evaluation:v1

s:author:
- class: s:Person
  s:identifier: https://orcid.org/0000-0002-5622-7998
  s:email: verena.chung@sagebase.org
  s:name: Verena Chung

s:codeRepository: https://github.com/Sage-Bionetworks-Challenges/brats2023
s:license: https://spdx.org/licenses/Apache-2.0

$namespaces:
  s: https://schema.org/
