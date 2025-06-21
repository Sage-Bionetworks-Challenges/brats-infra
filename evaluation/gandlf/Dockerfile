FROM ghcr.io/mlcommons/gandlf:master-cpu

WORKDIR /usr/local/bin/

COPY requirements.txt .
RUN python3 -m pip install -r requirements.txt
COPY *.py .

# Override the base image's entrypoint so that GaNDLF CLI
# doesn't run by default
ENTRYPOINT [ "/usr/bin/env" ]
