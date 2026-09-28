#!/usr/bin/env bash
# Decide whether an auto-patch release should run. Writes GitHub Actions outputs.
# Requires: fetch-depth 0 checkout. Env: EVENT_NAME, MANUAL_BUMP, HEAD_MSG (optional).
set -euo pipefail

github_output="${GITHUB_OUTPUT:-}"
if [[ -z "${github_output}" ]]; then
  echo "auto-patch-decide: GITHUB_OUTPUT is required" >&2
  exit 1
fi

write_out() {
  printf '%s\n' "$1" >> "${github_output}"
}

is_harness_only_path() {
  local path="$1"
  [[ "${path}" == lefthook.yml ]] && return 0
  [[ "${path}" == .cursor/* ]] && return 0
  return 1
}

if [[ "${HEAD_MSG:-}" == *"[skip release]"* ]]; then
  write_out "skip=true"
  write_out "reason=commit contains [skip release]"
  exit 0
fi

last_tag="$(git describe --tags --abbrev=0 --match 'v*' 2>/dev/null || true)"
if [[ -z "${last_tag}" ]]; then
  last_tag="v0.0.0"
fi
write_out "last_tag=${last_tag}"

bump="patch"
if [[ "${EVENT_NAME:-push}" == "workflow_dispatch" ]]; then
  bump="${MANUAL_BUMP:-patch}"
else
  range="${last_tag}..HEAD"
  if [[ "${last_tag}" == "v0.0.0" ]]; then
    range="HEAD"
    subjects="$(git log -1 --pretty=%s)"
    files="$(git diff-tree --no-commit-id --name-only -r HEAD)"
  else
    subjects="$(git log --pretty=%s "${range}")"
    files="$(git diff --name-only "${last_tag}" HEAD)"
  fi

  if [[ -z "${subjects}" ]]; then
    write_out "skip=true"
    write_out "reason=no commits since ${last_tag}"
    exit 0
  fi

  releasable="false"
  while IFS= read -r subject; do
    [[ -z "${subject}" ]] && continue
    lower="$(printf '%s' "${subject}" | tr '[:upper:]' '[:lower:]')"
    case "${lower}" in
      docs:*|docs\(*|chore:*|chore\(*|ci:*|ci\(*)
        ;;
      merge\ *)
        ;;
      *)
        releasable="true"
        ;;
    esac
  done <<< "${subjects}"

  if [[ "${releasable}" != "true" ]]; then
    write_out "skip=true"
    write_out "reason=only docs/chore/ci commits since ${last_tag}"
    exit 0
  fi

  if [[ -n "${files}" ]]; then
    harness_only="true"
    while IFS= read -r f; do
      [[ -z "${f}" ]] && continue
      if ! is_harness_only_path "${f}"; then
        harness_only="false"
        break
      fi
    done <<< "${files}"
    if [[ "${harness_only}" == "true" ]]; then
      write_out "skip=true"
      write_out "reason=only agent-harness paths since ${last_tag} (.cursor/, lefthook.yml)"
      exit 0
    fi
  fi
fi

ver="${last_tag#v}"
IFS='.' read -r maj min pat <<< "${ver}"
maj="${maj:-0}"
min="${min:-0}"
pat="${pat:-0}"
case "${bump}" in
  major) maj=$((maj + 1)); min=0; pat=0 ;;
  minor) min=$((min + 1)); pat=0 ;;
  patch) pat=$((pat + 1)) ;;
  *)
    echo "unknown bump: ${bump}" >&2
    exit 1
    ;;
esac
new_tag="v${maj}.${min}.${pat}"

if git rev-parse "${new_tag}" >/dev/null 2>&1; then
  write_out "skip=true"
  write_out "reason=tag ${new_tag} already exists"
  exit 0
fi

write_out "skip=false"
write_out "bump=${bump}"
write_out "new_tag=${new_tag}"
