#!/usr/bin/env bash
# Merge fire-and-forget Cursor wire paths into the consumer .gitignore.
# Pack symlinks from link-into-project.sh stay committed; local wires do not.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: sync-wired-cursor-gitignore.sh [--project PATH] [--check]

  --project PATH   Consumer repo root (default: current directory).
  --check          Exit 1 if .gitignore would change (CI / pre-commit).

Reads optional .cursor/wired-gitignore.manifest (one repo-relative path per line).
Always includes pack defaults (.cursor/debug-*.log).

Maintains a marked block in .gitignore:
  # BEGIN cursor-packs wired Cursor discovery
  ...
  # END cursor-packs wired Cursor discovery
EOF
}

PROJECT="$(pwd)"
CHECK=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --project)
      PROJECT="$2"
      shift 2
      ;;
    --check)
      CHECK=1
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
GITIGNORE="$PROJECT/.gitignore"
MANIFEST="$PROJECT/.cursor/wired-gitignore.manifest"
BEGIN="# BEGIN cursor-packs wired Cursor discovery (do not edit; run sync-wired-cursor-gitignore.sh)"
END="# END cursor-packs wired Cursor discovery"

TMP_PATHS="$(mktemp)"
echo ".cursor/debug-*.log" >"$TMP_PATHS"

if [[ -f "$MANIFEST" ]]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [[ -z "$line" ]] && continue
    echo "$line" >>"$TMP_PATHS"
  done <"$MANIFEST"
fi

SORTED_PATHS="$(mktemp)"
sort -u "$TMP_PATHS" >"$SORTED_PATHS"
rm -f "$TMP_PATHS"
PATH_COUNT="$(wc -l <"$SORTED_PATHS" | tr -d ' ')"

block_file="$(mktemp)"
{
  echo "$BEGIN"
  echo "# Wired by BOOTSTRAP / make wire-cursor-skills; not committed (see author-ai-copilots)."
  cat "$SORTED_PATHS"
  echo "$END"
} >"$block_file"
rm -f "$SORTED_PATHS"

OUT="$(mktemp)"
if [[ ! -f "$GITIGNORE" ]]; then
  cp "$block_file" "$OUT"
else
  if grep -qF "$BEGIN" "$GITIGNORE"; then
    export WIRED_BLOCK_FILE="$block_file"
    awk -v b="$BEGIN" -v e="$END" '
      function emit_block() {
        while ((getline line < ENVIRON["WIRED_BLOCK_FILE"]) > 0) print line
        close(ENVIRON["WIRED_BLOCK_FILE"])
      }
      {
        if ($0 == b) {
          emit_block()
          skip = 1
          next
        }
        if (skip) {
          if ($0 == e) skip = 0
          next
        }
        print
      }
    ' "$GITIGNORE" >"$OUT"
    unset WIRED_BLOCK_FILE
  else
    cat "$GITIGNORE" >"$OUT"
    echo >>"$OUT"
    cat "$block_file" >>"$OUT"
  fi
fi
rm -f "$block_file"

if [[ -f "$GITIGNORE" ]] && cmp -s "$GITIGNORE" "$OUT"; then
  rm -f "$OUT"
  echo "OK: $GITIGNORE already matches wired Cursor block."
  exit 0
fi

if [[ "$CHECK" -eq 1 ]]; then
  rm -f "$OUT"
  echo "FAIL: $GITIGNORE is out of date; run sync-wired-cursor-gitignore.sh --project $PROJECT" >&2
  exit 1
fi

mv "$OUT" "$GITIGNORE"
echo "Updated $GITIGNORE wired Cursor block ($PATH_COUNT path pattern(s))."
