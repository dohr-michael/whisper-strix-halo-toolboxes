# Builds and publication

Run from the repository root:

```sh
./scripts/build.sh rocm-fedora43 --build-arg BUILD_JOBS=2
./scripts/build.sh vulkan-radv --build-arg BUILD_JOBS=2
```

The equivalent direct command is:

```sh
podman build -f toolboxes/Dockerfile.rocm-fedora43 \
  -t localhost/whisper-strix-halo:rocm-fedora43 .
```

Pass `--build-arg WHISPER_REF=<full-commit-sha>` for an intentional source update.
Both recipes build inside the container and set `GGML_NATIVE=OFF` so published
CPU code does not depend on the builder's CPU. The ROCm recipe sets
`CMAKE_HIP_ARCHITECTURES=gfx1151` and `GGML_HIP_NO_VMM=ON`, matching our original
local preparation. Vulkan uses Mesa RADV at runtime and requires no ROCm userspace.

The runtime includes a shell, transcription tools and ffmpeg-free. The server is
selected by a command (`image whisper-server ...`), rather than a fixed entrypoint.
The actual source commit is recorded in `/opt/whisper/whisper-revision.txt`.

## CI channels

- Pull requests: build both backends and check CLI/server help without a GPU; no push.
- Main: publish the pinned recipes under `rocm-fedora43` and `vulkan-radv`.
- Version tags: publish backend-prefixed release tags, e.g. `vulkan-radv-v0.1.0`.
- Daily schedule: rebuild upstream master under backend-specific `-nightly` tags.
- Manual dispatch: select `upstream` to build nightly, or leave it off for pinned builds.

Nightly rebuilds run daily even if master is unchanged, also picking up Fedora
package changes. They are experimental and do not advance pinned tags. CI uses a
separate cache per backend and GITHUB_TOKEN to publish to GHCR. GPU inference is
not tested on GitHub-hosted runners. Follow the benchmark procedure on real hardware.

GHCR package visibility may need to be set to public before anonymous pulls work.
The repository's public visibility alone does not prove package availability.
For exact deployment reuse, pin the published image digest; package repositories
and Fedora base tags are not pinned, so rebuilds are not bit-for-bit reproducible.

## Automatic upstream release builds

`watch-releases.yml` checks the latest stable GitHub release of
`ggml-org/whisper.cpp` hourly, at minute 17. GitHub may delay scheduled runs;
this is polling, not an instantaneous upstream webhook. Drafts and prereleases
are excluded. Manual dispatch performs the same check.

On a new release, it resolves the release tag to a commit and builds both backends
from that exact revision using the same build and smoke-test workflow. Images get:

- `rocm-fedora43-release` and `vulkan-radv-release`: latest successfully published
  stable Whisper release for each backend.
- `rocm-fedora43-whisper-v1.9.4` and `vulkan-radv-whisper-v1.9.4`: example version tags.

Set `WHISPER_IMAGE=ghcr.io/dohr-michael/whisper-strix-halo-toolboxes:rocm-fedora43-release`
in `.env` to select that channel, then pull and recreate the service when ready.
Publication does not automatically restart running containers. Pinned and nightly
channels remain separate.

A success marker is saved only after both images have passed startup checks and
been published. Failed builds are retried by the next poll. The first check builds
the current release. Markers expire after 90 days, so an unchanged release can be
rebuilt after expiration or manual marker deletion. If several releases arrive
between checks, only the latest stable release is selected. Backend publications
are independent: one can advance while the other fails; the next check retries both.
