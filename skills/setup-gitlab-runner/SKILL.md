---
name: setup-gitlab-runner
description: >-
  Register and run a local GitLab group or project runner (Docker executor on
  macOS or Linux) when shared CI minutes are exhausted or jobs stick in pending.
  Covers gitlab-runner register, Homebrew brew services start on Mac,
  install/start elsewhere, Run untagged jobs, Docker Desktop pull hangs, and
  git-clean cache pitfalls. Use when setting up a Mac/Linux runner, group
  runner, docker executor, brew services gitlab-runner, or pending jobs with
  no runner assigned.
---

# Setup GitLab runner

Register a **local** GitLab runner so project pipelines can run without SaaS
shared minutes. Prefer the **docker** executor when jobs declare `image:`.

**Companion notes:** [reference.md](reference.md)

**Related:** `prepare-go-forge` (host forge settings and CI stubs). This skill
does **not** replace forge prepare; it only owns the runner machine side.

---

## When to load

- Shared CI minutes are exhausted or jobs stay **pending** with no runner
- User asks to register a group or project runner on a Mac or Linux host
- Choosing executor (`docker` vs `shell`), default image, or background service
- Homebrew Mac: start/stop/restart via `brew services`
- Local Docker runner fails checkout on leftover `.gomodcache` / `.go` paths,
  or jobs hang forever on image pull

---

## Pack membership (already gated)

Portable forge operator practice for any GitLab consumer. MUST NOT name a host
product, private monorepo layout, or one module’s CI job names in this skill.

---

## Discover first

| Fact | How |
|------|-----|
| Host OS | `uname -s` (`Darwin` vs `Linux`) |
| Install path | Darwin + Homebrew: `brew list gitlab-runner`; else binary from packages |
| Runner binary | `which gitlab-runner` and `gitlab-runner --version` |
| Service | Darwin: `brew services list \| grep gitlab-runner`; else `gitlab-runner status` |
| Process count | `pgrep -lf 'gitlab-runner run'` MUST show **one** process |
| Docker | `docker info` succeeds (required for docker executor) |
| Scope | Group registration token vs project token (GitLab **Build → Runners**) |
| Config | `~/.gitlab-runner/config.toml` (user-mode / Homebrew) or `/etc/gitlab-runner/config.toml` |
| Project remote | `git remote get-url origin`; if missing (monorepo root), use `glab --repo group/project` |

---

## Core constraints

**CONSTRAINT:** When CI jobs use `image:`, agents MUST register the **docker**
executor. MUST NOT choose `shell` for those pipelines unless the user
explicitly accepts rewriting CI to host-native tools.

- Enforcement: Read a representative job `image:` / `.go-base` (or equivalent); match executor
- Violation: STOP, switch to docker or get explicit shell approval

CORRECT:
```text
Jobs: image: golang:1.27-bookworm
→ executor: docker; default image golang:1.27-bookworm (or leave blank if every job sets image)
```

PROHIBITED:
```text
Jobs: image: golang:1.27-bookworm
→ executor: shell on macOS "because the machine is a Mac"
```

**CONSTRAINT:** Registration URL MUST be the GitLab instance root
(`https://gitlab.com/` or the self-managed base URL). MUST NOT use a group or
project path as `--url` (that yields 422 / verify failures).

- Enforcement: `gitlab-runner verify` reports valid after register
- Violation: STOP, re-register with instance URL only

CORRECT:
```bash
gitlab-runner register --url https://gitlab.com --token glrt-…
# interactive URL prompt: https://gitlab.com/
```

PROHIBITED:
```bash
gitlab-runner register --url https://gitlab.com/my-group --token glrt-…
```

**CONSTRAINT:** Agents MUST NOT print, commit, or paste registration tokens
(`glrt-…`) or `config.toml` runner tokens into chat, PRs, or docs. MUST treat
a token that appeared in a screenshot or log as compromised and tell the user
to rotate it in GitLab.

- Enforcement: Scan draft replies and commits for `glrt-` / `token = "`
- Violation: STOP, redact, rotate, re-verify

**CONSTRAINT:** After register, agents MUST leave the runner running as a
**background service**, not only a foreground `gitlab-runner run` terminal,
unless the user asks for a temporary foreground session.

On **Darwin with Homebrew**, MUST use:

```bash
brew services start gitlab-runner
brew services list | grep gitlab-runner
```

Stop / restart:

```bash
brew services stop gitlab-runner
brew services restart gitlab-runner
```

On hosts **without** Homebrew, MUST use `gitlab-runner install` then
`gitlab-runner start` (system or user service). MUST NOT tell Mac Homebrew
users that `gitlab-runner install` is the primary path when `brew services`
is available.

- Enforcement: Exactly one `gitlab-runner run` process; Darwin shows brew service `started`; Docker daemon up
- Violation: STOP, start the correct service or document why foreground-only was requested

CORRECT:
```bash
# Darwin + Homebrew
brew services start gitlab-runner
pgrep -lf 'gitlab-runner run'   # exactly one line
```

PROHIBITED:
```bash
# Claim "runner is set up" after register while no process/service is running
gitlab-runner register … && exit
# Or: brew services start AND a second terminal `gitlab-runner run`
```

**CONSTRAINT:** Agents MUST run **exactly one** runner manager process for a
given `config.toml`. MUST NOT leave both `brew services` and a manual
`gitlab-runner run` (or two LaunchAgents) active. Dual processes share the
same Docker builds path and cause checkout lock / TLS CA failures.

- Enforcement: `pgrep -lf 'gitlab-runner run'` count is 1; pause unused runners in GitLab
- Violation: STOP, stop extras (`brew services stop` / `pkill`), keep one

CORRECT:
```text
One brew service → one process → one docker runner online
Shell runner in same config.toml: paused in GitLab or limit = 0
```

PROHIBITED:
```text
brew services start gitlab-runner
# plus leftover LaunchAgent / second `gitlab-runner run`
→ .gitlab-runner.ext.conf lock / empty job logs / hour timeouts
```

**CONSTRAINT:** For Docker Desktop Mac runners, agents MUST set docker
`pull_policy = ["if-not-present"]` in `config.toml` when image pulls hang
with `pull_policy` of `always` (jobs sit in prepare_executor until
`server_timeout_running`). MUST NOT leave `always` if local images already
exist and pulls stall.

- Enforcement: Job log stops at "Pulling docker image …" for many minutes; config has if-not-present
- Violation: STOP, set pull_policy, restart brew service, retry

CORRECT:
```toml
[runners.docker]
  pull_policy = ["if-not-present"]
```

PROHIBITED:
```toml
# Default always on flaky Docker Desktop network → lint times out at 1h with no script output
```

**CONSTRAINT:** For a runner meant to replace shared minutes, agents MUST
enable **Run untagged jobs** in GitLab (UI or API) unless the user requires
tag routing. MUST NOT add `tags:` to every CI job by default.

- Enforcement: Runner detail shows `run_untagged: true`, or jobs without tags get assigned
- Violation: STOP, enable untagged (or add matching tags only when user chose tagged routing)

CORRECT:
```text
Runner: run_untagged=true, optional tags for description only
Jobs: no tags: required
```

PROHIBITED:
```text
Runner: tagged-only with tags macos,local
CI still has no tags: → jobs stay pending forever
```

**CONSTRAINT:** On Docker Desktop (especially macOS), when Go (or similar)
caches live under `$CI_PROJECT_DIR`, agents MUST keep checkout from deleting
them: set pipeline `GIT_CLEAN_FLAGS` to exclude cache dirs and prefer
`GOPATH` outside the project tree. MUST also exclude those dirs from SAST
(`.semgrepignore` / `SAST_EXCLUDED_PATHS`) so Semgrep does not scan module
caches. MUST NOT claim a “random” checkout failure is a compile error.

- Enforcement: Failed job log shows `get_sources` / `Invalid path .../.go` or
  `failed to remove .gomodcache` before any build script; or Semgrep scans `.gomodcache`
- Violation: STOP, apply exclusions (see [reference.md](reference.md)); re-run

CORRECT:
```yaml
variables:
  GIT_CLEAN_FLAGS: -ffdx -e .gomodcache -e .gocache -e .go
  SAST_EXCLUDED_PATHS: "spec, test, tests, tmp, .gomodcache, .gocache, .go"
# .go-base / equivalent:
# GOPATH: /go
# GOMODCACHE: $CI_PROJECT_DIR/.gomodcache
# GOCACHE: $CI_PROJECT_DIR/.gocache
```

PROHIBITED:
```yaml
# GOPATH under $CI_PROJECT_DIR/.go with default git clean on Docker Desktop Mac
# → next job dies in get_sources; blame go vet
```

**CONSTRAINT:** Agents MUST pause or disable competing local runners (for
example an older shell runner in the same `config.toml`) so they do not steal
jobs meant for docker. Prefer GitLab pause plus `limit = 0` on the unused
`[[runners]]` entry.

- Enforcement: Only the intended runner is online and active for the group/project
- Violation: STOP, pause extras in GitLab Runners UI or set limit = 0

---

## Steps

1. **Confirm Docker** — `docker info` OK. Pass: daemon reachable. Fail: start Docker Desktop / dockerd first.
2. **Create runner in GitLab** — Group or project → **Build → Runners → New runner** → create → copy registration token (do not echo it into chat).
3. **Register** — `gitlab-runner register --url <instance-root> --token <token>`; executor `docker`; default image matching the project’s usual `image:` (or blank if every job sets it).
4. **Docker pull policy (Mac)** — In `~/.gitlab-runner/config.toml` under `[runners.docker]`, set `pull_policy = ["if-not-present"]` when Desktop pulls hang.
5. **Background service** — Darwin+Homebrew: `brew services start gitlab-runner`. Else: `gitlab-runner install` then `start`. Confirm **one** process via `pgrep -lf 'gitlab-runner run'`.
6. **Untagged jobs** — Enable **Run untagged jobs** unless tagged routing was chosen. Pause competing shell runners.
7. **Smoke** — Trigger a pipeline (`glab ci run --repo group/project --branch <ref>`). Pass: a job shows the new runner id/name and a non-empty log past prepare_executor. Fail: check online, untagged, group_runners enabled, Docker up, single process.
8. **Cache / SAST pitfall** — If checkout fails on `.go` / `.gomodcache`, or Semgrep scans caches, apply exclusions from [reference.md](reference.md) in the **consumer** CI config (not this pack).

---

## Pre-completion checklist

- [ ] **Executor matches CI:** docker when jobs use `image:`
      Method: Compare executor in `config.toml` to job `image:`
      Pass: docker for image-based jobs
      Fail: STOP, re-register or rewrite CI with user approval
- [ ] **Single background service (brew on Darwin):**
      Method: Darwin: `brew services list` + `pgrep -lf 'gitlab-runner run'`; else `gitlab-runner status`
      Pass: Service started; exactly one process; Docker up
      Fail: STOP, start brew/service or kill duplicates
- [ ] **Untagged or tags aligned:**
      Method: Runner `run_untagged` or job `tags:` match
      Pass: Pending jobs get assigned
      Fail: STOP, enable untagged or add tags
- [ ] **No secrets in chat/commits:**
      Method: Scan for `glrt-` and config tokens
      Pass: None present
      Fail: STOP, redact and rotate
- [ ] **Smoke pipeline assigned to this runner:**
      Method: Job log header shows the runner name/id; log progresses past image pull
      Pass: At least one job ran on it
      Fail: STOP, fix eligibility / pull_policy before claiming done
