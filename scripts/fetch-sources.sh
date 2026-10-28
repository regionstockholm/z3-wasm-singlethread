#!/usr/bin/env bash
# Fetch Z3 and emsdk at the exact commits pinned in versions.env and verify them.
# Z3 is fetched by commit SHA (content-addressed); the upstream tag must point at that commit.
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck disable=SC1091
source versions.env
WORK="${WORK:-$PWD/work}"
mkdir -p "$WORK"

remote_tag_commit() { # peeled commit of an annotated or lightweight tag
  local repo=$1 tag=$2 line
  line=$(git ls-remote "$repo" "refs/tags/$tag^{}" | cut -f1)
  [ -n "$line" ] || line=$(git ls-remote "$repo" "refs/tags/$tag" | cut -f1)
  echo "$line"
}

fetch_pinned() { # repo commit dir
  local repo=$1 commit=$2 dir=$3
  rm -rf "$dir"
  git init -q "$dir"
  git -C "$dir" remote add origin "$repo"
  git -C "$dir" fetch -q --depth 1 origin "$commit"
  git -C "$dir" checkout -q FETCH_HEAD
  local got
  got=$(git -C "$dir" rev-parse HEAD)
  [ "$got" = "$commit" ] || { echo "commit mismatch for $repo: $got != $commit" >&2; exit 1; }
}

z3_tag_commit=$(remote_tag_commit "$Z3_REPO" "$Z3_TAG")
[ "$z3_tag_commit" = "$Z3_COMMIT" ] || {
  echo "Upstream tag $Z3_TAG resolves to $z3_tag_commit, expected $Z3_COMMIT" >&2
  exit 1
}
emsdk_tag_commit=$(remote_tag_commit "$EMSDK_REPO" "$EMSDK_VERSION")
[ "$emsdk_tag_commit" = "$EMSDK_COMMIT" ] || {
  echo "emsdk tag $EMSDK_VERSION resolves to $emsdk_tag_commit, expected $EMSDK_COMMIT" >&2
  exit 1
}

fetch_pinned "$Z3_REPO" "$Z3_COMMIT" "$WORK/z3"
fetch_pinned "$EMSDK_REPO" "$EMSDK_COMMIT" "$WORK/emsdk"
echo "Z3 $Z3_TAG @ $Z3_COMMIT and emsdk $EMSDK_VERSION @ $EMSDK_COMMIT verified."
