#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: ExpressionTool

label: Check submission status
doc: >
  Check the current submission status; if INVALID, throw an exception to
  end the workflow.

requirements:
- class: InlineJavascriptRequirement

inputs:
- id: status
  type: string
- id: previous_annotation_finished
  type: boolean?
- id: previous_email_finished
  type: boolean?

outputs:
- id: finished
  type: boolean
expression: |2

  ${
    if(["INVALID", "NOT_SCORED"].includes(inputs.status)) {
      throw 'invalid submission';
    } else {
      return {finished: true};
    }
  }
