#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: CommandLineTool
label: Send email with results

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
      parser.add_argument("--status", help="validation status")

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

      subject = f"Submission to '{evaluation.name}' "
      message = [f"Hello {name},\n\n"]
      if args.status == 'INVALID':
        subject += "invalid"
        message.append(
          f"Your submission (ID {args.submissionid}) is not a Docker image. "
          "Please try again."
        )
      else:
        subject += "accepted"
        message.append(
          "Thank you for participating in the BraTS-Lighthouse 2025 Challenge!\n\n"
          "This email is to notify you that we have received your Docker image for "
          "final evaluation.\n\n"
          "<b>Important!: we did not run your submitted Docker model to verify "
          "that it can run successfully</b>. Therefore, we highly encourage you to "
          "<a href='https://www.synapse.org/Synapse:syn64153130/wiki/633742'>"
          "locally run your Docker model</a> against the sample datasets to catch "
          "possible errors, and submit again if needed."
        )
      message.append(
        "\n\n"
        "Sincerely,\n"
        "BraTS Organizing Committee"
      )
      syn.sendMessage(
        userIds=[participantid],
        messageSubject=subject,
        messageBody="".join(message))

inputs:
- id: submissionid
  type: int
- id: synapse_config
  type: File
- id: status
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
- prefix: --status
  valueFrom: $(inputs.status)

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
