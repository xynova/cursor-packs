# Manage Go releases — review checklist (Stage 5)

Load this when a PR touches `.github/workflows/*release*`, `.goreleaser.yaml`, or `scripts/auto-patch-decide.sh`.

| Check | Pass | Fail |
|-------|------|------|
| Subject skip | Auto-patch skips `docs:` / `chore:` / `ci:` / `[skip release]` | Missing or incomplete |
| Harness path skip | Skips when diff since last tag is only `.cursor/**` or `lefthook.yml` | Pack bumps cut product tags |
| Packaging-only skip | Skips Go tag when diff is only Docker/packaging paths; publish `X.Y.Z-rN` via packaging rebuild | Dockerfile CVE cuts new `vX.Y.Z` |
| Image revision tags | GHCR `X.Y.Z-rN` reuses `vX.Y.Z` binaries; immutable tags; OCI `version` = app semver | Rebuild counter in app semver or mutable tags |
| GoReleaser same job | Tag create + `goreleaser release` in one workflow job (or same pipeline without tag-wake) | Tag push expects another workflow to start |
| Extra artifacts (Docker, etc.) | `workflow_call` or same-job publish after GoReleaser | Only `on: push: tags` sibling workflow |
| Verify after publish | Final job asserts artifacts for `new_tag` (e.g. `docker buildx imagetools inspect`) | GoReleaser or Docker green without registry proof |
| Consumer pin gate | Docs / agents wait for full workflow green including verify | Pin on tag exists or GoReleaser-only success |

CORRECT:

```yaml
jobs:
  release:
    steps:
      - run: bash .cursor/packs/shared/scripts/auto-patch-decide.sh
      - run: git tag && git push origin refs/tags/...
      - uses: goreleaser/goreleaser-action@v6
  docker:
    needs: release
    uses: ./.github/workflows/docker-release.yml
  verify:
    needs: [release, docker]
    if: needs.release.outputs.skip != 'true'
    steps:
      - run: docker buildx imagetools inspect ghcr.io/ORG/IMAGE:${VERSION}
```

PROHIBITED:

```yaml
# Auto patch pushes tag; docker-release only on push tags (GITHUB_TOKEN does not trigger it)
on:
  push:
    tags: ["v*"]
```
