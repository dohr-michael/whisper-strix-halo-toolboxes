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
