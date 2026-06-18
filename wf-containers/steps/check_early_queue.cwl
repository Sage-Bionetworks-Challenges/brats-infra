#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: CommandLineTool

label: Check for early queue submission

requirements:
- class: InlineJavascriptRequirement
- class: InitialWorkDirRequirement
  listing:
  - entryname: check_early_queue.py
    entry: |
      #!/usr/bin/env python
      import synapseclient
      import argparse
      import json

      SUBMISSION_VIEW = "syn75251711"
      EARLY_QUEUE_IDS = [9619626, 9619668, 9619669, 9619670, 9619671]
      STANDARD_QUEUE_IDS = [9619627, 9619629, 9619630, 9619631, 9619632]

      parser = argparse.ArgumentParser()
      parser.add_argument("-s", "--submissionid", required=True, help="Submission ID")
      parser.add_argument("-c", "--synapse_config", required=True, help="credentials file")
      parser.add_argument("--previous_status", required=True, help="Status from previous validation step")

      args = parser.parse_args()
      results = {"submission_status": args.previous_status}

      if args.previous_status != "INVALID":
        syn = synapseclient.Synapse(configPath=args.synapse_config)
        syn.login()

        sub = syn.getSubmission(args.submissionid, downloadFile=False)
        eval_id = int(sub.evaluationId)

        if eval_id in STANDARD_QUEUE_IDS:
          submitter_id = str(sub.get("teamId") or sub.userId)
          early_ids_str = ",".join(str(i) for i in EARLY_QUEUE_IDS)
          query = (
            f"SELECT * FROM {SUBMISSION_VIEW} "
            f"WHERE evaluationid IN ({early_ids_str}) "
            f"AND submitterid = '{submitter_id}' "
            f"LIMIT 1"
          )
          rows = list(syn.tableQuery(query).asDataFrame().itertuples())
          if rows:
            results["submission_status"] = "INVALID"
            results["submission_errors"] = (
              "Your team has already submitted to the EARLY Docker track. "
              "This submission to the standard Docker track will not "
              "be evaluated."
            )

      with open("results.json", "w") as f:
        json.dump(results, f, indent=2)

inputs:
- id: submissionid
  type: int
- id: synapse_config
  type: File
- id: previous_status
  type: string

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
- id: submission_errors
  type: string
  outputBinding:
    glob: results.json
    outputEval: $(JSON.parse(self[0].contents)['submission_errors'] || '')
    loadContents: true

baseCommand: python3
arguments:
- valueFrom: check_early_queue.py
- prefix: -s
  valueFrom: $(inputs.submissionid)
- prefix: -c
  valueFrom: $(inputs.synapse_config.path)
- prefix: --previous_status
  valueFrom: $(inputs.previous_status)

hints:
  DockerRequirement:
    dockerPull: sagebionetworks/synapsepythonclient:v4.9.0

s:author:
- class: s:Person
  s:identifier: https://orcid.org/0000-0002-5622-7998
  s:email: verena.chung@sagebase.org
  s:name: Verena Chung

s:codeRepository: https://github.com/Sage-Bionetworks-Challenges/brats-infra
s:license: https://spdx.org/licenses/Apache-2.0

$namespaces:
  s: https://schema.org/
