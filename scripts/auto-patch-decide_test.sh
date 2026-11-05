#!/usr/bin/env bash
# Smoke tests for auto-patch-path-predicates.sh and the skip marker in
# auto-patch-decide.sh (the marker cases build a throwaway git repo).
set -euo pipefail

_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=auto-patch-path-predicates.sh
source "${_script_dir}/auto-patch-path-predicates.sh"

failures=0

assert_harness() {
  local path="$1"
  if ! is_harness_only_path "${path}"; then
    echo "FAIL: expected harness-only: ${path}" >&2
    failures=$((failures + 1))
  fi
}

assert_not_harness() {
  local path="$1"
  if is_harness_only_path "${path}"; then
    echo "FAIL: expected not harness-only: ${path}" >&2
    failures=$((failures + 1))
  fi
}

assert_packaging() {
  local path="$1"
  if ! is_packaging_only_path "${path}"; then
    echo "FAIL: expected packaging-only: ${path}" >&2
    failures=$((failures + 1))
  fi
}

assert_not_packaging() {
  local path="$1"
  if is_packaging_only_path "${path}"; then
    echo "FAIL: expected not packaging-only: ${path}" >&2
    failures=$((failures + 1))
  fi
}

assert_harness "lefthook.yml"
assert_harness ".cursor/packs/shared"
assert_harness ".cursor/skills/foo/SKILL.md"
assert_not_harness "engine/foo.go"
assert_not_harness ".gitlab/ci/auto-patch-release.yml"

assert_packaging "Dockerfile"
assert_packaging "Dockerfile.prod"
assert_packaging "docker-bake.hcl"
assert_packaging "scripts/docker-build.sh"
assert_packaging ".github/workflows/docker-release.yml"
assert_not_packaging "pkg/foo/foo.go"

# The skip marker counts in the subject line only.
_tmp="$(mktemp -d)"
trap 'rm -rf "${_tmp}"' EXIT
_repo="${_tmp}/repo"
git init -q "${_repo}"
: > "${_repo}/main.go"
git -C "${_repo}" add main.go
git -C "${_repo}" -c user.name=test -c user.email=test@example.com commit -q -m "feat: add main"

decide_reason() {
  local msg="$1" out="${_tmp}/decide.out"
  : > "${out}"
  (cd "${_repo}" && OUTPUT_FILE="${out}" HEAD_MSG="${msg}" bash "${_script_dir}/auto-patch-decide.sh")
  sed -n 's/^reason=//p' "${out}"
}

assert_marker_skips() {
  local msg="$1"
  if [[ "$(decide_reason "${msg}")" != *"[skip release]"* ]]; then
    echo "FAIL: expected skip marker to skip: $(printf '%q' "${msg}")" >&2
    failures=$((failures + 1))
  fi
}

assert_marker_ignored() {
  local msg="$1"
  if [[ "$(decide_reason "${msg}")" == *"[skip release]"* ]]; then
    echo "FAIL: expected skip marker to be ignored: $(printf '%q' "${msg}")" >&2
    failures=$((failures + 1))
  fi
}

assert_marker_skips "feat: add main [skip release]"
assert_marker_ignored $'feat: add main\n\nThe [skip release] marker is documented here.'

if [[ "${failures}" -gt 0 ]]; then
  echo "${failures} auto-patch test(s) failed" >&2
  exit 1
fi

echo "auto-patch-decide_test: ok"
