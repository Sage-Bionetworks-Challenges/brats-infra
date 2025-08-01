#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: CommandLineTool

label: Check submission entity type

requirements:
- class: InlineJavascriptRequirement
- class: InitialWorkDirRequirement
  listing:
  - entryname: check_submission_type.py
    entry: |
      #!/usr/bin/env python
      import synapseclient
      import argparse
      import json
      import os
      parser = argparse.ArgumentParser()
      parser.add_argument("-s", "--submissionid", required=True, help="Submission ID")
      parser.add_argument("-c", "--synapse_config", required=True, help="credentials file")

      args = parser.parse_args()
      syn = synapseclient.Synapse(configPath=args.synapse_config)
      syn.login()

      sub = syn.getSubmission(args.submissionid, downloadFile=False)
      status = "ACCEPTED" if isinstance(sub.entity, synapseclient.entity.DockerRepository) else "INVALID"
      results =   {
        "submission_status": status
      }
      with open("results.json", "w") as f:
        json.dump(results, f, indent=2)

inputs:
- id: submissionid
  type: int
- id: synapse_config
  type: File

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

baseCommand: python3
arguments:
- valueFrom: check_submission_type.py
- prefix: -s
  valueFrom: $(inputs.submissionid)
- prefix: -c
  valueFrom: $(inputs.synapse_config.path)

hints:
  DockerRequirement:
    dockerPull: sagebionetworks/synapsepythonclient:v4.9.0

s:author:
- class: s:Person
  s:identifier: https://orcid.org/0000-0002-5622-7998
  s:email: verena.chung@sagebase.org
  s:name: Verena Chung

s:codeRepository: https://github.com/Sage-Bionetworks-Challenges/brats2023
s:license: https://spdx.org/licenses/Apache-2.0

$namespaces:
  s: https://schema.org/
