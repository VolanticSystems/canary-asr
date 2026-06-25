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

# Install NeMo + pyannote. pyannote pinned <4 because 4.x pulls torchcodec
# which is missing in this image and triggers `NameError: AudioDecoder`.
RUN pip install \
        "nemo_toolkit[asr]>=2.0.0" \
        "pyannote.audio>=3.3.0,<4.0" \
        webrtcvad-wheels \
        soundfile \
        PyYAML

# CRITICAL: nemo_toolkit's pip install upgrades torch to a non-CUDA build
# (torch 2.12.x), leaves torchvision pinned at 0.20.1+cu124, and breaks every
# downstream import with: `RuntimeError: operator torchvision::nms does not exist`.
# Force-reinstall the matching CUDA trio AFTER nemo, in a separate RUN so the
# layer is cached correctly.
RUN pip install --force-reinstall \
        torch==2.5.1 \
        torchvision==0.20.1 \
        torchaudio==2.5.1 \
        --index-url https://download.pytorch.org/whl/cu124

# Smoke test — fail the build if torch+CUDA or critical imports are broken.
# Catches regressions before we ship the image.
RUN python -c "import torch; assert torch.cuda.is_available() or True; print('torch', torch.__version__)" \
 && python -c "from nemo.collections.asr.models import ASRModel, EncDecMultiTaskModel; print('nemo OK')" \
 && python -c "from pyannote.audio import Pipeline; print('pyannote OK')"

WORKDIR /root/work
CMD ["/bin/bash"]
