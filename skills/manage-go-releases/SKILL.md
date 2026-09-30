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

**Scaffold binaries first:** `.cursor/skills/setup-goreleaser/SKILL.md` (CLI builds). **Host settings:** `.cursor/skills/prepare-go-forge/SKILL.md` when publish fails with package/job-token 403 or forge gates are missing. This skill owns **ongoing version policy** and **consumer pins**.

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

**CONSTRAINT:** MUST NOT create a tag when every file changed since the last `v*` tag is agent-harness only (paths under `.cursor/` or `lefthook.yml`). This covers cursor-packs pin bumps even when the commit subject is not `chore:`.
- Enforcement: shared `scripts/auto-patch-decide.sh` path filter or equivalent in auto-patch CI
- Violation: STOP; use harness-only skip before tagging

**CONSTRAINT:** MUST NOT create a Go tag when every file changed since the last `v*` tag is packaging-only (Dockerfiles, docker CI scripts, `docker-release.yml`, `packaging-rebuild.yml`). Publish an immutable GHCR image revision `X.Y.Z-rN` (`N >= 1`) that reuses the existing `vX.Y.Z` release binaries instead.
- Enforcement: `scripts/auto-patch-decide.sh` packaging-only path filter; `packaging-rebuild` or manual **Docker release** `workflow_call` with `image_revision`
- Violation: STOP; cut `-rN` image, not `vX.Y.(Z+1)`, for Dockerfile/base-only work

**CONSTRAINT:** Container images MUST carry OCI labels: `org.opencontainers.image.version` equals app semver `X.Y.Z` only; rebuild counter belongs in the image tag `X.Y.Z-rN` and vendor label `com.behaviorengineering.image.rebuild-revision` (`rN` or empty). MUST NOT overwrite an existing GHCR tag.
- Enforcement: Docker release immutability gate (`imagetools inspect` before push); label assert in CI
- Violation: STOP; bump `-rN` instead of re-pushing the same tag

**CONSTRAINT:** Docker images, Helm charts, or other publish jobs MUST run in the **same** workflow as tag + GoReleaser (`workflow_call` or extra job). MUST NOT rely on `GITHUB_TOKEN` tag push to start a sibling workflow.
- Enforcement: Stage 5 review checklist in [reference.md](reference.md); no `on: push: tags` as the only Docker path after auto-patch
- Violation: STOP; wire `workflow_call` from auto-patch (see `setup-goreleaser` auto-patch template)

**CONSTRAINT:** When release CI publishes container images or other non-Go artifacts in the same pipeline, a tag is **published** only after a final **verify** job in that workflow is green (artifacts exist for `new_tag`, for example GHCR manifest inspect for image tags). Consumer agents MUST NOT bump submodule, `go.mod`, `images.env`, or deploy pins to `vX.Y.Z` until that full workflow succeeds (GoReleaser plus extra publish plus verify). A GitHub Release tag or `git ls-remote` alone is not enough when images are in scope.
- Enforcement: Stage 5 checklist in [reference.md](reference.md); consumer pin checklist row for publish-complete
- Violation: STOP; fix or re-run release CI before pinning consumers

CORRECT:
```bash
# Auto patch workflow green through verify for v0.2.38, then pin host
gh run list --workflow="Auto patch release" --limit 5
# confirm success for the tag, then:
git -C providers/polypus checkout v0.2.38
```

PROHIBITED:
```bash
# GoReleaser succeeded but Docker or verify failed; tag exists on origin
git -C providers/polypus checkout v0.2.38   # half-publish
```

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

**CONSTRAINT:** When a consumer change depends on an upstream PR, merge, or `v*` tag (submodule gitlink, `go.mod` require, `images.env`, `.cursor/packs/shared`), MUST merge upstream **first** (or wait until it lands), then pin the consumer to the **post-merge** base tip or exact `v*` tag in the **same** consumer PR as the related host work.
- Enforcement: before `gh pr create` / `glab mr create` / push that claims the PR is ready, ask the human once whether any pins are missing (submodule, `go.mod`, image pins, packs gitlink); load `resolve-pr-merge-conflicts` pin gate when opening the PR
- Violation: STOP; do not open a pin-only follow-up MR to realign a squash-merge SHA after the main consumer MR merged

CORRECT:
```bash
# Upstream polypus PR #60 merged to main at 3103dcb
git -C providers/polypus fetch origin main
git -C providers/polypus checkout 3103dcb
# Host MR includes providers/polypus gitlink + images.env / go.mod in one change
```

PROHIBITED:
```bash
# Consumer MR pins upstream PR tip dca273b while upstream PR still open
# → merge consumer → second MR "chore: pin to main" for the same bump
```

---

## Upstream auto-patch CI (library)

When the repo is a Go **library** (source releases / `builds.skip: true` is OK):

1. Keep tag-triggered GoReleaser (`.github/workflows/release.yml` or GitLab `.gitlab/ci/goreleaser-release.yml`) for human-pushed `v*` tags.
2. Add a default-branch push workflow/job that:
   - Skips docs/chore/ci-only ranges, harness-only path ranges, and `[skip release]` (prefer `scripts/auto-patch-decide.sh` in cursor-packs)
   - Creates annotated `vX.Y.(Z+1)`
   - Runs GoReleaser in the **same job** (CI job-token tag pushes do not reliably trigger other pipelines)
   - Calls Docker or other publish workflows via `workflow_call` in the same pipeline when images are in scope
   - Ends with a **verify** job that fails when published artifacts for `new_tag` are missing (images: registry manifest inspect)
   - Offers manual bump (`workflow_dispatch` bump input on GitHub; `RELEASE_BUMP` on GitLab web pipelines)
3. Document the policy in the upstream README under a short **Releases (for agents)** section.

**GitHub reference:** `behaviorengineering/strop` workflow `auto-patch-release.yml`.

**GitLab reference:** `.gitlab/ci/auto-patch-release.yml` (same skip/bump rules; job `auto_patch_release`). Run `prepare-go-forge` so job-token can push tags (`ci_push_repository_for_job_token_allowed`) and upload packages (`ADMIN_PACKAGES`).

---

## Consumer pin checklist

Binary TRUE/FALSE:

| Check | Method | Pass | Fail |
|-------|--------|------|------|
| Tag exists on origin | `git ls-remote --tags origin 'v*'` | Desired `vX.Y.Z` listed | Tag missing; wait or cut release |
| Publish complete (images in scope) | Auto-patch / release workflow for that tag is green through **verify** | Success on verify job | Half-publish; fix CI before pin |
| Checkout matches tag | `git -C <dep> describe --tags --exact-match` | Equals `vX.Y.Z` | Dirty or wrong SHA |
| go.mod require matches | `go list -m <module>` | Version is `vX.Y.Z` | Pseudo-version / drift |
| Working tree clean for dep | `git -C <dep> status --short` | Empty | Uncommitted dep edits |
| Parent status after pin | After gitlink bump: run **`sync-submodules-after-merge`** (`git submodule update --init --recursive`) | No `(new commits)` dirt; checkout SHA equals gitlink | Stale checkout; do not `git add` the submodule to “fix” it |
| Pre-PR pin ask / post-merge SHA | Upstream merged first; consumer gitlink is post-merge tip or `v*` tag; human asked once about missing pins before PR open | Pin-only follow-up MR after squash-merge SHA rewrite | PR-tip pin while upstream still open (unless human accepted temp pin) |

---

## Review (Stage 5)

When release CI is in the PR diff, load this skill and score [reference.md](reference.md) checklist (subject skip, harness path skip, GoReleaser same job, same-pipeline Docker, verify job, publish-complete pin gate).

---

## Pre-completion verification

- [ ] Patch is the default bump; minor/major only when asked or API warrants it
- [ ] Docs/chore/ci-only, harness-only paths, and `[skip release]` do not get tags
- [ ] Extra publish (Docker) uses `workflow_call` or same job, not tag-wake sibling workflow
- [ ] Verify job present when extra publish (Docker, charts) is in scope
- [ ] Consumer pin waits for publish-complete (full workflow green), not tag or GoReleaser alone
- [ ] Consumer pin updated submodule (or path) **and** `go.mod` when applicable
- [ ] Pre-PR pin ask done; post-merge upstream SHA or `v*` tag in same consumer change (no pin-only follow-up MR)
- [ ] No force-push of tags unless the user explicitly requests it
- [ ] If publish 403'd on packages / `admin_packages`, `prepare-go-forge` was run (or deferred with reason)
