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
- id: synid2
  type: string?
- id: label
  type: string
expression: |2-

  ${
    // BraTS-GLI
    if (inputs.queue == "9615898") {
      return {
        synid: "syn64912121",  // Pre GT
        synid2: "syn61790732"  // Post GT
        label: "BraTS-GLI"
      };
    } 
    // BraTS-MEN
    else if (inputs.queue == "9615899") {
      return {
        synid: "syn51930262",
        synid2: "",
        label: "BraTS-MEN"
      };
    } 
    // BraTS-MEN-RT
    else if (inputs.queue == "9615900") {
      return {
        synid: "syn61484747",
        synid2: "",
        label: "BraTS-MEN-RT"
      };
    } 
    // BraTS-MET
    else if (inputs.queue == "9615901") {
      return {
        synid: "syn64915944",
        synid2: "",
        label: "BraTS-MET"
      };
    } 
    // BraTS-SSA
    else if (inputs.queue == "9615902") {
      return {
        synid: "syn61612353",
        synid2: "",
        label: "BraTS-SSA"
      };
    } 
    // BraTS-PED
    else if (inputs.queue == "9615903") {
      return {
        synid: "syn60969497",
        synid2: "",
        label: "BraTS-PED"
      }
    }
    else {
      throw 'invalid queue';
    }
  }
