#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: CommandLineTool
label: Get corresponding MLCube Docker image

requirements:
- class: InlineJavascriptRequirement
- class: InitialWorkDirRequirement
  listing:
  - entryname: get_docker_sub.py
    entry: |
      #!/usr/bin/env python
      import synapseclient
      import argparse
      import json
      import os
      import time

      parser = argparse.ArgumentParser()
      parser.add_argument("-s", "--submissionid", required=True, help="Submission ID")
      parser.add_argument("-e", "--evaluationid", required=True, help="Evaluation ID")
      parser.add_argument("-c", "--synapse_config", required=True, help="credentials file")
      parser.add_argument("-v", "--submission_view", required=True, help="synID of submission view")
      parser.add_argument("-r", "--results", required=True, help="Resulting scores")
      args = parser.parse_args()

      syn = synapseclient.Synapse(configPath=args.synapse_config)
      syn.login()

      sub = syn.getSubmission(args.submissionid, downloadFile=False)
      name = sub.get("name")
      submitter = sub.get("teamId") or sub.get("userId")
      
      query = (f"SELECT id FROM {args.submission_view} "
               f"WHERE evaluationid = {args.evaluationid} "
               f"AND name = '{name}' "
               f"AND submission_status IS NULL "
               f"AND submitterid = {submitter} ")
      res = syn.tableQuery(query).asDataFrame()["id"]
      if len(res) == 0:
        # Add a delay so that Synapse has time to refresh the submission view,
        # then try the query again.
        time.sleep(120)
        res = syn.tableQuery(query).asDataFrame()["id"]
      docker_id = 0
      if len(res) == 1:
        docker_id = res.iloc[0]

      with open('results.json', 'w') as out:
        out.write(json.dumps({
          'docker_id': int(docker_id),
          'submission_status': "MLCUBE_DOCKER_FOUND" if docker_id else "INVALID"
        }))

inputs:
- id: submissionid
  type: int
- id: synapse_config
  type: File
- id: submission_view
  type: string
- id: docker_evaluation_id
  type: int
- id: previous_annotation_finished
  type: boolean?

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
- id: docker_id
  type: int
  outputBinding:
    glob: results.json
    outputEval: $(JSON.parse(self[0].contents)['docker_id'])
    loadContents: true 

baseCommand: python3
arguments:
- valueFrom: get_docker_sub.py
- prefix: -s
  valueFrom: $(inputs.submissionid)
- prefix: -c
  valueFrom: $(inputs.synapse_config.path)
- prefix: -v
  valueFrom: $(inputs.submission_view)
- prefix: -r
  valueFrom: results.json
- prefix: -e
  valueFrom: $(inputs.docker_evaluation_id)

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
