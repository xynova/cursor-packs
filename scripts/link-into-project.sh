#!/usr/bin/env bash
# Link shared cursor-packs skills, rules, and personas into a consumer
# project's .cursor/ using relative symlinks next to project-local overlays.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=pack-cursor-allowlists.sh
source "$SCRIPT_DIR/pack-cursor-allowlists.sh"

usage() {
  cat <<'EOF'
Usage: link-into-project.sh [--project PATH] [--skip-cursor-components]

  --project PATH              Consumer repo root (default: current directory).
                              Expects PATH/.cursor/packs/shared (git submodule).
  --skip-cursor-components    Skip skills/rules/personas/agents symlinks (Cursor
                              plugin supplies discovery). Submodule still required
                              if this script is invoked for legacy docs.

Creates relative symlinks (unless --skip-cursor-components):
  .cursor/skills/<name>     -> ../packs/shared/skills/<name>
  .cursor/rules/<file>      -> ../packs/shared/rules/<file>
  .cursor/personas/<file>   -> ../packs/shared/personas/<file>
  .cursor/agents/<file>     -> ../packs/shared/agents/<file>

Refuses to overwrite a real (non-symlink) file or directory.
EOF
}

PROJECT="$(pwd)"
SKIP_CURSOR_COMPONENTS=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --project)
      PROJECT="$2"
      shift 2
      ;;
    --skip-cursor-components)
      SKIP_CURSOR_COMPONENTS=1
      shift
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
PACK="$CURSOR/packs/shared"

if [[ ! -d "$PACK" ]]; then
  echo "Missing pack at $PACK" >&2
  echo "Add the submodule first:" >&2
  echo "  git submodule add https://github.com/xynova/cursor-packs.git .cursor/packs/shared" >&2
  exit 1
fi

link_one() {
  local link_path="$1"
  local rel_target="$2"
  local abs_target="$3"

  if [[ ! -e "$abs_target" ]]; then
    echo "SKIP (missing pack target): $abs_target"
    return
  fi

  mkdir -p "$(dirname "$link_path")"

  if [[ -L "$link_path" ]]; then
    ln -sfn "$rel_target" "$link_path"
    echo "LINK (updated): $link_path -> $rel_target"
    return
  fi

  if [[ -e "$link_path" ]]; then
    echo "SKIP (exists, not a symlink — protecting local overlay): $link_path"
    return
  fi

  ln -sfn "$rel_target" "$link_path"
  echo "LINK: $link_path -> $rel_target"
}

echo "Project: $PROJECT"
echo "Pack:    $PACK"
if [[ "$SKIP_CURSOR_COMPONENTS" -eq 1 ]]; then
  echo "Mode:    skip Cursor components (plugin discovery)"
  echo
  echo "Done."
  exit 0
fi
echo

mkdir -p "$CURSOR/skills" "$CURSOR/rules" "$CURSOR/personas" "$CURSOR/agents"

for name in "${SKILLS[@]}"; do
  link_one \
    "$CURSOR/skills/$name" \
    "../packs/shared/skills/$name" \
    "$PACK/skills/$name"
done

for name in "${RULES[@]}"; do
  link_one \
    "$CURSOR/rules/$name" \
    "../packs/shared/rules/$name" \
    "$PACK/rules/$name"
done

for name in "${PERSONAS[@]}"; do
  link_one \
    "$CURSOR/personas/$name" \
    "../packs/shared/personas/$name" \
    "$PACK/personas/$name"
done

for name in "${AGENTS[@]}"; do
  link_one \
    "$CURSOR/agents/$name" \
    "../packs/shared/agents/$name" \
    "$PACK/agents/$name"
done

echo
echo "Done."
