#!/usr/bin/env bash
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
packs="${PACKS_PATH:-}"

if [[ -z "$packs" ]]; then
  if [[ -f "$root/lefthook/lefthook-packs-root.yml" ]]; then
    packs="$root"
  else
    packs="$root/.cursor/packs/shared"
  fi
fi

if [[ ! -d "$packs/.git" && ! -f "$packs/.git" ]]; then
  echo "lefthook: packs not found at $packs (consumer submodule or cursor-packs root)"
  exit 1
fi

packs_git() {
  env -u GIT_DIR -u GIT_WORK_TREE git -C "$packs" "$@"
}

packs_git fetch --tags origin 2>/dev/null || packs_git fetch --tags 2>/dev/null || true

packs_head="$(packs_git rev-parse HEAD)"
if ! current="$(packs_git describe --tags --exact-match "$packs_head" 2>/dev/null)"; then
  echo "lefthook: cursor-packs checkout must be at an exact v* release tag"
  exit 1
fi

if [[ ! "$current" =~ ^v[0-9]+\.[0-9]+\.[0-9]+ ]]; then
  echo "lefthook: packs pin must be a semver tag (got: $current)"
  exit 1
fi

latest="$(packs_git tag -l 'v*' --sort=-v:refname | head -n 1)"
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
