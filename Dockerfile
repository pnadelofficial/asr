ARG CUDA_IMAGE="12.2.0-devel-ubuntu22.04"
FROM nvidia/cuda:${CUDA_IMAGE}

LABEL maintainer="Peter Nadel <peter.nadel@tufts.edu>"

LABEL description="This container contains miniforge with a stack of ASR dependencies installed on ubuntu:24.04."

ENV PATH=/opt/miniforge/bin:$PATH \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

RUN apt-get update && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends build-essential wget git ca-certificates locales \
    && locale-gen en_US.UTF-8 \
    && update-locale LANG=en_US.UTF-8 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN wget https://github.com/conda-forge/miniforge/releases/download/25.3.1-0/Miniforge3-25.3.1-0-Linux-x86_64.sh \
    && bash Miniforge3-25.3.1-0-Linux-x86_64.sh  -b -p /opt/miniforge \
    && rm -f Miniforge3-25.3.1-0-Linux-x86_64.sh

RUN conda update --all \
    && conda clean --all --yes \
    && rm -rf /root/.cache/pip

COPY requirements.txt .
RUN CMAKE_ARGS="-DGGML_CUDA=on" pip install --no-cache-dir -r requirements.txt

SHELL ["/bin/bash", "-c"]