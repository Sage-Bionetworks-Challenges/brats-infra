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
- id: gt2_synid
  type: string
- id: label
  type: string
- id: config
  type: string?
expression: |2-

  ${
    // BraTS-GLI
    if (inputs.queue == "9615898") {
      return {
        gt_synid: "syn64912121",  // Pre GT
        gt2_synid: "syn61790732",  // Post GT
        label: "BraTS-GLI"
      };
    } 
    // BraTS-MEN
    else if (inputs.queue == "9615899") {
      return {
        gt_synid: "syn51930262",
        gt2_synid: "syn67006969", // empty zip
        label: "BraTS-MEN",
      };
    } 
    // BraTS-MEN-RT
    else if (inputs.queue == "9615900") {
      return {
        gt_synid: "syn61484747",
        gt2_synid: "syn67006969", // empty zip
        label: "BraTS-MEN-RT",
      };
    } 
    // BraTS-MET
    else if (inputs.queue == "9615901") {
      return {
        gt_synid: "syn64915944",
        gt2_synid: "syn67006969", // empty zip
        label: "BraTS-MET",
        config: "syn68603937"
      };
    } 
    // BraTS-SSA
    else if (inputs.queue == "9615902") {
      return {
        gt_synid: "syn61612353",
        gt2_synid: "syn67006969", // empty zip
        label: "BraTS-SSA",
      };
    } 
    // BraTS-PED
    else if (inputs.queue == "9615903") {
      return {
        gt_synid: "syn60969497",
        gt2_synid: "syn67006969", // empty zip
        label: "BraTS-PED",
      }
    }
    // BraSyn
    else if (inputs.queue == "9615905") {
      return {
        gt_synid: "syn60969497",
        gt2_synid: "syn67006969", // empty zip
        label: "BraSyn",
        config: "syn68741960"
      }
    }
    else {
      throw 'invalid queue';
    }
  }
