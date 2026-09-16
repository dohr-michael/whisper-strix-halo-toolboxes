#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
backend=${1:-rocm-fedora43}
case "$backend" in rocm-fedora43|vulkan-radv) ;; *) echo "Unknown backend: $backend" >&2; exit 2;; esac
if (( $# )); then shift; fi
exec "${CONTAINER_ENGINE:-podman}" build -f "$root/toolboxes/Dockerfile.$backend" \
  -t "${IMAGE_REPOSITORY:-localhost/whisper-strix-halo}:$backend" "$@" "$root"
