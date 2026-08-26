---
name: setup-goreleaser
description: >-
  Scaffold GoReleaser v2 + GitHub Actions release for a Go CLI (gitboard
  pattern): .goreleaser.yaml, release.yml, main.version ldflags, optional
  version subcommand. Use when adding GoReleaser, GitHub Releases for Go
  binaries, or tag-based multi-platform builds.
---

# Setup GoReleaser

Wire a Go CLI for tag-triggered GitHub Releases the same way as gitboard: GoReleaser v2, `CGO_ENABLED=0`, linux/darwin/windows × amd64/arm64, GitHub changelog groups, no Homebrew/Docker unless asked.

**Templates:** [reference.md](reference.md)

**Related (after setup):** project-local release skill (e.g. `release-<binary>`) for cut-a-tag procedure; see [reference.md](reference.md#project-release-skill).

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
- Ensure `var version = "dev"` in the main package and a way to print it (`version` subcommand or equivalent).
- Align local `make build` ldflags with `-X main.version=...` when a Makefile exists.
- Run `goreleaser check` after writing config (if `goreleaser` is installed).

## Must not

- Do not add Homebrew taps, Docker images, NFPM, or Snap unless the user asks.
- Do not force-push tags or invent a first release tag during setup.
- Do not commit secrets; `GITHUB_TOKEN` from Actions is enough for public/private GitHub Releases.
- Do not overwrite an existing `.goreleaser.yaml` or `release.yml` without confirmation.

---

## Steps

1. **Discover** — binary name, `./cmd/...` path, existing release files, version var.
2. **Write** `.goreleaser.yaml` from [reference.md](reference.md) (substitute project/binary/main).
3. **Write** `.github/workflows/release.yml` from [reference.md](reference.md).
4. **Wire version** — in the build main package:

```go
// version is set by GoReleaser / make build via -ldflags -X main.version=...
var version = "dev"
```

Expose it (e.g. `<binary> version` printing `"<binary> %s\n", version`).

5. **Makefile** (if present) — keep local builds consistent:

```make
VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo dev)
LDFLAGS := -X main.version=$(VERSION)
# build: go build -ldflags "$(LDFLAGS)" -o $(BINARY) ./cmd/<binary>
```

6. **Validate** — `goreleaser check` when available.
7. **Document briefly** — README install note: download Release assets for the tag; contributors use `make` / `go run`.
8. **Optional** — add a project skill `release-<binary>` (cut annotated `v*` tag from green `main`); template in [reference.md](reference.md#project-release-skill).

---

## Checklist

- [ ] `.goreleaser.yaml` (v2, multi-platform, ldflags, changelog groups)
- [ ] `.github/workflows/release.yml` (tag `v*`, goreleaser-action v6)
- [ ] `main.version` default `"dev"` + user-visible version command
- [ ] Makefile ldflags aligned (if Makefile exists)
- [ ] `goreleaser check` OK (or noted if binary missing)
- [ ] No Homebrew/Docker unless requested
