FROM --platform=linux/amd64 python:3.10-slim

WORKDIR /usr/local/bin

COPY BraTS-2024-Metrics/requirements.txt .
RUN pip install -r requirements.txt \
    && pip install synapseclient==3.2.0

COPY BraTS-2024-Metrics/surface_distance /usr/local/bin/surface_distance
COPY BraTS-2024-Metrics/metrics_*.py .
COPY BraTS-2023-Metrics/metrics.py .
COPY *.py .
