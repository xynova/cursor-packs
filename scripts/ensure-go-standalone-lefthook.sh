#!/usr/bin/env bash
# Scaffold standalone fleet Lefthook for Go modules (no cursor-packs submodule).
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ensure-go-standalone-lefthook.sh [--project PATH]

  --project PATH   Target Go module root (default: current directory).

Creates when missing:
  lefthook.yml
  lefthook/lefthook-go-standalone.yml
  scripts/git-hooks/default-branch-refuse.sh
  scripts/git-hooks/go-format-staged.sh

Does not overwrite existing files.

Next step: make hooks-install (or lefthook install). See install-repo-hooks skill.
EOF
}

PROJECT="$(pwd)"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --project)
      PROJECT="${2:?}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

PACK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

install_file() {
  local src="$1"
  local dest="$2"
  if [[ -e "$dest" ]]; then
    echo "exists: $dest"
    return 0
  fi
  mkdir -p "$(dirname "$dest")"
  cp "$src" "$dest"
  if [[ "$dest" == *.sh ]]; then
    chmod +x "$dest"
  fi
  echo "created: $dest"
}

install_file "$PACK_ROOT/lefthook/lefthook-go-standalone.yml" "$PROJECT/lefthook/lefthook-go-standalone.yml"
install_file "$PACK_ROOT/lefthook/scripts/default-branch-refuse.sh" "$PROJECT/scripts/git-hooks/default-branch-refuse.sh"
install_file "$PACK_ROOT/lefthook/scripts/go-format-staged.sh" "$PROJECT/scripts/git-hooks/go-format-staged.sh"

TARGET="$PROJECT/lefthook.yml"
if [[ -e "$TARGET" ]]; then
  echo "lefthook.yml already exists; not overwriting"
else
  cat >"$TARGET" <<'EOF'
# Fleet hooks (standalone Go module; see install-repo-hooks skill)
extends:
  - lefthook/lefthook-go-standalone.yml
EOF
  echo "created: $TARGET"
fi

echo "Next: run make hooks-install or lefthook install from $PROJECT"
