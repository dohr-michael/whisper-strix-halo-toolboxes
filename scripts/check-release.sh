#!/usr/bin/env bash
# GH_REPO is the packaging repository, GH_TOKEN authenticates GitHub API requests.
set -euo pipefail
: "${GH_REPO:?Set GH_REPO to the packaging repository}"
: "${GITHUB_OUTPUT:?Set GITHUB_OUTPUT}"
release=$(gh api repos/ggml-org/whisper.cpp/releases/latest)
jq -e '.draft == false and .prerelease == false' <<< "$release" >/dev/null
tag=$(jq -r '.tag_name' <<< "$release")
id=$(jq -r '.id' <<< "$release")
[[ "$tag" =~ ^[a-zA-Z0-9_][a-zA-Z0-9_.-]{0,100}$ ]]
[[ "$id" =~ ^[0-9]+$ ]]
# Resolve annotated and lightweight tags to the actual source commit.
refs=$(git ls-remote https://github.com/ggml-org/whisper.cpp.git "refs/tags/$tag" "refs/tags/$tag^{}")
revision=$(awk '$2 ~ /\^\{\}$/ {print $1}' <<< "$refs")
if [[ -z "$revision" ]]; then revision=$(awk -v ref="refs/tags/$tag" '$2 == ref {print $1}' <<< "$refs"); fi
[[ "$revision" =~ ^[0-9a-f]{40}$ ]]
marker="whisper-release-$id-$revision"
# Only the final success job writes this artifact. API failures must fail the poll.
markers=$(gh api --paginate "repos/$GH_REPO/actions/artifacts?per_page=100" \
  --jq '.artifacts[] | select(.expired == false) | .name')
changed=true
if grep -Fxq -- "$marker" <<< "$markers"; then changed=false; fi
printf 'tag=%s\nrevision=%s\nmarker=%s\nchanged=%s\n' "$tag" "$revision" "$marker" "$changed" >> "$GITHUB_OUTPUT"
echo "Whisper $tag ($revision): rebuild=$changed"
