#!/usr/bin/env bash
# Remove pack-owned symlinks under .cursor/ that point into packs/shared.
# Does not touch real files (overlays) or symlinks into ai-copilots / module cache.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=pack-cursor-allowlists.sh
source "$SCRIPT_DIR/pack-cursor-allowlists.sh"

usage() {
  cat <<'EOF'
Usage: unlink-pack-cursor-components.sh [--project PATH]

  --project PATH   Consumer repo root (default: current directory).

Removes symlinks only when the target path contains "packs/shared".
Creates .cursor/packs/plugin-mode when any pack symlink was removed (plugin-era marker).
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
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

PROJECT="$(cd "$PROJECT" && pwd)"
CURSOR="$PROJECT/.cursor"
removed=0

unlink_if_pack() {
  local link_path="$1"
  [[ -L "$link_path" ]] || return 0
  local target
  target="$(readlink "$link_path")"
  if [[ "$target" == *"packs/shared"* ]]; then
    rm "$link_path"
    echo "UNLINK: $link_path"
    removed=$((removed + 1))
  fi
}

for name in "${SKILLS[@]}"; do
  unlink_if_pack "$CURSOR/skills/$name"
done
for name in "${RULES[@]}"; do
  unlink_if_pack "$CURSOR/rules/$name"
done
for name in "${PERSONAS[@]}"; do
  unlink_if_pack "$CURSOR/personas/$name"
done
for name in "${AGENTS[@]}"; do
  unlink_if_pack "$CURSOR/agents/$name"
done

if [[ "$removed" -gt 0 ]]; then
  mkdir -p "$CURSOR/packs"
  : >"$CURSOR/packs/plugin-mode"
  echo "Wrote $CURSOR/packs/plugin-mode (lefthook pin skip for plugin-era consumers)"
fi

echo "Done. Removed $removed pack symlink(s)."
