# AMD Strix Halo Whisper.cpp Toolboxes

Container recipes for speech transcription with **whisper.cpp** on AMD Ryzen AI
Max “Strix Halo” (`gfx1151`), with ROCm/HIP and Vulkan RADV backends.

Inspired by [kyuz0/amd-strix-halo-toolboxes](https://github.com/kyuz0/amd-strix-halo-toolboxes):
one recipe per backend, shell and server usage, toolbox refresh helpers, automated
image publication, and documented benchmarks. This is an independent project;
it is not part of kyuz0's project and is not currently integrated into AI Toolbox Cockpit.

## Available toolboxes

Images are published to **ghcr.io/dohr-michael/whisper-strix-halo-toolboxes** after
successful CI builds. Check [build status](https://github.com/dohr-michael/whisper-strix-halo-toolboxes/actions)
before pulling: a recipe in this table does not imply a completed image release.

| Tag | Backend / stack | Status |
| --- | --- | --- |
| `rocm-fedora43` | Fedora 43 ROCm, HIP, gfx1151, no VMM | Based on our local Whisper preparation; standalone image validation pending |
| `vulkan-radv` | Fedora 43 Mesa RADV / Vulkan | Experimental; GPU validation pending |
| `rocm-fedora43-nightly` | Same ROCm stack, upstream Whisper master | Experimental daily build |
| `rocm-fedora43-release` / `vulkan-radv-release` | Latest stable Whisper release | Automatically built when a new release is detected |
| `vulkan-radv-nightly` | Same Vulkan stack, upstream Whisper master | Experimental daily build |

An hourly watcher detects new stable Whisper releases and publishes versioned images
and `-release` aliases. See [release tracking](docs/building.md#automatic-upstream-release-builds).

The two regular tags pin Whisper to `02612981545f58188a44de99b8a4710793714629`.
Nightly builds resolve master to a commit at build time and leave regular tags
untouched. Fedora image tags and package versions remain mutable.

## Quick start: transcribe a file

Requirements: Linux x86-64, a working AMD GPU driver, Podman, `/dev/dri`, and
`/dev/kfd` for ROCm. Your user must have permission to open the GPU devices.
See [host setup and troubleshooting](docs/troubleshooting.md).

```sh
git clone https://github.com/dohr-michael/whisper-strix-halo-toolboxes.git
cd whisper-strix-halo-toolboxes
mkdir -p models
# Put a whisper.cpp GGML model in models/ and sample.wav in the current directory.
./scripts/run.sh rocm-fedora43 whisper-cli \
  -m /models/ggml-large-v3-turbo.bin -f /audio/sample.wav -l auto
```

Use the [upstream model instructions](https://github.com/ggml-org/whisper.cpp/tree/master/models)
to obtain a GGML model. Models and recordings are never bundled in the images.
Replace `rocm-fedora43` with `vulkan-radv` to try RADV. Set `MODELS_DIR` and
`AUDIO_DIR` to use other directories. `CONTAINER_ENGINE=docker` selects Docker.

For an interactive shell:

```sh
./scripts/run.sh rocm-fedora43
# In the container, whisper-cli, whisper-server, whisper-bench and whisper-quantize are on PATH.
```

## Toolbx and Distrobox

```sh
./refresh-toolboxes.sh --dry-run all
./refresh-toolboxes.sh rocm-fedora43
toolbox enter whisper-rocm-fedora43
# Host home paths are accessible inside the toolbox.
whisper-cli -m ~/models/ggml-large-v3-turbo.bin -f ~/sample.wav -l auto
```

Use `TOOLBOX_ENGINE=distrobox` to select Distrobox (configured with Podman).
Toolbx/Distrobox host integration is provided by those tools and still needs an
end-to-end test with these images. The plain Podman path uses explicit devices.

To update, save any container-only files first, then run:

```sh
./refresh-toolboxes.sh --replace rocm-fedora43
```

The helper pulls before removing an existing container. It refuses replacement
without `--replace` and does not prune unrelated images or containers.

## Server mode

```sh
cp .env.example .env
# Set MODELS_DIR and MODEL_FILE in .env.
podman compose up -d
curl http://localhost:8081/v1/audio/transcriptions \
  -F file=@sample.wav -F response_format=json
```

Compose explicitly starts `whisper-server`; images otherwise open a shell.
See [server configuration](docs/server.md) for direct Podman usage and API limits.

## Building locally

```sh
./scripts/build.sh rocm-fedora43
./scripts/build.sh vulkan-radv
IMAGE_REPOSITORY=localhost/whisper-strix-halo ./scripts/run.sh rocm-fedora43 whisper-cli --help
```

See [builds and publication](docs/building.md) for source overrides, nightly
channels and CI validation. See [benchmarks](benchmark/README.md) for the test
procedure and what to record. No performance results are claimed yet.

## Repository layout

- `toolboxes/`: standalone multi-stage recipes for each backend.
- `scripts/`: local build and run helpers.
- `refresh-toolboxes.sh`: create or explicitly replace interactive toolboxes.
- `docs/`: building, server usage and host troubleshooting.
- `benchmark/`: reproducible GPU validation procedure.
- `.github/workflows/`: build, smoke-test and publish images.

## License and acknowledgements

Packaging is MIT licensed. Whisper and system packages retain their own licenses;
the Whisper license is included in each image. Recipes and scripts were authored
for this repository with AI assistance; no kyuz0 source files were copied.
Architecture and usage were inspired by kyuz0's project. No source modifications
are submitted to whisper.cpp.
