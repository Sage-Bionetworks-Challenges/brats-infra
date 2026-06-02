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
      #!/usr/bin/env python3
      import argparse
      import json
      import synapseclient

      def get_args():
          parser = argparse.ArgumentParser()
          parser.add_argument("-s", "--submissionid", type=int, required=True)
          parser.add_argument("-c", "--synapse_config", required=True)
          parser.add_argument("-r", "--results", required=True)
          parser.add_argument("-p", "--private_annotations", nargs="*", default=[])
          return parser.parse_args()

      def get_participant(syn, sub):
          """Return (participant_id, display_name) for a submission."""
          team_id = sub.get("teamId")
          if team_id:
              return team_id, syn.getTeam(team_id)["name"]
          return sub.userId, syn.getUserProfile(sub.userId)["userName"]

      def main():
          args = get_args()
          syn = synapseclient.Synapse(configPath=args.synapse_config)
          syn.login(silent=True)

          sub = syn.getSubmission(args.submissionid)
          participant_id, name = get_participant(syn, sub)
          evaluation = syn.getEvaluation(sub.evaluationId)

          with open(args.results) as f:
              annots = json.load(f)

          status = annots.get("submission_status")
          if status is None:
              raise ValueError("score.py must return 'submission_status' in results JSON")

          if status == "SCORED":
              csv_id = annots.pop("submission_scores")
              annots.pop("submission_status")
              for key in args.private_annotations:
                  annots.pop(key, None)

              metrics = "\n".join(f"  {k}: {v}" for k, v in annots.items())
              csv_url = f"https://www.synapse.org/#!Synapse:{csv_id}"
              subject = f"Submission to '{evaluation.name}' scored!"
              message = (
                  f"Hello {name},\n\n"
                  f"Your submission (id: {sub.id}) has been scored. "
                  f"Metric averages:\n\n{metrics}\n\n"
                  f"Individual scores are available here: {csv_url}"
              )
          else:
              subject = f"Submission to '{evaluation.name}' not scored"
              message = (
                  f"Hello {name},\n\n"
                  f"Unfortunately, your submission (id: {sub.id}) could not be scored, "
                  "possibly due to mismatches in origin or orientation. "
                  "Please review the spatial characteristics of your predictions."
              )

          message += "\n\nSincerely,\nChallenge Administrator"
          syn.sendMessage(
              userIds=[participant_id],
              messageSubject=subject,
              messageBody=message,
          )


      if __name__ == "__main__":
          main()

inputs:
- id: submissionid
  type: int
- id: synapse_config
  type: File
- id: results
  type: File
- id: private_annotations
  type: string[]?

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
- prefix: -r
  valueFrom: $(inputs.results.path)
- prefix: -p
  valueFrom: $(inputs.private_annotations)

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