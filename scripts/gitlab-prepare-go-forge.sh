#!/usr/bin/env bash
# Prepare a GitLab project for GoReleaser + Go quality (no Settings UI).
# Requires: glab authenticated as Maintainer+ on the project.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: gitlab-prepare-go-forge.sh --project GROUP/PROJECT [--dry-run]

  --project   GitLab path_with_namespace (e.g. behaviorengineering/opsis)
  --dry-run   Print actions without mutating the project

Enables packages, job-token git push, protected main + v* tags, and the
canonical fine-grained job-token policy profile (READ_JOBS, ADMIN_PACKAGES,
ADMIN_RELEASES, ADMIN_REPOSITORIES) on the project's self allowlist entry.
EOF
}

PROJECT=""
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project)
      PROJECT="${2:-}"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
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

if [[ -z "${PROJECT}" ]]; then
  echo "Missing --project GROUP/PROJECT" >&2
  usage >&2
  exit 1
fi

if ! command -v glab >/dev/null 2>&1; then
  echo "glab is required" >&2
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required" >&2
  exit 1
fi

# URL-encode path for REST (group%2Fproject)
PROJECT_ENC="$(python3 -c 'import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=""))' "${PROJECT}")"

run() {
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "DRY-RUN: $*"
    return 0
  fi
  "$@"
}

echo "==> project=${PROJECT}"

echo "==> fetch project"
PROJ_JSON="$(glab api "projects/${PROJECT_ENC}")"
PROJECT_ID="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])' <<<"${PROJ_JSON}")"
PATH_NS="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["path_with_namespace"])' <<<"${PROJ_JSON}")"
echo "    id=${PROJECT_ID} path=${PATH_NS}"

echo "==> enable packages + job-token git push"
run glab api --method PUT "projects/${PROJECT_ENC}" \
  -f packages_enabled=true \
  -f ci_push_repository_for_job_token_allowed=true >/dev/null

echo "==> ensure self on job-token allowlist"
ALLOW_JSON="$(glab api "projects/${PROJECT_ENC}/job_token_scope/allowlist" 2>/dev/null || echo '[]')"
ON_LIST="$(python3 -c '
import json,sys
want=int(sys.argv[1])
try:
  rows=json.load(sys.stdin)
except Exception:
  rows=[]
print("yes" if any(int(r.get("id",-1))==want for r in rows) else "no")
' "${PROJECT_ID}" <<<"${ALLOW_JSON}")"
if [[ "${ON_LIST}" != "yes" ]]; then
  run glab api --method POST "projects/${PROJECT_ENC}/job_token_scope/allowlist" \
    -f "target_project_id=${PROJECT_ID}" >/dev/null || true
else
  echo "    already on allowlist"
fi

echo "==> fine-grained policies (canonical GoReleaser profile)"
# Inline path strings avoid GraphQL variable type mismatches (ID vs String).
GQL_QUERY="$(python3 -c '
import json,sys
path=sys.argv[1]
# Escape for GraphQL string
esc=json.dumps(path)[1:-1]
print(f"""mutation {{
  ciJobTokenScopeUpdatePolicies(input: {{
    projectPath: \"{esc}\"
    targetPath: \"{esc}\"
    defaultPermissions: false
    jobTokenPolicies: [READ_JOBS, ADMIN_PACKAGES, ADMIN_RELEASES, ADMIN_REPOSITORIES]
  }}) {{
    errors
  }}
}}""")
' "${PATH_NS}")"

if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "DRY-RUN: glab api graphql ciJobTokenScopeUpdatePolicies for ${PATH_NS}"
else
  GQL_OUT="$(glab api graphql -f query="${GQL_QUERY}" 2>&1)" || {
    echo "GraphQL policy update failed:" >&2
    echo "${GQL_OUT}" >&2
    echo "See skills/prepare-go-forge/reference.md#pat-fallback" >&2
    exit 1
  }
  ERR="$(python3 -c '
import json,sys
try:
  d=json.load(sys.stdin)
except Exception as e:
  print("parse_error:"+str(e)); raise SystemExit(0)
errs=(d.get("data") or {}).get("ciJobTokenScopeUpdatePolicies") or {}
e=errs.get("errors") or []
top=d.get("errors") or []
msgs=[str(x) for x in e]+[str(x.get("message",x)) for x in top]
print("; ".join(msgs))
' <<<"${GQL_OUT}" || true)"
  if [[ -n "${ERR}" ]]; then
    echo "GraphQL reported errors: ${ERR}" >&2
    echo "${GQL_OUT}" >&2
    exit 1
  fi
  echo "    policies updated"
fi

echo "==> protect main"
if glab api "projects/${PROJECT_ENC}/protected_branches/main" >/dev/null 2>&1; then
  echo "    main already protected; refreshing via unprotect + protect"
  run glab api --method DELETE "projects/${PROJECT_ENC}/protected_branches/main" >/dev/null || true
fi
run glab api --method POST "projects/${PROJECT_ENC}/protected_branches" \
  -f name=main \
  -f push_access_level=0 \
  -f merge_access_level=40 \
  -f allow_force_push=false >/dev/null

echo "==> protect tags v*"
if glab api "projects/${PROJECT_ENC}/protected_tags/v%2A" >/dev/null 2>&1; then
  echo "    v* already protected"
else
  run glab api --method POST "projects/${PROJECT_ENC}/protected_tags" \
    -f name='v*' \
    -f create_access_level=40 >/dev/null || echo "    warn: could not protect v* (may already exist under another pattern)"
fi

echo "==> verify"
VERIFY="$(glab api "projects/${PROJECT_ENC}")"
python3 -c '
import json,sys
p=json.load(sys.stdin)
print("packages_enabled=", p.get("packages_enabled"))
print("ci_push_repository_for_job_token_allowed=", p.get("ci_push_repository_for_job_token_allowed"))
' <<<"${VERIFY}"

echo "OK: GitLab forge prepared for ${PATH_NS}"
echo "Next: copy skills/prepare-go-forge/templates/gitlab/* into the repo if CI stubs are missing."
echo "      (golang-quality.yml, ci-root.snippet.yml, goreleaser-release.yml)."
echo "Keep GITLAB_TOKEN=\$CI_JOB_TOKEN and gitlab_urls.use_job_token / use_package_registry in GoReleaser."
echo "On GitLab with CI_JOB_TOKEN: set changelog.use: git (not gitlab) and GIT_DEPTH=0 on the release job."
echo "If go.mod needs a newer Go than goreleaser/goreleaser ships, use golang:<ver>-bookworm and go install goreleaser."
