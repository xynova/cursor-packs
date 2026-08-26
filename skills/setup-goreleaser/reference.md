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

```go
// version is set by GoReleaser / make build via -ldflags -X main.version=...
var version = "dev"
```

Print example:

```go
fmt.Printf("%s %s\n", "<binary>", version)
```

## Makefile fragment

```make
VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo dev)
LDFLAGS := -X main.version=$(VERSION)

.PHONY: build
build:
	go build -ldflags "$(LDFLAGS)" -o $(BINARY) ./cmd/<binary>
```

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
