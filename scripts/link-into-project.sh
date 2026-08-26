#!/usr/bin/env bash
# Link shared cursor-packs skills and rules into a consumer project's .cursor/
# using relative symlinks next to project-local overlays.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: link-into-project.sh [--project PATH]

  --project PATH   Consumer repo root (default: current directory).
                   Expects PATH/.cursor/packs/shared (git submodule).

Creates relative symlinks:
  .cursor/skills/<name>  -> ../packs/shared/skills/<name>
  .cursor/rules/<file>   -> ../packs/shared/rules/<file>

Refuses to overwrite a real (non-symlink) file or directory.
EOF
}

PROJECT="$(pwd)"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --project)
      PROJECT="$2"
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
PACK="$CURSOR/packs/shared"

if [[ ! -d "$PACK" ]]; then
  echo "Missing pack at $PACK" >&2
  echo "Add the submodule first:" >&2
  echo "  git submodule add https://github.com/xynova/cursor-packs.git .cursor/packs/shared" >&2
  exit 1
fi

SKILLS=(
  golang-quality
  code-review-staged
  dspy-go-debugging
  dspy-module-patterns
  dspy-prompt-engineering
  review-member-visibility
)
RULES=(
  golang.mdc
  dspy.mdc
)

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
echo

mkdir -p "$CURSOR/skills" "$CURSOR/rules"

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

echo
echo "Done."
