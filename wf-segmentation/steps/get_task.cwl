#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: ExpressionTool
label: Get goldstandard based on task number

requirements:
- class: InlineJavascriptRequirement

inputs:
- id: queue
  type: string

outputs:
- id: gt_synid
  type: string
- id: cohort_label
  type: string
expression: |2-

  ${

    // BraTS-MET
    if (inputs.queue == "9619537") {
      return {
        gt_synid: "syn64915944",
        cohort_label: "BraTS-MET",
      };
    } 
    // BraTS-PED
    else if (inputs.queue == "9619538") {
      return {
        gt_synid: "syn60969497",
        cohort_label: "BraTS-PED",
      }
    }
    // BraTS-GoAT
    else if (inputs.queue == "9619683") {
      return {
        gt_synid: "syn61455588",
        cohort_label: "BraTS-GoAT",
      }
    }
    else {
      throw 'invalid queue';
    }
  }
