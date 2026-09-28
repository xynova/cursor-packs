#!/usr/bin/env bash
# Write a thin root lefthook.yml for cursor-packs consumers (does not overwrite).
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ensure-lefthook-consumer.sh [--project PATH]

  --project PATH   Consumer repo root (default: current directory).

Creates lefthook.yml at the consumer root when missing, extending the packs
submodule config. Does not overwrite an existing lefthook.yml.

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

EXTENDS=""
if [[ -f "$PROJECT/lefthook/lefthook.yml" ]]; then
  EXTENDS="./lefthook/lefthook.yml"
elif [[ -f "$PROJECT/.cursor/packs/shared/lefthook/lefthook.yml" ]]; then
  EXTENDS=".cursor/packs/shared/lefthook/lefthook.yml"
else
  echo "error: no lefthook config under $PROJECT/lefthook or $PROJECT/.cursor/packs/shared" >&2
  exit 1
fi

TARGET="$PROJECT/lefthook.yml"
if [[ -e "$TARGET" ]]; then
  echo "lefthook.yml already exists; not overwriting"
  exit 0
fi

cat >"$TARGET" <<EOF
# Fleet hooks from cursor-packs (see lefthook/README.md)
extends:
  - $EXTENDS
EOF

echo "Created $TARGET"
echo "Next: run make hooks-install or lefthook install from the repo root"
