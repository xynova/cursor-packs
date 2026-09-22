#!/usr/bin/env bash
# Prepare a GitHub repo for Go quality + release-ready ruleset gates.
# Requires: gh authenticated with admin on the repo.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: github-prepare-go-forge.sh --repo OWNER/NAME [--dry-run] [--contexts CSV]

  --repo       GitHub repository (e.g. behaviorengineering/strop)
  --dry-run    Print actions without mutating the repo
  --contexts   Comma-separated required status check contexts
               (default: discover from .github/workflows/ci.yml, else quality)

Upserts a repository ruleset on the default branch (PR required, required
status checks, no force push / deletion, linear history). Removes classic
branch protection when present. Best-effort enables secret scanning and
push protection. Prints next steps for CI template copy.
EOF
}

REPO=""
DRY_RUN=0
CONTEXTS_EXPLICIT=""
CONTEXTS_SET=0

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
      CONTEXTS_EXPLICIT="${2:-}"
      CONTEXTS_SET=1
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

echo "==> repo=${REPO}"

echo "==> verify access"
gh api "repos/${REPO}" --jq '.full_name' >/dev/null

DEFAULT_BRANCH="$(gh api "repos/${REPO}" --jq '.default_branch')"
echo "    default_branch=${DEFAULT_BRANCH}"

discover_ci_context() {
  local yaml
  yaml="$(
    gh api "repos/${REPO}/contents/.github/workflows/ci.yml" --jq '.content' 2>/dev/null \
      | tr -d '\n' \
      | base64 -d 2>/dev/null || true
  )"
  if [[ -z "${yaml}" ]]; then
    return 1
  fi
  DISCOVER_YAML="${yaml}" python3 - <<'PY'
import os, re
text = os.environ.get("DISCOVER_YAML", "")
in_jobs = False
lines = text.splitlines()
for i, line in enumerate(lines):
    if re.match(r"^jobs:\s*$", line):
        in_jobs = True
        continue
    if not in_jobs:
        continue
    if line and not line.startswith((" ", "\t", "#")):
        break
    m = re.match(r"^  ([A-Za-z0-9_-]+):\s*(#.*)?$", line)
    if not m:
        continue
    job_id = m.group(1)
    display = job_id
    for follow in lines[i + 1 : i + 12]:
        if re.match(r"^  [A-Za-z0-9_-]+:", follow) and not follow.startswith("    "):
            break
        nm = re.match(r'^\s+name:\s*["\']?([^"\']+)["\']?\s*$', follow)
        if nm:
            display = nm.group(1).strip()
            break
    print(display)
    break
PY
}

# Resolve status-check contexts: --contexts, else first job name in ci.yml, else quality.
if [[ "${CONTEXTS_SET}" -eq 1 ]]; then
  CONTEXTS="${CONTEXTS_EXPLICIT}"
  echo "    contexts (explicit): ${CONTEXTS}"
else
  DISCOVERED="$(discover_ci_context || true)"
  if [[ -n "${DISCOVERED}" ]]; then
    CONTEXTS="${DISCOVERED}"
    echo "    contexts (from ci.yml): ${CONTEXTS}"
  else
    CONTEXTS="quality"
    echo "    contexts (default): ${CONTEXTS}"
  fi
fi

CONTEXT_JSON="$(python3 -c '
import json,sys
ctx=[c.strip() for c in sys.argv[1].split(",") if c.strip()]
if not ctx:
    raise SystemExit("no status check contexts")
print(json.dumps(ctx))
' "${CONTEXTS}")"

RULESET_BODY="$(python3 -c '
import json,sys
contexts=json.loads(sys.argv[1])
checks=[{"context": c, "integration_id": 15368} for c in contexts]
body={
  "name": "main",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "include": ["~DEFAULT_BRANCH"],
      "exclude": []
    }
  },
  "rules": [
    {"type": "deletion"},
    {"type": "non_fast_forward"},
    {"type": "required_linear_history"},
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 0,
        "dismiss_stale_reviews_on_push": True,
        "require_code_owner_review": False,
        "require_last_push_approval": False,
        "required_review_thread_resolution": False,
        "allowed_merge_methods": ["squash"]
      }
    },
    {
      "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": True,
        "do_not_enforce_on_create": False,
        "required_status_checks": checks
      }
    }
  ]
}
print(json.dumps(body))
' "${CONTEXT_JSON}")"

echo "==> upsert ruleset for ${DEFAULT_BRANCH} (contexts=${CONTEXTS})"

# Prefer ruleset named "main"; else first branch ruleset that includes ~DEFAULT_BRANCH.
EXISTING_ID="$(
  python3 - <<PY
import json, subprocess, sys

def gh_json(*args):
    p = subprocess.run(["gh", "api", *args], capture_output=True, text=True)
    if p.returncode != 0:
        return None
    return json.loads(p.stdout)

repo = "${REPO}"
rulesets = gh_json(f"repos/{repo}/rulesets") or []
by_name = next((r["id"] for r in rulesets if r.get("name") == "main" and r.get("target") == "branch"), None)
if by_name is not None:
    print(by_name)
    sys.exit(0)
for r in rulesets:
    if r.get("target") != "branch":
        continue
    detail = gh_json(f"repos/{repo}/rulesets/{r['id']}") or {}
    include = (detail.get("conditions") or {}).get("ref_name", {}).get("include") or []
    if "~DEFAULT_BRANCH" in include or f"refs/heads/${DEFAULT_BRANCH}" in include:
        print(r["id"])
        sys.exit(0)
PY
)"

if [[ "${DRY_RUN}" -eq 1 ]]; then
  if [[ -n "${EXISTING_ID}" ]]; then
    echo "DRY-RUN: PUT repos/${REPO}/rulesets/${EXISTING_ID}"
  else
    echo "DRY-RUN: POST repos/${REPO}/rulesets"
  fi
  echo "${RULESET_BODY}"
  RULESET_ID="${EXISTING_ID:-new}"
else
  if [[ -n "${EXISTING_ID}" ]]; then
    RULESET_ID="$(printf '%s' "${RULESET_BODY}" | gh api -X PUT "repos/${REPO}/rulesets/${EXISTING_ID}" --input - --jq '.id')"
    echo "    updated ruleset id=${RULESET_ID}"
  else
    RULESET_ID="$(printf '%s' "${RULESET_BODY}" | gh api -X POST "repos/${REPO}/rulesets" --input - --jq '.id')"
    echo "    created ruleset id=${RULESET_ID}"
  fi
fi

echo "==> remove classic branch protection (if any)"
if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "DRY-RUN: DELETE repos/${REPO}/branches/${DEFAULT_BRANCH}/protection"
else
  if gh api -X DELETE "repos/${REPO}/branches/${DEFAULT_BRANCH}/protection" >/dev/null 2>/tmp/gh-del-protect-err.txt; then
    echo "    classic protection removed"
  else
    if grep -q '404\|Branch not protected' /tmp/gh-del-protect-err.txt 2>/dev/null; then
      echo "    classic protection absent"
    else
      echo "    warn: could not delete classic protection"
      cat /tmp/gh-del-protect-err.txt >&2 || true
    fi
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
echo "    ruleset_id=${RULESET_ID}"
echo "    required_status_checks=${CONTEXTS}"
echo "Next: copy skills/prepare-go-forge/templates/github/ci.yml and secret-scan.yml if missing."
echo "Release workflows stay on GITHUB_TOKEN with permissions.contents: write (setup-goreleaser)."
