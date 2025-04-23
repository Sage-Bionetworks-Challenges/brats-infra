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
    // BraTS-GLI (Pre)
    if (inputs.queue == "9615898") {
      return {
        synid: "syn64912121",
        label: "BraTS-GLI"
      };
    } 
    // BraTS-MEN
    else if (inputs.queue == "9615899") {
      return {
        synid: "syn51930262",
        label: "BraTS-MEN"
      };
    } 
    // BraTS-MEN-RT
    else if (inputs.queue == "9615900") {
      return {
        synid: "syn61484747",
        label: "BraTS-MEN-RT"
      };
    } 
    // BraTS-MET
    else if (inputs.queue == "9615901") {
      return {
        synid: "syn64915944",
        label: "BraTS-MET"
      };
    } 
    // BraTS-SSA
    else if (inputs.queue == "9615902") {
      return {
        synid: "syn61612353",
        label: "BraTS-SSA"
      };
    } 
    else if (inputs.queue == "9615903") {
      return {
        synid: "syn60969497",
        label: "BraTS-PED"
      }
    }
    else {
      throw 'invalid queue';
    }
  }
