# Manage Go releases — review checklist (Stage 5 — CI Quality)

Load when a PR touches:

- `.github/workflows/*release*`, `**/auto-patch-release.yml`
- `.gitlab/ci/*release*`, `.gitlab/ci/auto-patch-release.yml`
- `.goreleaser.yaml`, `.goreleaser.yml`
- `scripts/auto-patch-decide.sh`, `scripts/auto-patch-path-predicates.sh`
- `setup-goreleaser/**`, `prepare-go-forge/templates/**/auto-patch*`

Record findings with category **CI Quality**.

| Check | Pass | Fail |
|-------|------|------|
| Subject skip | Auto-patch skips `docs:` / `chore:` / `ci:` / `[skip release]` | Missing or incomplete |
| Harness path skip | Skips when diff since last tag is only `.cursor/**` or `lefthook.yml` (script or inline sync with `auto-patch-path-predicates.sh`) | Pack/harness bumps cut product tags |
| Packaging-only skip | Skips Go tag when diff is only Docker/packaging paths; publish `X.Y.Z-rN` via packaging rebuild | Dockerfile-only cuts new `vX.Y.Z` |
| Full history | `fetch-depth: 0` (GHA) / `GIT_DEPTH: "0"` (GitLab) on auto-patch job | Shallow clone; range since last `v*` wrong |
| Image revision tags | GHCR `X.Y.Z-rN` reuses `vX.Y.Z` binaries; immutable tags; OCI `version` = app semver | Rebuild counter in app semver or mutable tags |
| GoReleaser same job | Tag create + `goreleaser release` in one workflow job (or same pipeline without tag-wake) | Tag push expects another workflow to start |
| Extra artifacts (Docker, etc.) | `workflow_call` or same-job publish after GoReleaser | Only `on: push: tags` sibling workflow |
| Verify after publish | Final job asserts artifacts for `new_tag` (e.g. `docker buildx imagetools inspect`) | GoReleaser or Docker green without registry proof |
| Consumer pin gate | Docs / agents wait for full workflow green including verify | Pin on tag exists or GoReleaser-only success |
| Pre-PR pin ask / post-merge SHA | Upstream merged; consumer pins post-merge tip or `v*` in same PR; agent asked human about missing pins before open | Pin-only follow-up after squash-merge; PR-tip pin while upstream open |

CORRECT (GitHub — packs submodule):

```yaml
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - run: bash .cursor/packs/shared/scripts/auto-patch-decide.sh
```

CORRECT (GitLab — packs submodule):

```yaml
  variables:
    GIT_DEPTH: "0"
  script:
    - git submodule update --init --depth 1 .cursor/packs/shared
    - export OUTPUT_FILE="${CI_PROJECT_DIR}/auto-patch.env"
    - export EVENT_NAME="${CI_PIPELINE_SOURCE}"
    - bash .cursor/packs/shared/scripts/auto-patch-decide.sh
```

PROHIBITED:

```yaml
# Subject-only skip; harness path filter missing — packs pin can cut v*
# Only docs/chore/ci subject loop, no file list since last_tag
```

```yaml
# Auto patch pushes tag; docker-release only on push tags (GITHUB_TOKEN does not trigger it)
on:
  push:
    tags: ["v*"]
```
