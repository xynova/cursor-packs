#!/usr/bin/env bash
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
packs="${PACKS_PATH:-$root/.cursor/packs/shared}"

if [[ ! -d "$packs/.git" && ! -f "$packs/.git" ]]; then
  echo "lefthook: packs submodule not found at $packs (skip pin check only if repo has no packs)"
  exit 1
fi

git -C "$packs" fetch --tags origin 2>/dev/null || git -C "$packs" fetch --tags 2>/dev/null || true

if ! current="$(git -C "$packs" describe --tags --exact-match HEAD 2>/dev/null)"; then
  echo "lefthook: .cursor/packs/shared must be checked out at an exact v* release tag"
  exit 1
fi

if [[ ! "$current" =~ ^v[0-9]+\.[0-9]+\.[0-9]+ ]]; then
  echo "lefthook: packs pin must be a semver tag (got: $current)"
  exit 1
fi

latest="$(git -C "$packs" tag -l 'v*' --sort=-v:refname | head -n 1)"
if [[ -z "$latest" ]]; then
  echo "lefthook: no v* tags found in packs remote; cut a release on cursor-packs first"
  exit 1
fi

if [[ "$current" != "$latest" ]]; then
  echo "lefthook: packs pinned at $current but latest release is $latest"
  echo "Load manage-go-releases, bump the packs gitlink, sync submodules, commit, and push again."
  exit 1
fi

exit 0
