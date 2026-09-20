---
name: prepare-go-forge
description: >-
  Prepare GitLab or GitHub hosts for GoReleaser and Go quality via CLI:
  protected main, package/release job-token permissions, secret detection,
  and golang quality CI templates. Use when scaffolding a new Go module host,
  fixing release 403 admin_packages, CI_JOB_TOKEN changelog failures, or
  enabling forge settings without the UI.
---

# Prepare Go forge

Apply host settings and CI stubs so GoReleaser auto-patch, protected `main`, secret scanning, and Go quality gates work without Settings UI clicks.

**Scripts:** [../../scripts/gitlab-prepare-go-forge.sh](../../scripts/gitlab-prepare-go-forge.sh), [../../scripts/github-prepare-go-forge.sh](../../scripts/github-prepare-go-forge.sh)

**API tables and GraphQL:** [reference.md](reference.md)

**CI templates (copy into the target repo):** [templates/](templates/)

**Related:** `setup-goreleaser` (release files), `manage-go-releases` (tag policy / pins).

---

## When to load

- New or existing Go module needs forge-ready release + quality
- GitLab release upload fails with `admin_packages` / package registry 403
- GitLab release fails with `necessary APIs are not available when using CI_JOB_TOKEN` (changelog)
- Release job fails with `go.mod requires go >= X (running go Y)`
- User asks to protect `main`, enable secret detection, or set job-token permissions via CLI
- After `setup-goreleaser` scaffolds files and the host is not prepared yet

---

## Discover first

| Fact | How |
|------|-----|
| Host | `git remote get-url origin` contains `gitlab.com` vs `github.com` |
| Project path | GitLab: `group/project`; GitHub: `owner/repo` |
| Auth | `glab auth status` or `gh auth status` (Maintainer / admin) |
| Existing CI | Look for `.gitlab-ci.yml` / `.github/workflows/ci.yml` |

---

## Must

**CONSTRAINT:** Agents MUST run the matching prepare script for the host before claiming forge settings are done.
- Enforcement: script exit 0; print summary includes packages / protection / policies
- Violation: STOP, fix auth or API errors, re-run

**CONSTRAINT:** On GitLab, MUST apply the canonical fine-grained job-token profile only: `READ_JOBS`, `ADMIN_PACKAGES`, `ADMIN_RELEASES`, `ADMIN_REPOSITORIES` (everything else None).
- Enforcement: GraphQL `ciJobTokenScopeUpdatePolicies` with `defaultPermissions: false` and that policy list; see [reference.md](reference.md)
- Violation: STOP, do not invent broader scopes

CORRECT:
```bash
# From pack root or any checkout that can resolve the script
./scripts/gitlab-prepare-go-forge.sh --project behaviorengineering/opsis
```

PROHIBITED:
```bash
# Hand-edit Settings UI and claim the skill ran
# Grant ADMIN_* on every resource "just in case"
```

**CONSTRAINT:** MUST NOT overwrite existing CI files without explicit user confirmation.
- Enforcement: copy templates only when missing, or after user says replace
- Violation: STOP, show diff / ask

**CONSTRAINT:** MUST NOT mint or print a project access token unless GraphQL policy update fails and the user accepts the PAT fallback.
- Enforcement: primary path is job-token policies + `CI_JOB_TOKEN`; PAT is secondary in [reference.md](reference.md#pat-fallback)
- Violation: STOP, prefer GraphQL fix

**CONSTRAINT:** MUST keep GoReleaser on `GITLAB_TOKEN: $CI_JOB_TOKEN` with `gitlab_urls.use_job_token` and `use_package_registry` when packages + `ADMIN_PACKAGES` are enabled.
- Enforcement: check `.goreleaser.yaml` / release CI variables after prepare
- Violation: STOP, align config; do not leave a PAT as the default path

**CONSTRAINT:** On GitLab with `CI_JOB_TOKEN`, GoReleaser MUST set `changelog.use: git` (and CI `GIT_DEPTH: "0"` so tag history is complete). MUST NOT set `changelog.use: gitlab` while `GITLAB_TOKEN` is `$CI_JOB_TOKEN`.
- Enforcement: read `.goreleaser.yaml` changelog block and release job variables; GoReleaser fails with `the necessary APIs are not available when using CI_JOB_TOKEN` if `use: gitlab`
- Violation: STOP, switch changelog to `git`, keep job-token auth; do not mint a PAT only to unlock GitLab changelog mode

CORRECT:
```yaml
# .goreleaser.yaml
changelog:
  use: git

# .gitlab/ci/goreleaser-release.yml
variables:
  GIT_DEPTH: "0"
  GITLAB_TOKEN: $CI_JOB_TOKEN
```

PROHIBITED:
```yaml
changelog:
  use: gitlab   # with GITLAB_TOKEN: $CI_JOB_TOKEN
```

**CONSTRAINT:** The GitLab release job toolchain MUST satisfy `go.mod`'s `go` directive. When the official `goreleaser/goreleaser` image ships an older Go than `go.mod`, MUST run on `golang:<go.mod-version>-bookworm` and `go install` the pinned GoReleaser version in-job.
- Enforcement: compare `go.mod` `go` line to the release job image; release log must not show `go.mod requires go >= X (running go Y)`
- Violation: STOP, retarget the release job image / install path; do not lower `go.mod` below a dependency that requires the newer Go

CORRECT:
```yaml
release:
  image:
    name: golang:1.27-bookworm
    entrypoint: [""]
  script:
    - GOBIN=/usr/local/bin go install github.com/goreleaser/goreleaser/v2@v2.9.0
    - goreleaser release --clean
```

PROHIBITED:
```yaml
# go.mod says go 1.27.0; image only has Go 1.24
image:
  name: goreleaser/goreleaser:v2.9.0
```

---

## Steps

1. **Detect host** from `origin`.
2. **Authenticate** (`glab` or `gh`) as Maintainer+.
3. **Run prepare script** (`--project` / `--repo`).
4. **Copy CI templates** from [templates/](templates/) when missing (GitLab quality + secret/SAST snippet + `goreleaser-release.yml`; GitHub `ci.yml` + secret scan).
5. **Cross-check** checklist below.
6. **Hand off** to `setup-goreleaser` / `manage-go-releases` if release files or auto-patch are still missing.
7. **Verify** (optional): re-run the last failed `release` / `auto_patch_release` job.

---

## Checklist

Binary TRUE/FALSE:

| Check | Method | Pass | Fail |
|-------|--------|------|------|
| Script succeeded | Exit code of prepare script | 0 | Non-zero; read stderr |
| Packages enabled (GitLab) | Project API `packages_enabled` | true | false |
| Job push allowed (GitLab) | `ci_push_repository_for_job_token_allowed` | true | false |
| Fine-grained policies (GitLab) | Allowlist UI or GraphQL readback | Jobs Read; Packages/Releases/Repos R/W | Missing ADMIN_PACKAGES |
| Protected main | Protected branches API / `gh api` | `main` protected, no force push | Unprotected |
| GoReleaser changelog (GitLab job token) | `.goreleaser.yaml` | `changelog.use: git` | `use: gitlab` with `$CI_JOB_TOKEN` |
| Release job Go version (GitLab) | Job image vs `go.mod` | Image Go >= `go.mod` | Older Go than `go.mod` |
| Go quality CI present | File exists | `golang-quality.yml` or `.github/workflows/ci.yml` | Missing |
| Secret scanning present | File / feature | GitLab Secret-Detection include or GitHub secret workflow | Missing |

---

## Pre-completion verification

- [ ] Host prepare script ran successfully
- [ ] Canonical GitLab job-token profile applied (or GitHub branch protection + Actions ready)
- [ ] CI templates copied only when missing (or user confirmed replace)
- [ ] No token values printed
- [ ] Operator pointed at setup-goreleaser / manage-go-releases if still needed
