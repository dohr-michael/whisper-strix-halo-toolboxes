#!/usr/bin/env bash
set -euo pipefail
backend=${1:-rocm-fedora43}
case "$backend" in rocm-fedora43|vulkan-radv) ;; *) echo "Unknown backend: $backend" >&2; exit 2;; esac
if (( $# )); then shift; fi
engine=${CONTAINER_ENGINE:-podman}
args=(run --rm --device /dev/dri --security-opt label=disable)
if [[ "$backend" == rocm-* ]]; then args+=(--device /dev/kfd); fi
if [[ "$engine" == podman ]]; then args+=(--group-add keep-groups); fi
args+=(-v "${MODELS_DIR:-$PWD/models}:/models:ro" -v "${AUDIO_DIR:-$PWD}:/audio:ro")
if (( $# == 0 )); then args+=(-it); set -- bash; fi
exec "$engine" "${args[@]}" "${IMAGE_REPOSITORY:-ghcr.io/dohr-michael/whisper-strix-halo-toolboxes}:$backend" "$@"
