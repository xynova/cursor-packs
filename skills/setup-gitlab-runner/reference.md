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

| Mode | Commands | When |
|------|----------|------|
| Service | `gitlab-runner install` then `gitlab-runner start` | Normal; survives terminal close |
| Status | `gitlab-runner status` | Confirm service |
| Stop | `gitlab-runner stop` | Maintenance |
| Foreground | `gitlab-runner run` | Temporary debug only |

Docker Desktop (or dockerd) MUST be running while docker-executor jobs can be scheduled.

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

## Docker Desktop checkout / Go caches

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

# Go job base
variables:
  GOPATH: /go
  GOMODCACHE: $CI_PROJECT_DIR/.gomodcache
  GOCACHE: $CI_PROJECT_DIR/.gocache
```

Also pause older shell runners on the same machine so they do not steal jobs.

---

## Verify assignment

Job log header should name the local runner, for example:

```text
Running with gitlab-runner …
  on <runner-name> <short-token>, system ID: …
```

If jobs stay pending: online status, untagged flag, `group_runners_enabled` on the project, Docker daemon, and whether shared runners are the only ones listed (minutes may still queue SaaS runners that never start).
