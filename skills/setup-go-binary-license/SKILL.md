---
name: setup-go-binary-license
description: >-
  Signed Ed25519 activation for a shipped Go CLI or daemon: license.lic
  issuance, release-tag Gate, optional garble, GoReleaser -tags release.
  Use when adding product licenses, obfuscating a customer binary, garble,
  activation required, license-keygen, or protecting cortexd/kairos-style
  binaries. Do not use for SaaS API keys or gating importable pkg/ libraries.
---

# Setup Go binary license

**Moral:** Activation belongs on the process customers run. Obfuscation only hardens that binary. Source `go run` / `go test` stay ungated.

Load this skill when adding or changing signed `license.lic` activation, `make build-protected`, or GoReleaser `-tags release` for a Go CLI or daemon.

**Reference:** [reference.md](reference.md) (file list, make targets, Gate signatures).

**Related:** `.cursor/skills/setup-goreleaser/SKILL.md` for archive plumbing; `.cursor/skills/manage-go-releases/SKILL.md` for tags. This skill owns the activation Gate, not tagging policy.

---

## When to load

- User asks to license, activate, obfuscate, or garble a Go binary customers run
- Adding `internal/license`, `license.lic`, `activation required`, or `cortexd license` / `<bin> license` issuance
- GoReleaser or Makefile for a closed/on-prem CLI or daemon

**Do not load** when the product is a public Go module others import, or a hosted API that uses accounts and tokens instead of a file next to the binary.

---

## Fit check (before any files)

**CONSTRAINT:** MUST refuse a binary license Gate when customers receive source (`go get` / public module) as the product, or when the vendor hosts the process (SaaS). MUST proceed only when customers run a shipped binary or image and the git tree stays private.

- MUST: gate `cmd/<binary>` only; keep `pkg/` ungated
- MUST: keep license code in the same product repository (`internal/license`)
- MUST NOT: import another product's license package or extract a shared license module unless the user explicitly asks for multi-product sharing
- MUST NOT: copy attestation keys, NTP clock checks, or product-specific feature names from a reference implementation

Enforcement: state distribution (binary vs module vs hosted) in the change notes; grep `pkg/` for `license.Gate` / `license.Enforce`
Violation: STOP, drop library/SaaS gating, re-verify

CORRECT:
```text
On-prem daemon: Gate in cmd/productd before Listen; pkg/engine has no license import.
```

PROHIBITED:
```text
license.Gate in pkg/engine.Process so every importer is locked.
```

---

## Core constraints

**CONSTRAINT:** Dev builds MUST stay ungated. Release artifacts MUST enforce. `Gate(path, feature)` MUST take the `--license` flag path.

- MUST: `//go:build !release` `Gate` returns nil; `//go:build release` `Gate` calls `Enforce(path, feature)`
- MUST: skip Gate for `version` and `license …` subcommands
- MUST: dispatch those subcommands before serve `flag.Parse`
- MUST: call Gate after flags and before OTel, socket `RemoveAll`, and `Listen`
- MUST NOT: copy a `Gate(feature)` that ignores `--license`

Enforcement: grep `Gate(` in `cmd/` and `internal/license/gate*.go`; confirm serve calls `Gate(*licensePath, …)` before Listen
Violation: STOP, fix signature and call order, re-verify

CORRECT:
```go
licensePath := license.BindFlags(fs)
_ = fs.Parse(os.Args[1:])
if err := license.Gate(*licensePath, license.FeatureServe); err != nil {
    fmt.Fprintln(os.Stderr, err.Error())
    os.Exit(1)
}
```

PROHIBITED:
```go
flag.Parse()
_ = os.RemoveAll(*socket) // activation failure would kill a running daemon
license.Gate(license.FeatureServe) // ignores --license
```

**CONSTRAINT:** Fail closed with a generic message. MUST NOT leak paths, keys, or crypto details to users.

- MUST: print `activation required` (verbatim) on missing, invalid, expired, wrong-key, or wrong-feature
- MUST NOT: log the license path, signature, or public-key errors on the customer path

Enforcement: grep customer-facing prints in `cmd/` and `internal/license`; only `ErrActivation.Error()` on Gate failure
Violation: STOP, collapse messages, re-verify

**CONSTRAINT:** Vendor private key MUST stay off git. Product binaries MUST embed the public key only. Keychain item names MUST be unique per product.

- MUST: gitignore `keys/signing.key`; commit `internal/license/keys/product.pub.b64` as a real Ed25519 public key before the first `-tags release` artifact
- MUST: use a product-specific Keychain service (not a copied name from another product)
- MUST: Linux / no Keychain: `--write-key-file`; Make: `FORCE=1` or `KEYGEN_ARGS=--force` (Make swallows `--force`)
- MUST NOT: ship an empty `product.pub.b64` (every customer binary fail-closes)

Enforcement: `git check-ignore -v keys/signing.key`; `product.pub.b64` is non-empty base64 of 32 bytes; Keychain `Service` string contains the product name
Violation: STOP, unstage secrets / embed a real pubkey / rename Service, re-verify

CORRECT:
```text
Service = "myproduct-license-signing"
```

PROHIBITED:
```text
Service = "xynova-license-signing" // copied from another product
```

**CONSTRAINT:** Customer archives MUST actually enforce. Contributor `make build` / CI compile MUST stay ungated.

- MUST: add `tags: [release]` on the GoReleaser binary build when this product already publishes archives
- MUST: keep default `go test ./...` and CI `go build` without `release`
- MUST: add `go test -tags release ./internal/license/...` so release `Gate` is not a silent no-op
- MUST: first `-tags release` tag is a behavior break; operators MUST issue licenses before that tag
- MUST NOT: treat `garble` as required when the toolchain is newer than garble's linker patches; `go build -tags release` is the Gate. Optional `make build-garble` when garble supports that Go version

Enforcement: read `.goreleaser.yaml` builds.tags; CI test job includes `-tags release` for `internal/license`; Makefile `build` has no `release` tag
Violation: STOP, split ungated CI build vs tagged archives, re-verify

---

## Steps

1. **Fit** — confirm customers run a binary/image; source stays private. If not, stop.
2. **Package** — add `internal/license` from [reference.md](reference.md) (sign/verify/enforce/gate pair/ledger/keychain). No attestation. One default feature (for example `serve`).
3. **CLI** — `<bin> license keygen|sign|issue|show|list` in `internal/cli`; serve `--license` + env + `~/.config/<product>/license.lic` + `./license.lic`.
4. **Wire** — Gate in `cmd/<bin>` as specified. Make targets from the reference. Gitignore the private key.
5. **Release** — embed pubkey; GoReleaser `tags: [release]`; CI ungated build + release-tag license tests.
6. **Prove** — `go test ./internal/license/...`; `go test -tags release ./internal/license/...`; ungated binary starts without `.lic`; `-tags release` binary prints `activation required` then starts with a matching file.

---

## Pre-completion checklist

- [ ] **Binary only:** no `license` import under `pkg/`
      Method: `rg 'internal/license' pkg/`
      Pass: no matches
      Fail: STOP, move Gate to `cmd/`
- [ ] **Gate path:** serve calls `Gate(*licensePath, feature)` before Listen/OTel
      Method: read `cmd/<bin>/main.go`
      Pass: order is flags → Gate → side effects
      Fail: STOP, reorder
- [ ] **Build tags:** `gate.go` is `!release`; `gate_release.go` is `release`
      Method: read both files
      Pass: both tags present
      Fail: STOP, add files
- [ ] **No secrets:** `keys/signing.key` ignored; pubkey committed and non-empty
      Method: `git status` + `git check-ignore`
      Pass: key untracked/ignored; `.pub.b64` tracked
      Fail: STOP, unstage key
- [ ] **Archives enforce:** GoReleaser has `tags: [release]`
      Method: read `.goreleaser.yaml`
      Pass: tags list includes `release`
      Fail: STOP, add tags
- [ ] **Tests:** default package tests plus `-tags release` license tests pass
      Method: `go test ./internal/license/...` and `go test -tags release ./internal/license/...`
      Pass: both green
      Fail: STOP, fix tests
