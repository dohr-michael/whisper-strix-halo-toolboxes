#!/usr/bin/env bash
set -euo pipefail
usage() {
  echo "Usage: $0 [--dry-run] [--replace] {all|rocm-fedora43|vulkan-radv}"
  echo "TOOLBOX_ENGINE=toolbox (default) or distrobox; IMAGE_REPOSITORY overrides GHCR."
  echo "--replace deletes the selected container's writable layer; keep data in your home."
}
dry_run=false
replace=false
while (( $# )); do
  case "$1" in
    --dry-run) dry_run=true; shift;;
    --replace) replace=true; shift;;
    -h|--help) usage; exit 0;;
    *) break;;
  esac
done
[[ $# == 1 ]] || { usage >&2; exit 2; }
case "$1" in
  all) backends=(rocm-fedora43 vulkan-radv);;
  rocm-fedora43|vulkan-radv) backends=("$1");;
  *) usage >&2; exit 2;;
esac
manager=${TOOLBOX_ENGINE:-toolbox}
case "$manager" in toolbox|distrobox) ;; *) echo "Unsupported TOOLBOX_ENGINE" >&2; exit 2;; esac
run() {
  if "$dry_run"; then printf '%q ' "$@"; printf '\n'; else "$@"; fi
}
if ! "$dry_run"; then
  command -v podman >/dev/null
  command -v "$manager" >/dev/null
fi
for backend in "${backends[@]}"; do
  name="whisper-$backend"
  image="${IMAGE_REPOSITORY:-ghcr.io/dohr-michael/whisper-strix-halo-toolboxes}:$backend"
  exists=false
  if ! "$dry_run"; then
    if podman container exists "$name"; then
      exists=true
    else
      status=$?
      [[ $status == 1 ]] || exit "$status"
    fi
  fi
  if "$exists" && ! "$replace"; then
    echo "$name exists. Use --replace to recreate it; export container-only data first." >&2
    exit 1
  fi
  run podman pull "$image"
  if "$replace" && { "$exists" || "$dry_run"; }; then run "$manager" rm -f "$name"; fi
  if [[ "$manager" == toolbox ]]; then
    run toolbox create --image "$image" "$name"
  else
    run distrobox create --yes --name "$name" --image "$image"
  fi
  echo "Enter with: $manager enter $name"
done
