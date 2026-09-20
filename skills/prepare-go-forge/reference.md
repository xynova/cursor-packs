# Prepare Go forge reference

## GitLab: UI to API map

| UI (Settings → CI/CD → Job token permissions) | API |
|-----------------------------------------------|-----|
| Allowlist membership | REST `POST /projects/:id/job_token_scope/allowlist` with `target_project_id` |
| Fine-grained Packages / Releases / Repositories / Jobs | GraphQL `ciJobTokenScopeUpdatePolicies` |
| Allow Git push requests to the repository | REST `PUT /projects/:id` `ci_push_repository_for_job_token_allowed=true` |
| Package Registry feature | REST `PUT /projects/:id` `packages_enabled=true` |
| Protected `main` | REST protected branches API |
| Protected `v*` tags | REST protected tags API |

REST allowlist add does **not** set fine-grained policies. Use GraphQL for the policy row.

## Canonical fine-grained profile

| Resource | Scope | GraphQL enum |
|----------|-------|--------------|
| Jobs | Read | `READ_JOBS` |
| Packages | Read and write | `ADMIN_PACKAGES` |
| Releases | Read and write | `ADMIN_RELEASES` |
| Repositories | Read and write | `ADMIN_REPOSITORIES` |

All other resources: None (`defaultPermissions: false` and only the enums above).

## GraphQL: update policies

```graphql
mutation {
  ciJobTokenScopeUpdatePolicies(
    input: {
      projectPath: "group/project"
      targetPath: "group/project"
      defaultPermissions: false
      jobTokenPolicies: [
        READ_JOBS
        ADMIN_PACKAGES
        ADMIN_RELEASES
        ADMIN_REPOSITORIES
      ]
    }
  ) {
    errors
    ciJobTokenScopeAllowlistEntry {
      target {
        ... on Project {
          fullPath
        }
      }
    }
  }
}
```

`glab` example (inline path; matches the prepare script):

```bash
glab api graphql -f query='
mutation {
  ciJobTokenScopeUpdatePolicies(input: {
    projectPath: "behaviorengineering/opsis"
    targetPath: "behaviorengineering/opsis"
    defaultPermissions: false
    jobTokenPolicies: [READ_JOBS, ADMIN_PACKAGES, ADMIN_RELEASES, ADMIN_REPOSITORIES]
  }) { errors }
}'
```

## REST: project flags

```bash
glab api --method PUT "projects/behaviorengineering%2Fopsis" \
  -f packages_enabled=true \
  -f ci_push_repository_for_job_token_allowed=true
```

## REST: protect main

```bash
# Create (fails if already protected; then use unprotect + protect or PATCH where available)
glab api --method POST "projects/behaviorengineering%2Fopsis/protected_branches" \
  -f name=main \
  -f push_access_level=0 \
  -f merge_access_level=40 \
  -f allow_force_push=false
```

Access levels: `0` No access, `30` Developer, `40` Maintainer.

## REST: protect release tags

```bash
glab api --method POST "projects/behaviorengineering%2Fopsis/protected_tags" \
  -f name='v*' \
  -f create_access_level=40
```

## GoReleaser alignment (GitLab)

Keep release jobs on job token after prepare. The fine-grained allowlist (Jobs read; Packages / Releases / Repositories R/W) plus `ci_push_repository_for_job_token_allowed` is what lets GoReleaser create releases and upload packages. It does **not** unlock GoReleaser's GitLab changelog API path.

```yaml
# .gitlab/ci/goreleaser-release.yml
variables:
  GIT_DEPTH: "0"
  GITLAB_TOKEN: $CI_JOB_TOKEN
```

```yaml
# .goreleaser.yaml
gitlab_urls:
  use_job_token: true
  use_package_registry: true

changelog:
  use: git
```

When `go.mod` requires a newer Go than `goreleaser/goreleaser:<tag>` ships, use the matching `golang` image and install GoReleaser in-job. Copy [templates/gitlab/goreleaser-release.yml](templates/gitlab/goreleaser-release.yml) and pin the image to the `go.mod` version:

```yaml
release:
  stage: release
  image:
    name: golang:1.27-bookworm
    entrypoint: [""]
  rules:
    - if: $CI_COMMIT_TAG =~ /^v[0-9]+\.[0-9]+\.[0-9]+/
  variables:
    GIT_DEPTH: "0"
    GITLAB_TOKEN: $CI_JOB_TOKEN
  script:
    - GOBIN=/usr/local/bin go install github.com/goreleaser/goreleaser/v2@v2.9.0
    - goreleaser release --clean
  needs: []
```

Known failure if `changelog.use: gitlab` with job token:

```text
changelog: the necessary APIs are not available when using CI_JOB_TOKEN
```

Fix: `changelog.use: git` (preferred with job token). Do not mint a PAT solely for GitLab changelog mode.

## PAT fallback

Use only when GraphQL `ciJobTokenScopeUpdatePolicies` is unavailable or errors on the GitLab version in use.

1. Create a project access token (Maintainer) with `api`, `write_repository`, `write_registry` (names vary by GitLab version).
2. Store as a **masked**, **protected** CI/CD variable named `GITLAB_TOKEN`.
3. NEVER print the token value.
4. Prefer returning to job-token policies when GraphQL works.

## GitHub: branch protection (main)

```bash
gh api -X PUT "repos/OWNER/REPO/branches/main/protection" \
  --input - <<'EOF'
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["go-quality"]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 0
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
EOF
```

Adjust `contexts` to match the workflow job `name:` in [templates/github/ci.yml](templates/github/ci.yml) after first green run (GitHub may require the check to exist once).

## GitHub: secret scanning

When the token and plan allow:

```bash
gh api -X PATCH "repos/OWNER/REPO" \
  -f security_and_analysis='{"secret_scanning":{"status":"enabled"},"secret_scanning_push_protection":{"status":"enabled"}}'
```

Always copy [templates/github/secret-scan.yml](templates/github/secret-scan.yml) as a portable gitleaks baseline.
