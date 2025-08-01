#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: ExpressionTool
label: Check mlcube yaml file
doc: >
  Check whether `mlcube.yaml` has been uploaded for the submission (will have
  a synID if so); if synID is "", throw an expection to end the workflow.

requirements:
- class: InlineJavascriptRequirement

inputs:
- id: mlcube
  type: string
- id: previous_annotation_finished
  type: boolean?

outputs:
- id: finished
  type: boolean
expression: |2
  ${
    if(inputs.mlcube == ""){
      throw 'Submitted MLCube tarball does not contain a `mlcube.yaml`. Please try again.';
    } else {
      return {finished: true};
    }
  }

s:author:
- class: s:Person
  s:identifier: https://orcid.org/0000-0002-5622-7998
  s:email: verena.chung@sagebase.org
  s:name: Verena Chung

s:codeRepository: https://github.com/Sage-Bionetworks-Challenges/brats2023
s:license: https://spdx.org/licenses/Apache-2.0

$namespaces:
  s: https://schema.org/
