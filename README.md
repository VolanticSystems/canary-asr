# canary-asr image

Slim NeMo + pyannote container for exhaustive ASR + speaker diarization on Vast.ai.
Built on PyTorch 2.5.1 + CUDA 12.4 instead of the official NeMo container (saves
~20 GB on pull time).

Pull: `ghcr.io/bob7123/canary-asr:v1`

## What's in it

| layer | provides |
|---|---|
| `pytorch/pytorch:2.5.1-cuda12.4-cudnn9-runtime` | PyTorch + CUDA + cuDNN |
| apt | git, ffmpeg, libsndfile1, build-essential, openssh-client |
| pip | nemo_toolkit[asr], pyannote.audio, webrtcvad-wheels, soundfile, PyYAML |

## Build

Triggered automatically by GitHub Actions on any push to `Dockerfile` or `build.yml`.
Manual trigger: `gh workflow run build.yml`.

## One-time post-build step

GHCR packages are created **private** by default even if the source repo is public.
After the first successful build, make the package public:

1. https://github.com/users/bob7123/packages/container/canary-asr/settings
2. Scroll to Danger Zone, click **Change visibility**, pick **Public**.

After that, Vast (and anyone else) can pull anonymously.

## Pin the dependency set

Once a build resolves cleanly, copy the resolved versions out of `pip freeze` on the
running container and pin them in the Dockerfile to lock the image.
