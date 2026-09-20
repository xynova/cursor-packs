# Operator config patterns

LOAD-WHEN: implementing config discovery, init, `${VAR}` expand, or Keychain-backed runtime secrets per `operator-config` skill.

## Discovery order

### Pattern: resolveConfigPath

```go
// Order: override → user XDG file → cwd fallbacks.
func resolveConfigPath(override string) (string, error) {
	if p := strings.TrimSpace(override); p != "" {
		return p, nil
	}
	if user, err := UserConfigFilePath(); err == nil {
		if _, err := os.Stat(user); err == nil {
			return user, nil
		}
	}
	for _, p := range []string{"config.yaml", "config/config.yaml"} {
		if _, err := os.Stat(p); err == nil {
			return p, nil
		}
	}
	return "", fmt.Errorf("config.yaml not found (run: make init)")
}
```

**Rules:**

- MUST resolve override from `--config` or `<APP>_CONFIG` before any search.
- MUST probe `UserConfigFilePath()` (`$XDG_CONFIG_HOME/<app>/config.yaml` or `~/.config/<app>/config.yaml`).
- MUST NOT treat cwd `config.yaml` as the only supported operator path.

## Init

### Pattern: create-if-missing user config

```go
// Live file 0600; example may be 0644 and refreshed every init.
func InitUserConfig(force bool) error {
	dir, err := UserConfigDir()
	if err != nil {
		return err
	}
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return err
	}
	live := filepath.Join(dir, "config.yaml")
	if force || !fileExists(live) {
		if err := os.WriteFile(live, templateYAML, 0o600); err != nil {
			return err
		}
	}
	return os.WriteFile(filepath.Join(dir, "config.yaml.example"), templateYAML, 0o644)
}
```

**Rules:**

- MUST expose `make init` and/or `<bin> init`.
- MUST NOT overwrite live config without `force`.
- MUST keep examples free of literal secrets.

## Secrets

### Pattern: placeholder + reflective expand

```yaml
# config.yaml (no literals)
providers:
  redis:
    password: "${REDIS_PASSWORD}"
```

```go
// After unmarshal: expand all strings; error if "${" remains when policy is fail-closed.
expandAllStrings(reflect.ValueOf(cfg))
if unresolved := collectUnresolved(cfg); len(unresolved) > 0 {
	return fmt.Errorf("unresolved env placeholders: %s", strings.Join(unresolved, ", "))
}
```

**Rules:**

- MUST NOT maintain a per-field expand checklist as the only expand path.
- MUST document env names in `.env.example` with empty or dummy placeholders.
- NEVER commit real keys.

### Pattern: env then Keychain

```go
func ResolveSecret(envName string) (string, error) {
	if v := strings.TrimSpace(os.Getenv(envName)); v != "" {
		return v, nil
	}
	if keychain.Available() {
		if v, err := keychain.Load(serviceApp, envName); err == nil && strings.TrimSpace(v) != "" {
			return v, nil
		}
	}
	return "", fmt.Errorf("secret %q not set in environment or Keychain", envName)
}
```

**Rules:**

- MUST prefer process env over Keychain so CI and non-interactive hosts work.
- MUST use stable service id (`<app>`) and account id (usually the env var name).
- MUST provide a non-Darwin stub (`Available() == false`).
- MUST NOT dump resolved secrets back into YAML on disk.
- License signing private keys use `setup-go-binary-license`, not this password bag.

PROHIBITED:
```go
// Writes the password into the user config file after first run
cfg.Redis.Password = resolved
_ = WriteUserConfig(cfg)
```
