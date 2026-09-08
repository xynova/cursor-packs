#!/usr/bin/env bash
# Prepare a GitHub repo for Go quality + release-ready branch protection.
# Requires: gh authenticated with admin on the repo.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: github-prepare-go-forge.sh --repo OWNER/NAME [--dry-run] [--contexts CSV]

  --repo       GitHub repository (e.g. behaviorengineering/strop)
  --dry-run    Print actions without mutating the repo
  --contexts   Comma-separated required status check contexts (default: go-quality)

Protects main (PR required, no force push), best-effort enables secret scanning
and push protection, and prints next steps for CI template copy.
EOF
}

REPO=""
DRY_RUN=0
CONTEXTS="go-quality"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      REPO="${2:-}"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --contexts)
      CONTEXTS="${2:-}"
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

if [[ -z "${REPO}" ]]; then
  echo "Missing --repo OWNER/NAME" >&2
  usage >&2
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "gh is required" >&2
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required" >&2
  exit 1
fi

run() {
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "DRY-RUN: $*"
    return 0
  fi
  "$@"
}

echo "==> repo=${REPO}"

echo "==> verify access"
gh api "repos/${REPO}" --jq '.full_name' >/dev/null

DEFAULT_BRANCH="$(gh api "repos/${REPO}" --jq '.default_branch')"
echo "    default_branch=${DEFAULT_BRANCH}"

CONTEXT_JSON="$(python3 -c '
import json,sys
ctx=[c.strip() for c in sys.argv[1].split(",") if c.strip()]
print(json.dumps(ctx))
' "${CONTEXTS}")"

echo "==> protect ${DEFAULT_BRANCH}"
PROTECTION_BODY="$(python3 -c '
import json,sys
contexts=json.loads(sys.argv[1])
body={
  "required_status_checks": {"strict": True, "contexts": contexts},
  "enforce_admins": True,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": True,
    "require_code_owner_reviews": False,
    "required_approving_review_count": 0
  },
  "restrictions": None,
  "allow_force_pushes": False,
  "allow_deletions": False,
  "required_linear_history": False,
}
print(json.dumps(body))
' "${CONTEXT_JSON}")"

if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "DRY-RUN: PUT repos/${REPO}/branches/${DEFAULT_BRANCH}/protection"
  echo "${PROTECTION_BODY}"
else
  # Required checks may 422 until the named check has run once; fall back without contexts.
  if ! printf '%s' "${PROTECTION_BODY}" | gh api -X PUT "repos/${REPO}/branches/${DEFAULT_BRANCH}/protection" --input - >/dev/null 2> /tmp/gh-protect-err.txt; then
    echo "    warn: protection with contexts failed; retrying without required_status_checks"
    cat /tmp/gh-protect-err.txt >&2 || true
    FALLBACK="$(python3 -c '
import json
body={
  "required_status_checks": None,
  "enforce_admins": True,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": True,
    "require_code_owner_reviews": False,
    "required_approving_review_count": 0
  },
  "restrictions": None,
  "allow_force_pushes": False,
  "allow_deletions": False,
}
print(json.dumps(body))
')"
    printf '%s' "${FALLBACK}" | gh api -X PUT "repos/${REPO}/branches/${DEFAULT_BRANCH}/protection" --input - >/dev/null
    echo "    protected without status contexts; re-run after first green go-quality check:"
    echo "      $0 --repo ${REPO} --contexts ${CONTEXTS}"
  fi
fi

echo "==> secret scanning (best effort)"
if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "DRY-RUN: enable secret_scanning + push_protection"
else
  if ! gh api -X PATCH "repos/${REPO}" \
    --input - >/dev/null 2> /tmp/gh-secret-err.txt <<'EOF'
{
  "security_and_analysis": {
    "secret_scanning": { "status": "enabled" },
    "secret_scanning_push_protection": { "status": "enabled" }
  }
}
EOF
  then
    echo "    warn: could not enable secret scanning via API (plan/permissions may block it)"
    cat /tmp/gh-secret-err.txt >&2 || true
  else
    echo "    secret scanning enabled"
  fi
fi

echo "OK: GitHub forge prepared for ${REPO}"
echo "Next: copy skills/prepare-go-forge/templates/github/ci.yml and secret-scan.yml if missing."
echo "Release workflows stay on GITHUB_TOKEN with permissions.contents: write (setup-goreleaser)."
