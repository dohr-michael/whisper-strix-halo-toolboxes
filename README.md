# Whisper.cpp on AMD Strix Halo

Build and run whisper.cpp with ROCm/HIP on Linux AMD Ryzen AI Max (gfx1151).
Inspired by [kyuz0's AMD Strix Halo toolboxes](https://github.com/kyuz0/amd-strix-halo-toolboxes).
This independent project packages whisper.cpp; it is not an upstream fork or an official AMD image.

## What is included

- Fedora 43 ROCm packages, matching the original local setup.
- whisper-server, whisper-cli, whisper-bench and whisper-quantize.
- GPU compilation for gfx1151, with GGML_HIP_NO_VMM=ON.
- A pinned whisper.cpp revision, built inside the container (no host binaries).
- A GitHub Actions build and GHCR publication workflow, with CLI smoke checks.

The initial source revision is `02612981545f58188a44de99b8a4710793714629`.
Fedora packages and base-image tags can change; this is not a bit-for-bit reproducible build.
Only the ROCm backend is provided initially. These are ordinary OCI containers;
Toolbx/Distrobox integration and Vulkan variants have not been validated.

## Requirements

Linux x86-64 with a working AMD GPU driver, `/dev/kfd`, `/dev/dri`, and Podman
or Docker. The host kernel/firmware must support your GPU. ROCm userspace is
provided by the image. Rootless Podman users need access to both GPU devices;
`--group-add keep-groups` preserves supplementary device-group permissions.

## Build

```sh
podman build -f Containerfile -t localhost/whisper-strix-halo:dev .
podman run --rm localhost/whisper-strix-halo:dev --help
```

Use `--build-arg BUILD_JOBS=2` to reduce build memory usage. For an intentional
source update, pass `--build-arg WHISPER_REF=<full-commit-sha>` and validate GPU
inference before changing the default revision. `GGML_NATIVE=OFF` avoids baking
the builder's CPU instruction set into published binaries.

## Start the server

Place a whisper.cpp GGML model (for example `ggml-large-v3-turbo.bin`) in `models/`.
Use the [upstream model instructions](https://github.com/ggml-org/whisper.cpp/tree/master/models)
to obtain it. Models and recordings are not included in this repository or image.

```sh
mkdir -p models
cp .env.example .env
# Edit MODELS_DIR and MODEL_FILE in .env as needed.
podman compose up -d
```

For a local build, set `WHISPER_IMAGE=localhost/whisper-strix-halo:dev` in `.env`.
Podman Compose requires a Compose provider; `docker compose up -d` is also supported.
The default host binding is localhost:8081. The server has no authentication;
use an authenticated reverse proxy if exposing it remotely.

Rootless Podman can instead run directly with host group access:

```sh
podman run --rm --device /dev/kfd --device /dev/dri \
  --group-add keep-groups --security-opt label=disable \
  -p 127.0.0.1:8081:8080 -v "$PWD/models:/models:ro" \
  localhost/whisper-strix-halo:dev \
  -m /models/ggml-large-v3-turbo.bin --host 0.0.0.0 --port 8080 \
  --inference-path /v1/audio/transcriptions --threads 4 --convert --language auto
```

```sh
curl http://localhost:8081/v1/audio/transcriptions \
  -F file=@sample.wav -F response_format=json
```

This configures the URL used by OpenAI-style transcription clients; it does not
promise full OpenAI API compatibility. `--convert` invokes Fedora's ffmpeg-free;
codec availability depends on that package.

## Validation and publication

GitHub Actions builds on pull requests and publishes to
`ghcr.io/dohr-michael/whisper-strix-halo-toolboxes` on main and version tags.
Tags include `rocm-fedora43`, a commit SHA tag, and release tags when present.
No registry password is needed: publication uses the repository's GITHUB_TOKEN.
A newly created GHCR package may need its visibility changed to public in GitHub
package settings before anonymous pulls work.

Hosted CI checks startup without a GPU. It cannot validate gfx1151 inference.
Before a release, run whisper-cli on real audio with the target GPU, inspect the
logs for the HIP backend, and check the transcription. No benchmark claims are
made. The existing local preparation used privileged containers; the examples
here start with explicit GPU devices and SELinux label disabling, so host-specific
permissions may still need adjustment.

## License and provenance

Repository packaging is MIT licensed. whisper.cpp and the bundled system packages
retain their own licenses; the whisper.cpp license is included in the image.
The packaging and documentation were prepared with AI assistance and require
maintainer review. No source modifications are submitted to whisper.cpp.
