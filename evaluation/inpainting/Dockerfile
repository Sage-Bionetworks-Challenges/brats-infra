FROM bitnami/pytorch:2.8.0

# Temporarily change to root user in order to create
# the .synapseCache folder required by synapseclient.
USER 0
RUN mkdir /.synapseCache
USER $CONTAINER_USER_I

WORKDIR /app

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY *.py .
