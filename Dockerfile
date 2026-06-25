FROM pytorch/pytorch:2.5.1-cuda12.4-cudnn9-runtime

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

# System deps that NeMo + pyannote + soundfile + webrtcvad need.
RUN apt-get update && apt-get install -y --no-install-recommends \
        git \
        build-essential \
        ffmpeg \
        libsndfile1 \
        libsndfile1-dev \
        openssh-client \
        wget \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Python deps. Pin loosely on the first build; tighten after we know
# the resolved set works end to end.
RUN pip install \
        "nemo_toolkit[asr]>=2.0.0" \
        "pyannote.audio>=3.3.0" \
        webrtcvad-wheels \
        soundfile \
        PyYAML

WORKDIR /root/work
CMD ["/bin/bash"]
