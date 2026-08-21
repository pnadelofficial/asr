# CUDA 12.2 runtime is enough: every wheel here ships prebuilt binaries.
# Swap to "12.2.0-devel-ubuntu22.04" only if you later need nvcc.
ARG CUDA_IMAGE="12.2.0-runtime-ubuntu22.04"
FROM nvidia/cuda:${CUDA_IMAGE}
 
LABEL maintainer="Peter Nadel <peter.nadel@tufts.edu>"
LABEL description="Miniforge + ASR stack (Whisper, pyannote.audio) on Ubuntu 22.04 / CUDA 12.2"
 
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
 
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    PIP_NO_CACHE_DIR=1 \
    PYTHONDONTWRITEBYTECODE=1
 
# Single apt layer, lists cleaned. No `apt-get upgrade` -- on an nvidia/cuda
# base it can pull in CUDA packages that don't match the image's tag.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      build-essential \
      wget \
      git \
      ca-certificates \
      locales \
      ffmpeg \
 && locale-gen en_US.UTF-8 \
 && update-locale LANG=en_US.UTF-8 \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*
 
# ---------------------------------------------------------------- miniforge
ENV CONDA_DIR=/opt/miniforge
ARG MINIFORGE_VERSION=25.3.1-0
 
RUN wget -q "https://github.com/conda-forge/miniforge/releases/download/${MINIFORGE_VERSION}/Miniforge3-${MINIFORGE_VERSION}-Linux-x86_64.sh" \
      -O /tmp/miniforge.sh \
 && bash /tmp/miniforge.sh -b -p "${CONDA_DIR}" \
 && rm -f /tmp/miniforge.sh
 
# ------------------------------------------------------------------ asr env
ARG PYTHON_VERSION=3.11
ENV ASR_ENV=${CONDA_DIR}/envs/asr
 
RUN "${CONDA_DIR}/bin/conda" create -y -n asr "python=${PYTHON_VERSION}" pip \
 && "${CONDA_DIR}/bin/conda" clean -a -y
 
# Put the env's bin FIRST on PATH. Do NOT set CONDA_PREFIX by hand -- conda
# manages that variable itself, and a wrong value silently breaks activation.
ENV PATH=${ASR_ENV}/bin:${CONDA_DIR}/condabin:${PATH}
 
# Fail loudly at build time if the interpreter isn't the one we think it is.
RUN which python pip \
 && python -c "import sys; assert sys.version_info[:2] == (3, 11), sys.version; print(sys.version)"
 
# ------------------------------------------------------------- python deps
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
 
# Smoke test. The second import is the one that breaks if speechbrain
# resolves to >=1.0 alongside pyannote.audio 3.1.1.
RUN python -c "import torch; print('torch', torch.__version__, 'cuda', torch.version.cuda)" \
 && python -c "import whisper; print('whisper ok')" \
 && python -c "from pyannote.audio.pipelines.speaker_verification import PretrainedSpeakerEmbedding; print('pyannote ok')"
 
# pyannote's pretrained pipelines are gated on Hugging Face: accept the model
# terms, then pass a token at runtime, e.g.
#   docker run --gpus all -e HF_TOKEN=hf_xxx -v $PWD/audio:/app/audio <image>
ENV HF_HOME=/app/.cache/huggingface
 
CMD ["python"]