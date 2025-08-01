#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: CommandLineTool

label: Send email if tarball is not found

requirements:
- class: InlineJavascriptRequirement
- class: InitialWorkDirRequirement
  listing:
  - entryname: email_results.py
    entry: |
      #!/usr/bin/env python
      import synapseclient
      import argparse
      import json
      import os
      parser = argparse.ArgumentParser()
      parser.add_argument("-s", "--submissionid", required=True, help="Submission ID")
      parser.add_argument("-c", "--synapse_config", required=True, help="credentials file")
      parser.add_argument("-m", "--mlcube_id", help="synID for MLCube yaml file")

      args = parser.parse_args()
      syn = synapseclient.Synapse(configPath=args.synapse_config)
      syn.login()

      sub = syn.getSubmission(args.submissionid)
      participantid = sub.get("teamId")
      if participantid is not None:
        name = syn.getTeam(participantid)['name']
      else:
        participantid = sub.userId
        name = syn.getUserProfile(participantid)['userName']
      evaluation = syn.getEvaluation(sub.evaluationId)

      if not args.mlcube_id:
        subject = f"Submission to '{evaluation.name}' invalid"
        message = [
            f"Hello {name},\n\n",
            f"<b>Your MLCube tarball submission (ID: {args.submissionid}) "
            "is invalid.</b> Double-check that the submitted tarball has at "
            "least a `mlcube.yaml` file and please try again.\n\n",
            "Sincerely,\n",
            "BraTS Organizing Committee"
          ]
        syn.sendMessage(
          userIds=[participantid],
          messageSubject=subject,
          messageBody="".join(message))

inputs:
- id: submissionid
  type: int
- id: synapse_config
  type: File
- id: mlcube_id
  type: string

outputs:
- id: finished
  type: boolean
  outputBinding:
    outputEval: $( true )

baseCommand: python3
arguments:
- valueFrom: email_results.py
- prefix: -s
  valueFrom: $(inputs.submissionid)
- prefix: -c
  valueFrom: $(inputs.synapse_config.path)
- prefix: -m
  valueFrom: $(inputs.mlcube_id)

hints:
  DockerRequirement:
    dockerPull: sagebionetworks/synapsepythonclient:v2.7.2

s:author:
- class: s:Person
  s:identifier: https://orcid.org/0000-0002-5622-7998
  s:email: verena.chung@sagebase.org
  s:name: Verena Chung

s:codeRepository: https://github.com/Sage-Bionetworks-Challenges/brats2023
s:license: https://spdx.org/licenses/Apache-2.0

$namespaces:
  s: https://schema.org/