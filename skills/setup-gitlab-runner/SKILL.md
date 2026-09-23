---
name: setup-gitlab-runner
description: >-
  Register and run a local GitLab group or project runner (Docker executor on
  macOS or Linux) when shared CI minutes are exhausted or jobs stick in pending.
  Covers gitlab-runner register, install/start as a background service, Run
  untagged jobs, Docker Desktop, and git-clean cache pitfalls. Use when setting
  up a Mac/Linux runner, group runner, docker executor, gitlab-runner run vs
  install, or pending jobs with no runner assigned.
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
- Local Docker runner fails checkout on leftover `.gomodcache` / `.go` paths

---

## Pack membership (already gated)

Portable forge operator practice for any GitLab consumer. MUST NOT name a host
product, private monorepo layout, or one module’s CI job names in this skill.

---

## Discover first

| Fact | How |
|------|-----|
| Host OS | `uname -s` (`Darwin` vs `Linux`) |
| Runner binary | `which gitlab-runner` and `gitlab-runner --version` |
| Docker | `docker info` succeeds (required for docker executor) |
| Scope | Group registration token vs project token (GitLab **Build → Runners**) |
| Config | `~/.gitlab-runner/config.toml` (user-mode) or `/etc/gitlab-runner/config.toml` |
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
**background service** when the host supports it (`gitlab-runner install` then
`start`), not only a foreground `gitlab-runner run` terminal, unless the user
asks for a temporary foreground session.

- Enforcement: `gitlab-runner status` shows the service running; Docker daemon up
- Violation: STOP, install/start or document why foreground-only was requested

CORRECT:
```bash
gitlab-runner install
gitlab-runner start
gitlab-runner status
```

PROHIBITED:
```bash
# Claim "runner is set up" after register while no process/service is running
gitlab-runner register … && exit
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
`GOPATH` outside the project tree. MUST NOT claim a “random” checkout failure
is a compile error.

- Enforcement: Failed job log shows `get_sources` / `Invalid path .../.go` or
  `failed to remove .gomodcache` before any build script
- Violation: STOP, apply exclusions (see [reference.md](reference.md)); re-run

CORRECT:
```yaml
variables:
  GIT_CLEAN_FLAGS: -ffdx -e .gomodcache -e .gocache -e .go
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
jobs meant for docker.

- Enforcement: Only the intended runner is online and active for the group/project
- Violation: STOP, pause extras in GitLab Runners UI or remove unused `[[runners]]`

---

## Steps

1. **Confirm Docker** — `docker info` OK. Pass: daemon reachable. Fail: start Docker Desktop / dockerd first.
2. **Create runner in GitLab** — Group or project → **Build → Runners → New runner** → create → copy registration token (do not echo it into chat).
3. **Register** — `gitlab-runner register --url <instance-root> --token <token>`; executor `docker`; default image matching the project’s usual `image:` (or blank if every job sets it).
4. **Background service** — `gitlab-runner install` then `gitlab-runner start` (or user-requested foreground `run`).
5. **Untagged jobs** — Enable **Run untagged jobs** unless tagged routing was chosen.
6. **Smoke** — Trigger a pipeline (`glab ci run --repo group/project --branch <ref>`). Pass: a job shows the new runner id/name. Fail: check online, untagged, group_runners enabled, Docker up.
7. **Cache pitfall** — If checkout fails on `.go` / `.gomodcache`, apply `GIT_CLEAN_FLAGS` / `GOPATH` fix from [reference.md](reference.md) in the **consumer** CI config (not this pack).

---

## Pre-completion checklist

- [ ] **Executor matches CI:** docker when jobs use `image:`
      Method: Compare executor in `config.toml` to job `image:`
      Pass: docker for image-based jobs
      Fail: STOP, re-register or rewrite CI with user approval
- [ ] **Runner online and not foreground-only (unless requested):**
      Method: `gitlab-runner status` / GitLab runner `online=true`
      Pass: Service running; Docker up
      Fail: STOP, install/start or start Docker
- [ ] **Untagged or tags aligned:**
      Method: Runner `run_untagged` or job `tags:` match
      Pass: Pending jobs get assigned
      Fail: STOP, enable untagged or add tags
- [ ] **No secrets in chat/commits:**
      Method: Scan for `glrt-` and config tokens
      Pass: None present
      Fail: STOP, redact and rotate
- [ ] **Smoke pipeline assigned to this runner:**
      Method: Job log header shows the runner name/id
      Pass: At least one job ran on it
      Fail: STOP, fix eligibility before claiming done
