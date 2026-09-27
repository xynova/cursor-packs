---
name: operator-config
description: >-
  Operator app configuration discovery, init, and secret resolution for Go CLIs
  and daemons: XDG user config.yaml, make init / binary init, no literal secrets,
  ${VAR} expand, zalando/go-keyring (Keychain / Credential Manager / Secret Service).
  Use when adding config.yaml, UserConfig paths, CORTEX_CONFIG/POLYPUS_CONFIG-style
  overrides, init targets, env placeholders, keyring-backed secrets, or .env.example.
  Triggers: config discovery, XDG_CONFIG_HOME, ~/.config, make init, keyring secrets, no-secrets.
---

# Operator config (discovery + secrets)

**Moral:** Live config belongs under the user config dir. Secrets never sit as literals in YAML; they resolve from the environment or the OS keyring (go-keyring) after discovery.

Load when authoring or changing operator config loading, `config.yaml` / `config.yaml.example`, `make init` / `<bin> init`, secret fields, or go-keyring storage for runtime credentials.

**Related:** shared Make verb `init` (golang-quality shared Make verbs when present); license signing Keychain stays in `setup-go-binary-license` (signing key, not app passwords).

## When to load

- Adding or changing `config.yaml`, `config.yaml.example`, or embedded config templates
- Implementing config path resolution, `LoadConfig`, or Viper/search paths
- Adding `make init` / `<bin> init` that writes user config
- Wiring passwords, API keys, tokens, or master keys into config
- Storing or loading runtime secrets from the OS credential store (go-keyring)
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

**CONSTRAINT:** Config files and committed examples MUST NOT contain literal secrets (API keys, passwords, tokens, master keys, credential-bearing URLs). MUST reference secrets via env placeholders (`${VAR}`) and/or keyring account names (env var names). MUST expand placeholders with a generic walk over string fields (or equivalent whole-document expand). MUST fail closed if any `${...}` remains unresolved after expand when that field is required, or when the host policy rejects unresolved placeholders globally.

- Enforcement: Grep examples for high-entropy literals; read expand + unresolved check; review Stage / no-secrets
- Violation: STOP, replace literals with `${ENV}` or keyring refs, add expand + fail-closed, re-verify

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

**CONSTRAINT:** When the host uses an OS keyring, MUST declare which env names are secrets in the live config (top-level `secrets:` as a list of env names and/or `{env, required}` mappings). MUST query the keyring only for those names, and only after env is empty. MUST skip the keyring entirely when `secrets:` is omitted or empty. MUST NOT hardcode a product-wide env list that always calls `Keyring.Get` on every load. MUST inject `Keyring` via `operatorconfig.Options.Keyring` (or a host options field) for tests; MUST NOT require a process-global mutable keyring as the only test seam.

Implementers MUST use `github.com/behaviorengineering/operatorconfig` (`ResolveConfigPath`, `Load` or host decode + `ResolveSecrets`, `InitUserConfig`, `Options.Keyring`) instead of reimplementing discovery and keyring order.

- Enforcement: Read YAML `secrets:` (or equivalent) and resolve helper; empty list does not call Get; tests inject Keyring
- Violation: STOP, bind secret names from config, skip Get when empty, add injection seam, re-verify

**CONSTRAINT:** Runtime secret resolution MUST try, in order: process environment (including values loaded from a documented local `.env` when the host uses godotenv), then [zalando/go-keyring](https://github.com/zalando/go-keyring) for a **declared** secret (macOS Keychain, Windows Credential Manager, Linux Secret Service), then an optional SOPS secrets file when configured and present (`operatorconfig` default: `~/.config/<app>/secrets.enc.yaml`), then fail closed if the secret is required and still empty. MUST use a stable keyring service id derived from the app name (for example `<app>`) and a stable account/name per secret (the env var name). MUST NOT write runtime passwords into YAML after resolve. **CI and containers:** inject secrets via env only; do not rely on a host keyring inside the container. Container/deploy config templates MUST omit `secrets:` (env injection only); host `serve` templates MAY include `secrets:` for keyring-backed dev. Canonical API and order live in `github.com/behaviorengineering/operatorconfig` `ai-copilots/skills/operatorconfig/SKILL.md`.

Signing private keys for license issuance remain under `setup-go-binary-license` and MAY use a dedicated Keychain item; do not conflate signing-key storage with Redis/API password items.

- Enforcement: Read secret resolve helper; order env → keyring → optional SOPS → error; tests use in-memory Keyring and injectable SecretFile
- Violation: STOP, implement ordered resolve or adopt operatorconfig, re-verify

CORRECT:
```yaml
secrets:
  - REDIS_PASSWORD
  - env: API_TOKEN
    required: true
```
```text
password: "${REDIS_PASSWORD}"
→ os.Getenv("REDIS_PASSWORD")
→ else keyring Get(service=<app>, account=REDIS_PASSWORD) because REDIS_PASSWORD is in secrets:
→ else optional SOPS file for declared names when file exists
→ else error if required
```

PROHIBITED:
```text
// Always Get API_TOKEN even when secrets: is omitted
hardcodedSecrets := []string{"API_TOKEN", "ACCOUNT_ID"}
// Keyring-only on all platforms; Docker/CI cannot start
loadFromKeyringOrPanic("redis")
```

**CONSTRAINT:** Pack docs and shared examples MUST stay product-neutral (`<app>`, `~/.config/<app>/`). Host READMEs MAY name the product and concrete paths. MUST NOT put one host's brand or private layout into this skill as a hard requirement.

- Enforcement: Scan this skill for host brand paths beyond illustrative CORRECT lines
- Violation: STOP, generalize wording, move host specifics to the consumer

## Steps

1. **Name the app dir:** choose `<app>` for XDG (`~/.config/<app>/`) and the override env (`<APP>_CONFIG`).
2. **Discovery:** implement override → user config.yaml → documented fallbacks; unit-test the order.
3. **Init:** embed or ship an example template; wire `make init` / `<bin> init` (create-if-missing, `0600`, refresh example).
4. **Secrets:** YAML placeholders (`${VAR}`) plus a `secrets:` list of env names; generic expand; fail-closed; document env names in `.env.example`.
5. **Keyring (optional runtime):** go-keyring store/load by service+account for **declared** names only; env wins; inject `Options.Keyring` / `NewMemKeyring` in tests.
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
- [ ] **No literal secrets:** Examples and templates use `${VAR}` or keyring refs only
      Method: Grep template for password/api_key literals
      Pass: No real secrets
      Fail: Literal found → STOP, replace
- [ ] **Expand + fail-closed:** Unresolved `${` cannot silently ship into runtime for required secrets
      Method: Unit test with missing env
      Pass: Error or validation failure
      Fail: Empty password accepted when required → STOP, fail closed
- [ ] **Keyring order:** Env beats keyring; containers use env injection only
      Method: Read resolve helper; Docker/CI docs
      Pass: Ordered env → keyring → error; CI path is env-only
      Fail: Keyring-only → STOP, add env path
- [ ] **Declared secrets only:** `secrets:` (or equivalent) lists env names; omitted list means no keyring Get
      Method: Read YAML schema + resolve; test with empty secrets and a boom Keyring
      Pass: No Get when list empty; Get only for listed names
      Fail: Hardcoded always-query list → STOP, bind from config
