#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: CommandLineTool
label: Get MLCube config files then upload to Synapse

requirements:
- class: InlineJavascriptRequirement
- class: InitialWorkDirRequirement
  listing:
  - entryname: extract_config.py
    entry: |
      #!/usr/bin/env python
      import synapseclient
      import argparse
      import json
      import os
      import tarfile

      parser = argparse.ArgumentParser()
      parser.add_argument("-i", "--input_file", required=True, help="Input file to extract")
      parser.add_argument("-c", "--synapse_config", required=True, help="credentials file")
      parser.add_argument("--parent_id", required=True, help="parent ID to upload config")
      args = parser.parse_args()

      syn = synapseclient.Synapse(configPath=args.synapse_config)
      syn.login()

      results = {
        'mlcube': "",
        'parameters': "",
        'additional_files': ""
      }
      if tarfile.is_tarfile(args.input_file):
        with tarfile.open(args.input_file) as tar_ref:
          for member in tar_ref:
            if os.path.split(member.name)[1] == 'mlcube.yaml':
              tar_ref.extract(member)
              mlcube = synapseclient.File(member.name, parent=args.parent_id)
              mlcube = syn.store(mlcube)
              results['mlcube'] = mlcube.id
            elif os.path.split(member.name)[1] == 'parameters.yaml':
              tar_ref.extract(member)
              parameters = synapseclient.File(member.name, parent=args.parent_id)
              parameters = syn.store(parameters)
              results['parameters'] = parameters.id
            elif os.path.split(member.name)[1] == 'additional_files.tar.gz':
              tar_ref.extract(member)
              add = synapseclient.File(member.name, parent=args.parent_id)
              add = syn.store(add)
              results['additional_files'] = add.id
      with open('results.json', 'w') as out:
        out.write(json.dumps(results))


inputs:
- id: input_file
  type: File
- id: parent_id
  type: string
- id: synapse_config
  type: File

outputs:
- id: mlcube
  type: string
  outputBinding:
    glob: results.json
    outputEval: $(JSON.parse(self[0].contents)['mlcube'])
    loadContents: true
- id: parameters
  type: string
  outputBinding:
    glob: results.json
    outputEval: $(JSON.parse(self[0].contents)['parameters'])
    loadContents: true
- id: addtional_files
  type: string
  outputBinding:
    glob: results.json
    outputEval: $(JSON.parse(self[0].contents)['additional_files'])
    loadContents: true

baseCommand: python3
arguments:
- valueFrom: extract_config.py
- prefix: -i
  valueFrom: $(inputs.input_file)
- prefix: -c
  valueFrom: $(inputs.synapse_config.path)
- prefix: --parent
  valueFrom: $(inputs.parent_id)

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