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
- id: synid
  type: string
- id: label
  type: string
expression: |2-

  ${
    // BraTS-GLI 2023
    if (inputs.queue == "9615768") {
      return {
        synid: "syn51514102",
        label: "BraTS-GLI"
      };
    } 
    // BraTS-GLI 2024
    else if (inputs.queue == "9615769") {
      return {
        synid: "syn61790732",
        label: "BraTS-GLI"
      };
    } 
    // BraTS-MEN 2023
    else if (inputs.queue == "9615770") {
      return {
        synid: "syn51930262",
        label: "BraTS-MEN"
      };
    } 
    // BraTS-MEN-RT 2024
    else if (inputs.queue == "9615771") {
      return {
        synid: "syn61484747",
        label: "BraTS-MEN-RT"
      };
    }
    // BraTS-MET 2023 
    else if (inputs.queue == "9615776") {
      return {
        synid: "syn52237053",
        label: "BraTS-MET"
      };
    } 
    // BraTS-PED 2023
    else if (inputs.queue == "9615772") {
      return {
        synid: "syn51929881",
        label: "BraTS-PED"
      };
    } 
    // BraTS-PED 2024
    else if (inputs.queue == "9615773") {
      return {
        synid: "syn60969497",
        label: "BraTS-PED"
      };
    }
    // BraTS-SSA 2023
    else if (inputs.queue == "9615774") {
      return {
        synid: "syn52045897",
        label: "BraTS-SSA"
      };
    }
    // BraTS-SSA 2024
    else if (inputs.queue == "9615775") {
      return {
        synid: "syn61612353",
        label: "BraTS-SSA"
      };
    } else {
      throw 'invalid queue';
    }
  }
