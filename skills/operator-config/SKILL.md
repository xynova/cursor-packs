---
name: operator-config
description: >-
  Operator app configuration discovery, init, and secret resolution for Go CLIs
  and daemons: XDG user config.yaml, make init / binary init, no literal secrets,
  ${VAR} expand, optional macOS Keychain. Use when adding config.yaml, UserConfig
  paths, CORTEX_CONFIG/POLYPUS_CONFIG-style overrides, init targets, env
  placeholders, Keychain-backed secrets, or .env.example. Triggers: config
  discovery, XDG_CONFIG_HOME, ~/.config, make init, keychain secrets, no-secrets.
---

# Operator config (discovery + secrets)

**Moral:** Live config belongs under the user config dir. Secrets never sit as literals in YAML; they resolve from the environment or Keychain after discovery.

Load when authoring or changing operator config loading, `config.yaml` / `config.yaml.example`, `make init` / `<bin> init`, secret fields, or macOS Keychain storage for runtime credentials.

**Related:** shared Make verb `init` (golang-quality shared Make verbs when present); license signing Keychain stays in `setup-go-binary-license` (signing key, not app passwords).

## When to load

- Adding or changing `config.yaml`, `config.yaml.example`, or embedded config templates
- Implementing config path resolution, `LoadConfig`, or Viper/search paths
- Adding `make init` / `<bin> init` that writes user config
- Wiring passwords, API keys, tokens, or master keys into config
- Storing or loading runtime secrets from macOS Keychain
- Writing `.env.example` or no-secrets review findings

## Core constraints

**CONSTRAINT:** Config discovery MUST prefer an explicit override, then the XDG user config file, then documented repo/cwd fallbacks. MUST include `~/.config/<app>/config.yaml` (or `$XDG_CONFIG_HOME/<app>/config.yaml`) in the search path. MUST NOT load only a repo-root `config.yaml` as the sole production path.

Canonical order (first existing wins after the override):

1. Explicit path flag or env (for example `<APP>_CONFIG` / `--config`)
2. `$XDG_CONFIG_HOME/<app>/config.yaml` or `~/.config/<app>/config.yaml`
3. Optional host-documented fallbacks (cwd `config.yaml`, `$<APP>_ROOT/config.yaml`, embedded example for first-run only)

- Enforcement: Read resolve helpers; user config path appears before or equal to cwd fallback; override is first
- Violation: STOP, add `UserConfigFilePath` (or equivalent) to the chain, re-verify

CORRECT:
```text
CORTEX_CONFIG → ~/.config/dss-cortex/config.yaml → ./config.yaml (dev fallback)
```

PROHIBITED:
```text
// Only looks next to the binary / cwd; never XDG user dir
open("config.yaml")
```

**CONSTRAINT:** When the app has a durable operator config file, MUST provide `make init` and/or `<bin> init` that creates the user config directory and writes `config.yaml` only if missing (unless `--force`). MUST refresh `config.yaml.example` under the user config dir (or document a shipped example in-repo). Live `config.yaml` MUST be mode `0600` when the host creates it. MUST NOT overwrite an existing live config without an explicit force flag.

- Enforcement: Trace init command and Make target; missing-file create; force gate; file mode
- Violation: STOP, add init that writes under the user config dir, re-verify

CORRECT:
```text
make init  →  ~/.config/<app>/config.yaml (create if missing, 0600)
           →  ~/.config/<app>/config.yaml.example (refresh)
```

PROHIBITED:
```text
# Operators must manually mkdir and cp with no init verb
cp config.yaml.example ./config.yaml
```

**CONSTRAINT:** Config files and committed examples MUST NOT contain literal secrets (API keys, passwords, tokens, master keys, credential-bearing URLs). MUST reference secrets via env placeholders (`${VAR}`) and/or Keychain account names. MUST expand placeholders with a generic walk over string fields (or equivalent whole-document expand). MUST fail closed if any `${...}` remains unresolved after expand when that field is required, or when the host policy rejects unresolved placeholders globally.

- Enforcement: Grep examples for high-entropy literals; read expand + unresolved check; review Stage / no-secrets
- Violation: STOP, replace literals with `${ENV}` or Keychain refs, add expand + fail-closed, re-verify

CORRECT:
```yaml
redis:
  password: "${REDIS_PASSWORD}"
immudb:
  password: "${IMMUDB_PASSWORD}"
```

PROHIBITED:
```yaml
redis:
  password: "s3cr3t-local"
```

**CONSTRAINT:** Runtime secret resolution MUST try, in order: process environment (including values loaded from a documented local `.env` when the host uses godotenv), then optional macOS Keychain for the named secret when Keychain integration is enabled for that app, then fail closed if the secret is required and still empty. MUST use a stable Keychain service id derived from the app name (for example `<app>` or reverse-DNS) and a stable account/name per secret. MUST NOT write runtime passwords into YAML after resolve. MUST NOT require Keychain on non-Darwin hosts; file or env-only fallbacks MUST work there.

Signing private keys for license issuance remain under `setup-go-binary-license` and MAY use a dedicated Keychain item; do not conflate signing-key storage with Redis/API password items.

- Enforcement: Read secret resolve helper; order env → Keychain → error; stub/non-Darwin path exists
- Violation: STOP, implement ordered resolve + platform stub, re-verify

CORRECT:
```text
password: "${REDIS_PASSWORD}"
→ os.Getenv("REDIS_PASSWORD")
→ else Keychain service=<app> account=REDIS_PASSWORD (when enabled)
→ else error if required
```

PROHIBITED:
```text
// Keychain-only on all platforms; Linux CI cannot start
loadFromKeychainOrPanic("redis")
```

**CONSTRAINT:** Pack docs and shared examples MUST stay product-neutral (`<app>`, `~/.config/<app>/`). Host READMEs MAY name the product and concrete paths. MUST NOT put one host's brand or private layout into this skill as a hard requirement.

- Enforcement: Scan this skill for host brand paths beyond illustrative CORRECT lines
- Violation: STOP, generalize wording, move host specifics to the consumer

## Steps

1. **Name the app dir:** choose `<app>` for XDG (`~/.config/<app>/`) and the override env (`<APP>_CONFIG`).
2. **Discovery:** implement override → user config.yaml → documented fallbacks; unit-test the order.
3. **Init:** embed or ship an example template; wire `make init` / `<bin> init` (create-if-missing, `0600`, refresh example).
4. **Secrets:** YAML placeholders only; generic expand; fail-closed; document env names in `.env.example`.
5. **Keychain (optional runtime):** Darwin store/load by service+account; env wins; non-Darwin stub returns err or skips.
6. **Serve path:** `make serve` loads discovered config (not a one-off cwd file) unless override is set.

## Pre-completion checklist

- [ ] **User dir in path:** Discovery includes `~/.config/<app>/config.yaml` (or `$XDG_CONFIG_HOME/...`)
      Method: Read resolve function / tests
      Pass: User path in candidate list before optional cwd-only production use
      Fail: Cwd-only → STOP, add user path
- [ ] **Override first:** `<APP>_CONFIG` or `--config` wins when set
      Method: Test with override pointing at a temp file
      Pass: That file loads
      Fail: Override ignored → STOP, fix order
- [ ] **Init verb:** `make init` or `<bin> init` creates user config if missing
      Method: Run init against empty temp `XDG_CONFIG_HOME`
      Pass: `config.yaml` exists mode `0600` (or documented equivalent)
      Fail: No init / always overwrite → STOP, fix
- [ ] **No literal secrets:** Examples and templates use `${VAR}` or Keychain refs only
      Method: Grep template for password/api_key literals
      Pass: No real secrets
      Fail: Literal found → STOP, replace
- [ ] **Expand + fail-closed:** Unresolved `${` cannot silently ship into runtime for required secrets
      Method: Unit test with missing env
      Pass: Error or validation failure
      Fail: Empty password accepted when required → STOP, fail closed
- [ ] **Keychain order:** Env beats Keychain; non-Darwin does not hard-require Keychain
      Method: Read resolve + build tags / stub
      Pass: Ordered resolve; stub compiles
      Fail: Keychain-only → STOP, add env path
