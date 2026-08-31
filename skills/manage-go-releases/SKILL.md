---
name: manage-go-releases
description: >-
  Shared Go module release practice for agents: auto-patch tags on main,
  skip docs/chore/ci-only merges, manual minor/major, and pin consumers to
  v* tags (submodule + go.mod). Use when releasing, tagging, bumping a Go
  dependency, pinning providers/strop or cursor-packs, or wiring auto-patch CI.
---

# Manage Go releases (agent practice)

Shared policy for Go libraries and toolkits consumed by agents (for example strop, cursor-packs consumers). Humans rarely browse Releases; agents need a resolvable `v*` after every releasable merge.

**Scaffold binaries first:** `.cursor/skills/setup-goreleaser/SKILL.md` (CLI builds). This skill owns **ongoing version policy** and **consumer pins**.

---

## When to load

- User asks to release, tag, auto-patch, or bump a Go module
- After merging to an upstream `main` that publishes tags
- Pinning a submodule under `providers/` or `.cursor/packs/` plus `go.mod`
- Adding or changing `auto-patch-release` style workflows (GitHub Actions or GitLab CI)

---

## Policy (MUST)

**CONSTRAINT:** Default bump on each releasable merge to `main` MUST be **patch** (`vX.Y.(Z+1)`).
- Enforcement: workflow tags patch unless dispatch/manual says otherwise
- Violation: STOP, do not invent a minor/major without an explicit ask or breaking-API reason

**CONSTRAINT:** MUST NOT create a tag when every commit subject since the last `v*` tag is only `docs:`, `chore:`, or `ci:` (conventional prefixes), or the subject contains `[skip release]`.
- Enforcement: auto-tag job skip logic / agent checks subjects before tagging
- Violation: delete mistaken tag only if user asks; never force-push by default

**CONSTRAINT:** MUST use **minor** only for additive public API, and **major** only for breaking public API (or when the user explicitly requests that bump).
- Enforcement: `workflow_dispatch` bump input or explicit user instruction
- Violation: STOP, do not treat “cut a release” as major by default

**CONSTRAINT:** After a new upstream `v*` tag exists, consumer agents MUST pin both the git checkout (submodule or clone) and the Go module require to that tag when the consumer depends on it.
- Enforcement: `git checkout vX.Y.Z` (or submodule update) + `go get module@vX.Y.Z` + `go mod tidy`
- Violation: STOP, do not leave dirty submodule or untagged SHA when a tag exists for that commit

CORRECT:
```bash
git -C providers/strop fetch --tags origin
git -C providers/strop checkout "v0.2.1"
go get github.com/behaviorengineering/strop@v0.2.1
go mod tidy
```

PROHIBITED:
```bash
# Point go.mod at a pseudo-version while submodule sits on dirty main
go get github.com/behaviorengineering/strop@latest
```

---

## Upstream auto-patch CI (library)

When the repo is a Go **library** (source releases / `builds.skip: true` is OK):

1. Keep tag-triggered GoReleaser (`.github/workflows/release.yml` or GitLab `.gitlab/ci/goreleaser-release.yml`) for human-pushed `v*` tags.
2. Add a default-branch push workflow/job that:
   - Skips docs/chore/ci-only ranges and `[skip release]`
   - Creates annotated `vX.Y.(Z+1)`
   - Runs GoReleaser in the **same job** (CI job-token tag pushes do not reliably trigger other pipelines)
   - Offers manual bump (`workflow_dispatch` bump input on GitHub; `RELEASE_BUMP` on GitLab web pipelines)
3. Document the policy in the upstream README under a short **Releases (for agents)** section.

**GitHub reference:** `behaviorengineering/strop` workflow `auto-patch-release.yml`.

**GitLab reference:** `.gitlab/ci/auto-patch-release.yml` (same skip/bump rules; job `auto_patch_release`). Enable job-token write to the repository so the job can push tags.

---

## Consumer pin checklist

Binary TRUE/FALSE:

| Check | Method | Pass | Fail |
|-------|--------|------|------|
| Tag exists on origin | `git ls-remote --tags origin 'v*'` | Desired `vX.Y.Z` listed | Tag missing; wait or cut release |
| Checkout matches tag | `git -C <dep> describe --tags --exact-match` | Equals `vX.Y.Z` | Dirty or wrong SHA |
| go.mod require matches | `go list -m <module>` | Version is `vX.Y.Z` | Pseudo-version / drift |
| Working tree clean for dep | `git -C <dep> status --short` | Empty | Uncommitted dep edits |

---

## Pre-completion verification

- [ ] Patch is the default bump; minor/major only when asked or API warrants it
- [ ] Docs/chore/ci-only and `[skip release]` do not get tags
- [ ] Consumer pin updated submodule (or path) **and** `go.mod` when applicable
- [ ] No force-push of tags unless the user explicitly requests it
