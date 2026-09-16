# Host setup and troubleshooting

Use a Linux kernel and firmware with support for your Strix Halo GPU. Container
images supply userspace libraries, not the host driver. The
[Strix Halo setup guide](https://strix-halo-toolboxes.com/) maintained alongside
kyuz0's projects is a useful host-configuration reference.

## Device access

```sh
ls -l /dev/dri /dev/kfd
id
```

ROCm needs both `/dev/kfd` and the render devices under `/dev/dri`. Vulkan only
needs `/dev/dri`. Device ownership varies by distribution; ensure your login has
access, then log in again after any group changes. Our Podman runner preserves
supplementary groups using `--group-add keep-groups` (requires a compatible OCI
runtime such as crun). Docker users may need numeric device groups added with
`--group-add`. Compose users may likewise need host-specific group configuration.

On SELinux systems the examples disable container label separation for GPU and
bind-mount access. They do not relabel your model directory. The previous private
setup used privileged containers; that is not evidence that every host requires it.

## Confirm the backend

Run a real transcription, then inspect stderr for HIP or Vulkan initialization
and the selected GPU. A successful `--help` command only checks startup and shared
libraries. It does not establish GPU compatibility or transcription correctness.
For Vulkan, `scripts/run.sh vulkan-radv vulkaninfo --summary` provides diagnostics.

## Memory and audio

Strix Halo shares system memory with the GPU. Test with available memory while
other models are loaded; do not apply llama.cpp-specific flags such as `-ngl` to
Whisper. Start with a 16 kHz mono WAV to separate audio-decoding issues from GPU
issues. Server `--convert` uses ffmpeg-free, whose supported codecs may differ
from a full FFmpeg build.

## Image or toolbox failures

Check GitHub Actions for a successful publish before pulling. Authentication
errors can mean the GHCR package is still private. Toolbx/Distrobox integration
is experimental; use `scripts/run.sh` to isolate host-integration issues.
`refresh-toolboxes.sh --dry-run all` shows the commands without changing anything.
