# Go binary license reference

LOAD-WHEN: implementing `setup-go-binary-license` (file list, make targets, Gate signatures).

Product-neutral names: replace `<bin>`, `<product>`, `<FEATURE>`, `<ENV>`.

---

## Package files (`internal/license`)

| File | Role |
|------|------|
| `errors.go` | `var ErrActivation = errors.New("activation required")` |
| `license.go` | JSON `File` / `Payload`, version, `hasFeature` (empty list = all) |
| `sign.go` | Ed25519 sign; **no** attestation key field |
| `verify.go` | VerifyBytes / VerifyFile against embedded pubkey |
| `public_key.go` | `//go:embed keys/product.pub.b64` |
| `testing.go` | `SetPublicKeyForTest` / `ResetPublicKeyForTest` |
| `enforce.go` | ResolvePath: flag, env, `~/.config/<product>/license.lic`, `./license.lic` |
| `gate.go` | `//go:build !release` no-op `Gate(path, feature string) error` |
| `gate_release.go` | `//go:build release` `return Enforce(path, feature)` |
| `signing_key.go` | ResolveSigningKey (file, then Keychain, then `keys/signing.key`) |
| `filename.go` | SafeLicenseFilename |
| `ledger.go` | JSONL under `~/.config/<product>/issued.jsonl` |
| `summary.go` | Redacted `show` (no secrets) |
| `cli.go` | `BindFlags` for `--license` |
| `keychain_bridge.go` | Wrappers |
| `keychain/keychain.go` | **Product-specific** `Service` / `Account` / `Label` |
| `keychain/keychain_darwin.go` | `//go:build darwin && cgo` |
| `keychain/keychain_stub.go` | `//go:build !darwin \|\| !cgo` |

Dep: `github.com/keybase/go-keychain` (operator keygen on Darwin). Customer GoReleaser stays `CGO_ENABLED=0`.

Constants (do not copy another product's strings):

```go
const (
    FeatureServe = "serve" // or the product's one default feature
    EnvLicense   = "MYPRODUCT_LICENSE"
    ConfigDirName = "myproduct"
)
```

Path order MUST be flag → env → XDG/config file if present → cwd `license.lic`.

---

## Gate signatures

```go
// both build tags:
func Gate(path, feature string) error
```

```go
// cmd/<bin>/main.go (sketch)
if len(os.Args) > 1 {
    switch os.Args[1] {
    case "version":
        // print version; no Gate
        return
    case "license":
        os.Exit(cli.RunLicense(os.Args[2:]))
    }
}
fs := flag.NewFlagSet(os.Args[0], flag.ExitOnError)
licensePath := license.BindFlags(fs)
_ = fs.Parse(os.Args[1:])
if err := license.Gate(*licensePath, license.FeatureServe); err != nil {
    fmt.Fprintln(os.Stderr, err.Error())
    os.Exit(1)
}
// THEN otel, THEN RemoveAll(socket), THEN Listen
```

**Rules:**

- MUST skip Gate for `version` and `license`
- MUST NOT call `Gate` with only a feature string
- MUST NOT start telemetry or delete sockets before Gate fails

---

## Make targets

```make
GARBLE_VERSION ?= v0.16.0
KEYGEN_ARGS ?=
ifeq ($(FORCE),1)
KEYGEN_ARGS += --force
endif
LICENSE_FILE := $(HOME)/.config/<product>/license.lic

build:
	go build -ldflags "$(LDFLAGS)" -o bin/$(BINARY) ./cmd/<bin>

build-protected:
	go build -tags release -ldflags="-s -w $(LDFLAGS)" -o bin/$(BINARY) ./cmd/<bin>

build-garble:
	garble build -tags release -ldflags="-s -w $(LDFLAGS)" -o bin/$(BINARY) ./cmd/<bin>

license-keygen:
	go run ./cmd/<bin> license keygen $(KEYGEN_ARGS)

license-keygen-release:
	go run ./cmd/<bin> license keygen --embed-pub internal/license/keys/product.pub.b64 $(KEYGEN_ARGS)

dev-license:
	go run ./cmd/<bin> license sign --licensee dev-local --days 3650 --no-ledger --out $(LICENSE_FILE)

issue-license:
	go run ./cmd/<bin> license issue --licensee "$(LICENSEE)" --days $(DAYS) --features "$(FEATURES)"

test-license-release:
	go test -tags release ./internal/license/...
```

**Rules:**

- MUST keep `build` ungated
- MUST keep version `-X` on protected ldflags
- NEVER document `make --force`; use `FORCE=1`
- NEVER require garble when `garble` errors that Go is too new; `build-protected` is `go build -tags release`

`.gitignore`: `keys/signing.key`, `license.lic`. Ledger lives under XDG, not the repo.

---

## GoReleaser and CI

```yaml
builds:
  - id: <bin>
    tags:
      - release
    env:
      - CGO_ENABLED=0
```

CI unit job: `go test ./internal/license/...` and `go test -tags release ./internal/license/...`.

CI compile job: **no** `release` tag.

---

## Tests to port

- Sign/verify happy path
- Expired, wrong key, missing file, missing feature → `ErrActivation`
- ResolvePath: flag > env > config > cwd
- `!release` Gate is no-op
- `-tags release` Gate fails without a file and passes with a temp signed file (`SetPublicKeyForTest`)

---

## Out of scope (NEVER copy)

- Attestation private keys inside the license JSON
- NTP / clock-skew network checks
- Gating `pkg/` APIs
- A second git repository for the license package
- Legal SPDX / dual-license text (separate document)
- Machine binding or remote revocation (local ledger is audit only)

Accepted limits (state in README): copied `.lic` works on any machine; expiry uses local clock; git access bypasses the Gate.
