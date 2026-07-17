# canary-asr

The GPU runtime image for [`canary-pipeline`](https://github.com/VolanticSystems/canary-pipeline)
— exhaustive speech-to-text and speaker diarization for long recordings. This
repo is the Docker image; the orchestration logic that drives it lives in the
pipeline repo.

```
docker pull ghcr.io/volanticsystems/canary-asr:v1
```

## What's in it

| Layer | Provides |
|---|---|
| `pytorch/pytorch:2.5.1-cuda12.4-cudnn9-runtime` | PyTorch + CUDA + cuDNN, version-pinned |
| apt | git, ffmpeg, libsndfile1, build-essential, openssh-client |
| pip | `nemo_toolkit[asr]`, `pyannote.audio<4.0`, soundfile, PyYAML |
| baked-in weights | Parakeet-TDT-0.6B + Canary-1b-flash model weights |

**Two deliberate choices worth calling out:**

- **Built on a slim PyTorch base, not NVIDIA's official NeMo container.**
  The official image is ~25-30 GB. This one is ~13 GB — most of that is the
  baked-in model weights below, not framework bloat.
- **Model weights are baked in at build time, not downloaded at runtime.**
  Every rented GPU instance used to spend 10-15 minutes on its first run
  re-pulling ~6 GB of weights from a throttled HuggingFace endpoint —
  repeated on *every single rental*, since Vast.ai instances are ephemeral.
  Baking them into the image moves that cost to CI, once, instead of paying
  it again on every job.

pyannote's diarization weights are the one exception — they're gated behind
a HuggingFace token, so they're pulled at runtime with credentials rather
than baked in. They're small (~30 MB), so the cost is negligible.

## Build

GitHub Actions rebuilds automatically on any push to `Dockerfile` or
`build.yml`. Manual trigger: `gh workflow run build.yml`.

Build takes ~15-25 minutes — most of it is downloading and caching the model
weights during the build, once, so every subsequent pull skips that entirely.

## Notes for anyone forking or adapting this

- **GHCR packages default to private**, even from a public repo, and some
  orgs lock the visibility toggle at the org level (Settings → Packages →
  Package Creation must allow Public). Check both if a fresh pull 403s.
- **Docker tags must be lowercase.** If you fork this into an org or account
  with a mixed-case name, `${{ github.repository_owner }}` will break the
  build outright — see the lowercase-conversion step in `build.yml`.
- `pyannote.audio` is pinned below 4.0 deliberately — the newer major version
  pulls in `torchcodec`, which isn't present in this image and breaks import.

## License

MIT — see `LICENSE`.
