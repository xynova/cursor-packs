---
name: setup-goreleaser
description: >-
  Scaffold GoReleaser v2 + GitHub Actions release for a Go CLI (gitboard
  pattern): .goreleaser.yaml, release.yml, main.version ldflags, BuildInfo
  fallback for go install, optional version subcommand. Use when adding
  GoReleaser, GitHub Releases for Go binaries, or tag-based multi-platform builds.
---

# Setup GoReleaser

Wire a Go CLI for tag-triggered GitHub Releases the same way as gitboard: GoReleaser v2, `CGO_ENABLED=0`, linux/darwin/windows × amd64/arm64, GitHub changelog groups, no Homebrew/Docker unless asked.

**Templates:** [reference.md](reference.md)

**Related (after setup):** `.cursor/skills/prepare-go-forge/SKILL.md` for host CLI settings (protected `main`, job-token packages/releases, quality + secret CI); `.cursor/skills/manage-go-releases/SKILL.md` for auto-patch / skip / consumer pin policy; optional project-local cut-a-tag skill (e.g. `release-<binary>`) - see [reference.md](reference.md#project-release-skill).

---

## When to load

- User asks to add GoReleaser, release binaries, or GitHub Releases for a Go CLI
- Bootstrapping release CI in a new or existing Go module

---

## Discover first

Before writing files, detect:

| Fact | How |
|------|-----|
| Module / binary name | `go.mod` module path basename, or `cmd/<name>` |
| Main package | Prefer `./cmd/<binary>`; else ask if only `package main` at root |
| Existing release | Skip overwrite of `.goreleaser.yaml` / `release.yml` unless user asks to replace |
| Version injection | Search for `main.version` / `-X main.version` |

Defaults: `project_name` = binary name; `main` = `./cmd/<binary>`; `binary` = `<binary>`.

---

## Must

- Use GoReleaser **config version 2** and action `goreleaser/goreleaser-action@v6` with `version: "~> v2"`.
- Builds: `CGO_ENABLED=0`, `GOWORK=off`; goos linux/darwin/windows; goarch amd64/arm64.
- Ldflags: `-s -w -X main.version={{.Version}}` (package `main` in the build `main` path).
- Archives: `tar.gz`; Windows override `zip`; checksums file `checksums.txt`.
- Changelog: `use: github` with Features / Bug fixes / Docs / Others; exclude chore/ci.
- Workflow: on push tags `v*`; `permissions.contents: write`; `fetch-depth: 0`; Go from `go.mod`.
- Ensure `var version = "dev"` in the main package (or the package named by `-X`) and a way to print it (`version` subcommand or equivalent).
- MUST fall back to `runtime/debug.BuildInfo` when the ldflag is still `dev`, so `go install module/cmd/…@vX.Y.Z` prints the module tag. Plain `go install` does not apply GoReleaser/`make` ldflags.
- MUST treat module version `(devel)` as local development and keep reporting `dev`.
- Align local `make build` ldflags with `-X main.version=...` when a Makefile exists.
- Run `goreleaser check` after writing config (if `goreleaser` is installed).

## Must not

- Do not add Homebrew taps, Docker images, NFPM, or Snap unless the user asks.
- Do not force-push tags or invent a first release tag during setup.
- Do not commit secrets; `GITHUB_TOKEN` from Actions is enough for public/private GitHub Releases.
- Do not overwrite an existing `.goreleaser.yaml` or `release.yml` without confirmation.
- Do not print only the ldflag `version` string from a `version` command; that stays `dev` after `go install` without the BuildInfo fallback.

---

## Steps

1. **Discover** - binary name, `./cmd/...` path, existing release files, version var.
2. **Write** `.goreleaser.yaml` from [reference.md](reference.md) (substitute project/binary/main).
3. **Write** `.github/workflows/release.yml` from [reference.md](reference.md).
4. **Wire version** - in the build main package (or the package the `-X` path targets):

```go
import (
	"fmt"
	"runtime/debug"
	"strings"
)

// version is injected by GoReleaser / make build via -ldflags -X main.version=...
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

Expose it (e.g. `<binary> version` printing `"<binary> %s\n", reportVersion()`). Prefer a small unit test on `resolveVersion` (ldflag wins; `dev`+`vX.Y.Z` → tag; `dev`+`(devel)` → `dev`).

If the version var lives outside `package main`, keep GoReleaser `-X` aligned with that import path (for example `-X github.com/org/mod/internal/cli.version={{.Version}}`).

5. **Makefile** (if present) - keep local builds consistent:

```make
VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo dev)
LDFLAGS := -X main.version=$(VERSION)
# build: go build -ldflags "$(LDFLAGS)" -o $(BINARY) ./cmd/<binary>
```

6. **Validate** - `goreleaser check` when available.
7. **Prepare forge** - run `.cursor/skills/prepare-go-forge/SKILL.md` (host CLI: protected `main`, packages, job-token policies, quality + secret CI) before the first publish.
8. **Document briefly** - README install note: download Release assets for the tag; contributors use `make` / `go run`; `go install …@vX.Y.Z` should still print the module version via BuildInfo.
9. **Optional** - add a project skill `release-<binary>` (cut annotated `v*` tag from green `main`); template in [reference.md](reference.md#project-release-skill).

---

## Checklist

- [ ] `.goreleaser.yaml` (v2, multi-platform, ldflags, changelog groups)
- [ ] `.github/workflows/release.yml` (tag `v*`, goreleaser-action v6)
- [ ] `version` default `"dev"` + `reportVersion` / BuildInfo fallback + user-visible version command
- [ ] Makefile ldflags aligned (if Makefile exists)
- [ ] `goreleaser check` OK (or noted if binary missing)
- [ ] Forge prepared (`prepare-go-forge`) or explicitly deferred
- [ ] No Homebrew/Docker unless requested
