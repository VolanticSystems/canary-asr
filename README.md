# canary-asr

The GPU runtime image for [`canary-pipeline`](https://github.com/VolanticSystems/canary-pipeline)
— exhaustive speech-to-text and speaker diarization for long recordings. This
repo is the Docker image; the orchestration logic that drives it, plus the
instrumentation and guardrails that make it production-safe, lives in the
[pipeline repo](https://github.com/VolanticSystems/canary-pipeline#instrumentation).

```
docker pull ghcr.io/volanticsystems/canary-asr:v1
```

## Why this image and not the obvious alternatives

**Why not NVIDIA's official NeMo container?** Because that's what this
started as, and it didn't hold up under real use. `nvcr.io/nvidia/nemo` is
25-30 GB. On a rented GPU that gets torn down after every job, that's a
20-30 minute tax paid on *every single rental* — and on a mediocre host, the
pull sometimes never finished at all (see the evolution below: this is the
literal reason the custom image exists). This image is ~13 GB, and most of
that is the model weights, not framework bloat.

**Why not just pull the models from HuggingFace at runtime, like most
NeMo tutorials do?** Because every rented instance is ephemeral — nothing
persists between jobs — so "download once, cache forever" doesn't apply.
Every job was independently re-downloading ~6 GB from HuggingFace's
throttled anonymous-access path, 10-15 minutes of pure dead time, before a
single second of transcription happened. Both models' weights are baked
into this image at build time instead, so a rental goes straight to work.

**Why not just `pip install nemo_toolkit pyannote.audio` yourself?**
You can — and you'll hit two non-obvious breakages doing it (below), because
we did too. This image has already absorbed both, plus a build-time smoke
test so a future regression fails the CI build instead of failing silently
on a GPU you're paying for by the minute.

## How this image evolved

Not designed clean upfront — built, broken by real jobs, and hardened one
incident at a time:

1. **Started on NVIDIA's official NeMo container.** It worked, technically.
   It also meant a 25+ minute pull on a good host, and on a bad one, a
   Docker layer would sometimes retry-loop indefinitely with zero forward
   progress — the run just never started. That unreliability is what
   justified building a custom image at all.

2. **Built a slim image on a plain PyTorch base instead** — just CUDA,
   cuDNN, and the actual dependencies, nothing NVIDIA ships that this
   pipeline doesn't use. First attempt: **broke on its own dependencies.**
   `pip install "nemo_toolkit[asr]"` silently upgrades torch to a CPU-only
   build and leaves `torchvision` pinned to a version that no longer
   matches — every downstream import failed with
   `RuntimeError: operator torchvision::nms does not exist`. Fixed by
   force-reinstalling a version-matched CUDA torch/torchvision/torchaudio
   trio as its own layer, *after* NeMo's install, not before.

3. **pyannote's newer major version broke the same way.** `pyannote.audio`
   4.x pulls in `torchcodec`, which isn't in this image and isn't needed for
   the diarization model actually in use — import failed with
   `NameError: AudioDecoder is not defined`. Pinned to `pyannote.audio<4.0`.

4. **Added a build-time smoke test.** Both breakages above would have
   shipped silently and failed on a rented, paid-by-the-minute GPU instead
   of in CI. Now the build imports `torch`, both NeMo model classes, and
   `pyannote.audio.Pipeline` before the image is allowed to publish — a
   dependency regression fails the free build, not the paid rental.

5. **Found the recurring HuggingFace tax in production, months after the
   image felt "done."** Every real transcription job was still burning
   10-15 minutes on model downloads that should have been unnecessary — the
   image was slim, but the *weights* weren't in it. Baked both ASR models'
   weights into the image at build time (`RUN python -c
   "...from_pretrained(...)"`), moving that cost from every job to once, in
   CI. Image grew from ~6.3 GB to ~13 GB; job startup time dropped by the
   full 10-15 minutes it used to spend waiting on HuggingFace.

6. **The image's ownership moved to this org, and *that* broke the build
   too.** A GitHub repo transfer doesn't bring the linked container package
   with it — had to trigger a fresh build under the new owner. That fresh
   build then failed outright on `invalid tag: repository name must be
   lowercase`, because `github.repository_owner` preserves an org's display
   case and Docker tags can't be mixed-case. Fixed with an explicit
   lowercase-conversion step in the workflow (see below) — worth knowing if
   you ever fork this into your own mixed-case org.

## What's in it

| Layer | Provides |
|---|---|
| `pytorch/pytorch:2.5.1-cuda12.4-cudnn9-runtime` | PyTorch + CUDA + cuDNN, version-pinned |
| apt | git, ffmpeg, libsndfile1, build-essential, openssh-client |
| pip | `nemo_toolkit[asr]`, `pyannote.audio<4.0`, soundfile, PyYAML |
| baked-in weights | Parakeet-TDT-0.6B + Canary-1b-flash model weights |

pyannote's diarization weights are the one thing *not* baked in — they're
gated behind a HuggingFace token, so they're pulled at runtime with
credentials rather than baked in at build time. They're small (~30 MB), so
the cost is negligible.

## Build

GitHub Actions rebuilds automatically on any push to `Dockerfile` or
`build.yml`. Manual trigger: `gh workflow run build.yml`. Build takes
~15-25 minutes — almost all of it downloading and caching the model weights
once, so every subsequent *pull* skips that entirely.

## What runs on top of this image

This image only holds the environment. The logic that decides what gets
transcribed, catches silent data loss, cross-checks two models against each
other, and detects a bad rental host mid-job all lives in
[`canary-pipeline`](https://github.com/VolanticSystems/canary-pipeline) —
see its [Instrumentation](https://github.com/VolanticSystems/canary-pipeline#instrumentation)
and [build-journey](https://github.com/VolanticSystems/canary-pipeline#how-this-got-built-what-off-the-shelf-got-wrong-and-what-got-learned-fixing-it)
sections for that half of the story.

## Notes for anyone forking or adapting this

- **GHCR packages default to private**, even from a public repo, and some
  orgs lock the visibility toggle at the org level (Settings → Packages →
  Package Creation must allow Public). Check both if a fresh pull 403s.
- **Docker tags must be lowercase.** If you fork this into an org or account
  with a mixed-case name, `${{ github.repository_owner }}` will break the
  build outright — see the lowercase-conversion step in `build.yml`.
- **A repo ownership transfer does not move the linked GHCR package with
  it.** Expect to trigger a fresh build under the new owner after any
  transfer.

## License

MIT — see `LICENSE`.
