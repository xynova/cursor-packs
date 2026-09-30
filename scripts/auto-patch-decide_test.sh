#!/usr/bin/env bash
# Smoke tests for auto-patch-path-predicates.sh (no git required).
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
assert_packaging "scripts/docker-build.sh"
assert_packaging ".github/workflows/docker-release.yml"
assert_not_packaging "pkg/foo/foo.go"

if [[ "${failures}" -gt 0 ]]; then
  echo "${failures} predicate test(s) failed" >&2
  exit 1
fi

echo "auto-patch-decide_test: ok"
