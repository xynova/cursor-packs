#!/usr/bin/env bash
set -euo pipefail

root="$(git rev-parse --show-toplevel)"

# Cursor plugin era: pack skills/rules are not symlinked from packs/shared.
if [[ -f "$root/.cursor/packs/plugin-mode" ]]; then
  exit 0
fi

skill_link="$root/.cursor/skills/golang-quality"
if [[ -L "$skill_link" ]]; then
  target="$(readlink "$skill_link" 2>/dev/null || true)"
  if [[ "$target" != *"packs/shared"* ]]; then
    exit 0
  fi
elif [[ ! -e "$skill_link" ]]; then
  exit 0
fi

packs="${PACKS_PATH:-}"

if [[ -z "$packs" ]]; then
  if [[ -f "$root/lefthook/lefthook-packs-root.yml" ]]; then
    packs="$root"
    # cursor-packs as git root: do not require consumers to track latest tag on self
    exit 0
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
  echo "If you use the Cursor plugin for pack skills, run unlink-pack-cursor-components.sh and keep the submodule only for Lefthook/CI scripts."
  exit 1
fi

exit 0
