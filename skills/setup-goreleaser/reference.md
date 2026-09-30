# GoReleaser templates (gitboard pattern)

Substitute `<project>`, `<binary>`, and `./cmd/<binary>` for the target repo. Keep structure and options unless the user asks otherwise.

## `.goreleaser.yaml`

```yaml
# yaml-language-server: $schema=https://goreleaser.com/static/schema.json
version: 2

project_name: <project>

builds:
  - id: <binary>
    main: ./cmd/<binary>
    binary: <binary>
    env:
      - CGO_ENABLED=0
      - GOWORK=off
    goos:
      - linux
      - darwin
      - windows
    goarch:
      - amd64
      - arm64
    ldflags:
      - -s -w -X main.version={{.Version}}

archives:
  - formats: [tar.gz]
    name_template: "{{ .ProjectName }}_{{ .Version }}_{{ .Os }}_{{ .Arch }}"
    format_overrides:
      - goos: windows
        formats: [zip]

checksum:
  name_template: checksums.txt

changelog:
  use: github
  sort: asc
  abbrev: -1
  groups:
    - title: Features
      regexp: '(?i)^.*?feat(\(.+\))?!?:.+$'
      order: 0
    - title: Bug fixes
      regexp: '(?i)^.*?(fix|bug)(\(.+\))?!?:.+$'
      order: 1
    - title: Docs
      regexp: '(?i)^.*?docs?.+$'
      order: 2
    - title: Others
      order: 999
  filters:
    exclude:
      - '(?i)^.*?chore(\(.+\))?!?:.+$'
      - '(?i)^.*?ci(\(.+\))?!?:.+$'

release:
  name_template: "v{{.Version}}"
```

If the main package is not under `cmd/`, set `main:` to that path and keep `-X main.version=...` only if the version var lives in `package main` of that build.

## `.github/workflows/release.yml`

```yaml
name: Release

on:
  push:
    tags:
      - "v*"

permissions:
  contents: write

jobs:
  goreleaser:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - uses: actions/setup-go@v5
        with:
          go-version-file: go.mod
          cache: true

      - uses: goreleaser/goreleaser-action@v6
        with:
          distribution: goreleaser
          version: "~> v2"
          args: release --clean
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## Version in `package main`

GoReleaser and `make build` inject the tag via ldflags. Plain `go install module/cmd/…@vX.Y.Z` does not, so print through `reportVersion()` (BuildInfo fallback). Keep `(devel)` as `dev` for local `go run` / workspace builds.

```go
import (
	"fmt"
	"runtime/debug"
	"strings"
)

// version is set by GoReleaser / make build via -ldflags -X main.version=...
// go install does not apply those ldflags, so reportVersion falls back to BuildInfo.
var version = "dev"

func reportVersion() string {
	moduleVersion := ""
	if bi, ok := debug.ReadBuildInfo(); ok {
		moduleVersion = bi.Main.Version
	}
	return resolveVersion(version, moduleVersion)
}

func resolveVersion(ldflag, moduleVersion string) string {
	if v := strings.TrimSpace(ldflag); v != "" && v != "dev" {
		return v
	}
	if v := strings.TrimSpace(moduleVersion); v != "" && v != "(devel)" {
		return v
	}
	return "dev"
}
```

Print example:

```go
fmt.Printf("%s %s\n", "<binary>", reportVersion())
```

Prefer a table test on `resolveVersion`: ldflag wins over module version; `dev` + `v0.1.0` → `v0.1.0`; `dev` + `(devel)` → `dev`.

If the version var is not in `package main`, set GoReleaser `-X` to that package path (for example `-X github.com/org/mod/internal/cli.version={{.Version}}`) and keep the same `reportVersion` helpers next to the var.

## Makefile fragment

```make
VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo dev)
LDFLAGS := -X main.version=$(VERSION)

.PHONY: build
build:
	go build -ldflags "$(LDFLAGS)" -o $(BINARY) ./cmd/<binary>
```

## `.github/workflows/auto-patch-release.yml`

Default-branch auto patch (agent-oriented). Uses shared decide script when cursor-packs is present.

```yaml
name: Auto patch release

on:
  push:
    branches: [main]
  workflow_dispatch:
    inputs:
      bump:
        description: Semver bump level
        required: false
        type: choice
        options: [patch, minor, major]
        default: patch

permissions:
  contents: write

jobs:
  release:
    runs-on: ubuntu-latest
    outputs:
      skip: ${{ steps.decide.outputs.skip }}
      new_tag: ${{ steps.decide.outputs.new_tag }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
          submodules: recursive

      - name: Decide whether to tag
        id: decide
        env:
          EVENT_NAME: ${{ github.event_name }}
          MANUAL_BUMP: ${{ github.event.inputs.bump }}
          HEAD_MSG: ${{ github.event.head_commit.message }}
        run: bash .cursor/packs/shared/scripts/auto-patch-decide.sh

      - name: Skip notice
        if: steps.decide.outputs.skip == 'true'
        run: echo "Skipping auto release: ${{ steps.decide.outputs.reason }}"

      - uses: actions/setup-go@v5
        if: steps.decide.outputs.skip != 'true'
        with:
          go-version-file: go.mod
          cache: true

      - name: Create and push tag
        if: steps.decide.outputs.skip != 'true'
        env:
          NEW_TAG: ${{ steps.decide.outputs.new_tag }}
        run: |
          set -euo pipefail
          git config user.name "github-actions[bot]"
          git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
          git tag -a "${NEW_TAG}" -m "Release ${NEW_TAG}"
          git push origin "refs/tags/${NEW_TAG}"

      - uses: goreleaser/goreleaser-action@v6
        if: steps.decide.outputs.skip != 'true'
        with:
          distribution: goreleaser
          version: "~> v2"
          args: release --clean
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

  # When the user asked for container images: add a reusable docker-release.yml with workflow_call,
  # then uncomment and set permissions.packages: write on the caller.
  # docker:
  #   needs: release
  #   if: needs.release.outputs.skip != 'true'
  #   uses: ./.github/workflows/docker-release.yml
  #   with:
  #     version: ${{ needs.release.outputs.new_tag }}
  #     git_ref: ${{ needs.release.outputs.new_tag }}
  #   secrets: inherit
```

If cursor-packs is not a submodule yet, inline the same rules from `scripts/auto-patch-decide.sh` until the pin exists.

**MUST:** auto-patch jobs use full git history (`fetch-depth: 0` on GitHub, `GIT_DEPTH: "0"` on GitLab). Range since last `v*` drives path skips.

**MUST NOT:** rely on workflow `paths:` / `paths-ignore:` or GitLab `rules:changes:` as the only harness protection (tip commit only).

## `.gitlab/ci/auto-patch-release.yml` (packs present)

Copy from `prepare-go-forge/templates/gitlab/auto-patch-release.yml` or use the same script invocation:

```bash
git submodule update --init --depth 1 .cursor/packs/shared
export OUTPUT_FILE="${CI_PROJECT_DIR}/auto-patch.env"
export EVENT_NAME="${CI_PIPELINE_SOURCE}"
export MANUAL_BUMP="${RELEASE_BUMP:-patch}"
export HEAD_MSG="${CI_COMMIT_TITLE:-}"
bash .cursor/packs/shared/scripts/auto-patch-decide.sh
source "${OUTPUT_FILE}"
```

Treat `CI_PIPELINE_SOURCE=web` as manual (same as `workflow_dispatch`); the decide script accepts `EVENT_NAME=web`.

## Inline path-filter fragment (no cursor-packs submodule)

Insert **after** the subject-releasable check and **before** semver bump. Keep in sync with `scripts/auto-patch-path-predicates.sh`.

```bash
# Keep in sync with cursor-packs scripts/auto-patch-decide.sh

is_harness_only_path() {
  local path="$1"
  [[ "${path}" == lefthook.yml ]] && return 0
  [[ "${path}" == .cursor/* ]] && return 0
  return 1
}

is_packaging_only_path() {
  local path="$1"
  case "${path}" in
    Dockerfile|Dockerfile.*) return 0 ;;
    scripts/docker-*) return 0 ;;
    scripts/ci/docker-*) return 0 ;;
    scripts/ci/switchyard-smoke-routes.toml) return 0 ;;
    .github/workflows/docker-release.yml|.github/workflows/packaging-rebuild.yml) return 0 ;;
  esac
  return 1
}

# When last_tag is v0.0.0: files="$(git diff-tree --no-commit-id --name-only -r HEAD)"
# Else: files="$(git diff --name-only "${last_tag}" HEAD)"

if [[ -n "${files}" ]]; then
  harness_only="true"
  while IFS= read -r f; do
    [[ -z "${f}" ]] && continue
    if ! is_harness_only_path "${f}"; then harness_only="false"; break; fi
  done <<< "${files}"
  if [[ "${harness_only}" == "true" ]]; then
    echo "Skipping auto release: only agent-harness paths since ${last_tag}"
    exit 0
  fi

  packaging_only="true"
  while IFS= read -r f; do
    [[ -z "${f}" ]] && continue
    if ! is_packaging_only_path "${f}"; then packaging_only="false"; break; fi
  done <<< "${files}"
  if [[ "${packaging_only}" == "true" ]]; then
    echo "Skipping auto release: packaging-only (use Docker release -rN)"
    exit 0
  fi
fi
```

On GitHub Actions, write `skip=true` to `$GITHUB_OUTPUT` instead of `exit 0` when the decide step must set job outputs.

## Project release skill

After setup, consumers often keep a **project-local** skill (not in cursor-packs) named `release-<binary>`:

- Release only from green `main`
- Annotated semver tags: `vMAJOR.MINOR.PATCH`
- `git push origin vX.Y.Z` so `release.yml` runs
- Confirm Release has binaries, `checksums.txt`, changelog groups
- Must not: force-move tags, tag dirty/feature branches, add Homebrew/Docker unless asked

```bash
git checkout main && git pull --ff-only && git status
git tag -a v0.1.0 -m "v0.1.0"
git push origin v0.1.0
gh run watch
gh release view v0.1.0
goreleaser check   # local config only
```
