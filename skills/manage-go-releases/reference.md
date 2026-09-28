# Manage Go releases — review checklist (Stage 5)

Load this when a PR touches `.github/workflows/*release*`, `.goreleaser.yaml`, or `scripts/auto-patch-decide.sh`.

| Check | Pass | Fail |
|-------|------|------|
| Subject skip | Auto-patch skips `docs:` / `chore:` / `ci:` / `[skip release]` | Missing or incomplete |
| Harness path skip | Skips when diff since last tag is only `.cursor/**` or `lefthook.yml` | Pack bumps cut product tags |
| GoReleaser same job | Tag create + `goreleaser release` in one workflow job (or same pipeline without tag-wake) | Tag push expects another workflow to start |
| Extra artifacts (Docker, etc.) | `workflow_call` or same-job publish after GoReleaser | Only `on: push: tags` sibling workflow |

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
```

PROHIBITED:

```yaml
# Auto patch pushes tag; docker-release only on push tags (GITHUB_TOKEN does not trigger it)
on:
  push:
    tags: ["v*"]
```
