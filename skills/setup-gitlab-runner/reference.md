# Setup GitLab runner — reference

LOAD-WHEN: operating `setup-gitlab-runner`; registering, verifying, or debugging
local GitLab runners and Docker Desktop checkout failures.

---

## Register (interactive)

```bash
# Instance root only — not a group/project path
gitlab-runner register --url https://gitlab.com --token "$GITLAB_RUNNER_REGISTRATION_TOKEN"

# Prompts (typical):
# - GitLab instance URL: https://gitlab.com/
# - Runner name: descriptive host label
# - Executor: docker
# - Default Docker image: match project CI (example golang:1.27-bookworm) or blank
```

User-mode config (Homebrew / no sudo): `~/.gitlab-runner/config.toml`

System-mode: `/etc/gitlab-runner/config.toml` (often requires sudo)

---

## Background vs foreground

### Darwin + Homebrew (preferred on Mac)

```bash
brew services start gitlab-runner
brew services stop gitlab-runner
brew services restart gitlab-runner
brew services list | grep gitlab-runner
pgrep -lf 'gitlab-runner run'   # must be exactly one process
```

Config still lives at `~/.gitlab-runner/config.toml`. Docker Desktop MUST be
running while docker-executor jobs can be scheduled.

### Other hosts (no Homebrew)

| Mode | Commands | When |
|------|----------|------|
| Service | `gitlab-runner install` then `gitlab-runner start` | Normal; survives terminal close |
| Status | `gitlab-runner status` | Confirm service |
| Stop | `gitlab-runner stop` | Maintenance |
| Foreground | `gitlab-runner run` | Temporary debug only |

### One process only

Two managers (for example `brew services` plus a manual `gitlab-runner run`, or
two LaunchAgents) share builds directories and cause:

```text
could not lock config file .../.gitlab-runner.ext.conf: File exists
error adding trust anchors from file: .../CI_SERVER_TLS_CA_FILE
```

Jobs may also show empty logs while GitLab still says “running”
(`server_timeout_running` after ~1h).

Fix: stop extras, keep a single `brew services` (or single `run`), pause unused
runners in GitLab, optionally set `limit = 0` on unused `[[runners]]` entries.

If a stale lock remains, remove **only** the lock file in
`pre_get_sources_script` (never delete the whole `.tmp` dir; that removes
`CI_SERVER_TLS_CA_FILE`):

```toml
pre_get_sources_script = """
if [ -n "${CI_PROJECT_DIR:-}" ]; then
  rm -f "${CI_PROJECT_DIR}.tmp/.gitlab-runner.ext.conf.lock" 2>/dev/null || true
fi
"""
```

---

## Docker pull hangs on Desktop

Symptom: job log stops at `Using effective pull policy of [always]` / Pulling
image, then fails with `server_timeout_running`.

```toml
[runners.docker]
  pull_policy = ["if-not-present"]
```

Then `brew services restart gitlab-runner` (or restart the single `run`).

---

## Untagged jobs vs YAML tags

| Goal | Runner setting | CI YAML |
|------|----------------|---------|
| Replace shared minutes | **Run untagged jobs** = on | No `tags:` required |
| Pin jobs to this host | Tagged-only + tag list | Matching `tags:` on those jobs |

Default recommendation: untagged on, no YAML tag sweep.

---

## glab without a GitLab remote

Monorepo roots often have no `origin`. Point glab at the project:

```bash
glab runner list --repo group/project
glab ci run --repo group/project --branch main
glab api "runners/<id>"
```

Group runners may not appear in the project’s shared-runner table; fetch by runner id or `groups/<group>/runners?type=group_type`.

---

## Docker Desktop checkout / Go caches / SAST

Symptom in job log (before any compile script):

```text
fatal: Invalid path '/builds/.../.go': No such file or directory
warning: failed to remove .gomodcache/: Directory not empty
ERROR: Job failed: exit code 1   # during get_sources
```

Consumer CI fix (product repo, not this pack):

```yaml
# .gitlab-ci.yml (pipeline-wide)
variables:
  GIT_CLEAN_FLAGS: -ffdx -e .gomodcache -e .gocache -e .go
  SAST_EXCLUDED_PATHS: "spec, test, tests, tmp, .gomodcache, .gocache, .go"
  SECRET_DETECTION_EXCLUDED_PATHS: ".gomodcache, .gocache, .go"

# Go job base
variables:
  GOPATH: /go
  GOMODCACHE: $CI_PROJECT_DIR/.gomodcache
  GOCACHE: $CI_PROJECT_DIR/.gocache
```

Also add a `.semgrepignore` with `.gomodcache/`, `.gocache/`, `.go/` so Semgrep
does not scan module caches left by `GIT_CLEAN_FLAGS`.

Also pause older shell runners on the same machine so they do not steal jobs.

---

## Verify assignment

Job log header should name the local runner, for example:

```text
Running with gitlab-runner …
  on <runner-name> <short-token>, system ID: …
```

If jobs stay pending: online status, untagged flag, `group_runners_enabled` on the project, Docker daemon, single runner process, and whether shared runners are the only ones listed (minutes may still queue SaaS runners that never start).
