---
name: process-compose-docker
description: >-
  Process-compose stacks that mix host processes with Docker sidecars: timed
  Docker preflight on up, confirm when the daemon is down, and never remove
  named volumes on down. Use when editing pc-up/pc-down, process-compose.yaml,
  docker-compose.yml for observability sidecars, make serve/serve-down, or when
  serve hangs on docker info. Triggers: process-compose, docker compose, Phoenix,
  HyperDX, named volumes, serve-down, docker preflight.
---

# Process-compose + Docker sidecars

**Moral:** Optional Docker arms must fail fast and ask before skipping. Stopping the stack must never wipe durable volumes.

Load when authoring or changing process-compose launchers that start Docker containers (observability, databases, collectors) beside host binaries.

**Related:** shared Make verb names (`serve` / `serve-down`) live in golang-quality CONSTRAINT 21.

## When to load

- Editing `process-compose.yaml`, `pc-up.sh` / `pc-down.sh`, or `docker-compose.yml` used by those scripts
- `make serve` / `make serve-down` for a multi-namespace process-compose project
- Serve hangs with no output after the up script starts (classic stuck `docker info`)
- Down scripts, compose stop targets, or volume cleanup discussions
- `Taskfile.yml` `serve` / `serve-down`, `scripts/serve-up.sh`, or serve hangs while process-compose shows Running with HEALTH `-` and no listener

## Applicability gate

**CONSTRAINT:** Prebuild and HTTP readiness constraints below apply only when the repository has `process-compose.yaml` or `scripts/pc-up.sh` AND exposes `serve` / `serve-down` (Taskfile or Makefile). MUST NOT apply them to library Makefiles that define `serve` unused, or Taskfiles without a process-compose stack.

- Enforcement: Confirm both compose (or pc-up) and serve verbs exist before editing serve scripts
- Violation: STOP, skip prebuild rules for that repo

## Core constraints

**CONSTRAINT:** When a Taskfile or Makefile (or documented operator entrypoint) starts or stops a process-compose local stack, MUST name those verbs `serve` and `serve-down`. MUST NOT expose the long-running stack only as `dev` / `dev-down` on a new or rewritten Taskfile or Makefile. MAY keep `dev` / `dev-down` as thin aliases that invoke `serve` / `serve-down` during migration. Help lines MUST be one short product-neutral or host-specific description (host MAY name itself; pack docs MUST NOT require a brand). MUST NOT put Make `$(VAR)` in `##` (golang-quality C20).

- Enforcement: Read Makefile `.PHONY` / `##` lines and pc-up/pc-down wiring; up/down are `serve` / `serve-down`
- Violation: STOP, add or rename to `serve` / `serve-down`, optionally alias old names, re-verify

CORRECT:
```makefile
serve: ## process-compose TUI; rebuilds on file changes
	./scripts/pc-up.sh

serve-down: ## Stop this process-compose project
	./scripts/pc-down.sh
```

PROHIBITED:
```makefile
dev: ## Start local stack
	process-compose up
# no serve target
```

**CONSTRAINT:** Up scripts that optionally start Docker containers MUST probe the daemon with a bounded timeout before `docker compose up` / process start. MUST NOT call bare `docker info` (or equivalent) without a timeout.

- MUST: use `timeout` / `gtimeout`, or a portable background-kill probe, defaulting to a few seconds (for example 3s); allow an env override for the wait
- MUST: run the probe at most once per up invocation and reuse the result for every Docker-backed namespace
- MUST NOT: block indefinitely when the Docker CLI exists but the daemon is stopped or still starting

Enforcement: grep up scripts for `docker info` / `docker compose`; confirm a timeout wrapper or probe helper surrounds daemon checks
Violation: STOP, add timed probe, re-verify

CORRECT:
```bash
# 3s probe (timeout, gtimeout, or background + kill)
if docker_ok; then
  NAMESPACES+=(obs hyperdx)
fi
```

PROHIBITED:
```bash
if docker info >/dev/null 2>&1; then
  NAMESPACES+=(obs)
fi
```

**CONSTRAINT:** When Docker is required for optional containers and the timed probe fails, MUST tell the operator the daemon is down and ask whether to continue without those containers before starting the rest of the stack.

- MUST: name which containers or namespaces will be skipped
- MUST: default the confirm to no (abort) unless the operator explicitly continues
- MUST: support a non-interactive escape hatch (for example `*_DOCKER_CONTINUE=1` or explicit `*_PHOENIX=0` / skip flags) when stdin is not a TTY
- MUST NOT: silently skip Docker namespaces on an interactive TTY without a confirm
- MUST NOT: hang waiting for input when stdin is not a TTY; exit with a clear message instead

Enforcement: up script shows a prompt or documented continue env; CI/non-TTY path exits or honors continue/skip flags
Violation: STOP, add confirm + non-TTY policy, re-verify

CORRECT:
```text
Docker is down, so Phoenix and HyperDX cannot start.
Continue without Phoenix and HyperDX? [y/N]
```

PROHIBITED:
```text
WARN: Docker not available; Phoenix skipped.
# (interactive, no question, stack continues anyway)
```

**CONSTRAINT:** Down / stop paths MUST stop process-compose and Docker containers without removing named volumes or anonymous volume data.

- MUST: use `process-compose down` and/or `docker compose stop` / `docker compose down` **without** `-v` / `--volumes`
- MUST NOT: pass `-v`, `--volumes`, `--rmi`, or run `docker volume rm` / `docker volume prune` as part of a normal down / serve-down target
- MUST NOT: document volume wipe as the default stop recipe; destructive cleanup belongs in a separately named, explicitly requested command

Enforcement: grep down scripts and Makefile stop targets for `-v`, `--volumes`, `volume rm`, `volume prune`
Violation: STOP, remove volume destruction from the default down path, re-verify

CORRECT:
```bash
process-compose down -U -u "$SOCK"
# or: docker compose stop
# or: docker compose down    # no -v
```

PROHIBITED:
```bash
docker compose down -v
docker volume rm project_phoenix_data
```

**CONSTRAINT:** Durable observability or datastore state for local stacks MUST live on named Docker volumes (or an explicit host bind the operator owns), not only the container writable layer.

- MUST: declare named volumes in compose for working dirs / database paths that should survive restart
- MUST NOT: rely on container filesystem alone for traces/logs that operators expect to keep across `serve-down` / `serve`

Enforcement: compose file lists named volumes for sidecar data paths
Violation: STOP, add named volumes or document ephemeral-by-design with user agreement

CORRECT:
```yaml
volumes:
  - phoenix_data:/data
  - hyperdx_ch_data:/var/lib/clickhouse
```

PROHIBITED:
```yaml
# no volumes: — every down loses local trace history with no warning
services:
  phoenix:
    image: arizephoenix/phoenix:latest
```

**CONSTRAINT:** When the applicability gate passes, each Go process-compose service MUST be compiled to a named binary before `process-compose up` (in the up script or the first `serve` task command). The process-compose command MUST `exec` that binary to listen. MUST NOT use `go run` or `wgo run` as the first listen process.

- MUST: run `go build -o` (or equivalent) into a stable path (for example `tmp/my-daemon`) before the TUI starts
- MUST skip `go build` and optional codegen on the prebuild script when the named binary exists, is executable, and is newer than watched sources (source suffixes plus `go.mod` / `go.sum`)
- MUST still `go build -o` when missing or stale. The Go compile cache applies only on that rebuild
- MUST NOT treat "always invoke `go build`" as required on every `serve`
- MUST NOT use `go run` / `wgo run` as listen
- MAY honor a force-rebuild env (example name `SERVE_FORCE_BUILD=1`; hosts MAY pick another name)
- Codegen (example: template generate) MUST run only when generated files are missing or older than their inputs; MUST NOT run codegen on every up
- MUST: watchers (`wgo`, `air`, and similar) MAY rebuild the same `-o` path then re-exec; first start MUST skip rebuild when the binary is newer than watched sources
- MUST NOT: block readiness on `go tool link` inside the supervised process tree
- Enforcement: `rg 'go run|wgo run' process-compose.yaml scripts/serve*.sh`; listen path is `exec` of a prebuilt binary
- Violation: STOP, add serve-build script + exec wrapper, re-verify

CORRECT:
```bash
# serve-build-api.sh
if bin executable and no watched source -newer bin; then
  echo "serve: using existing tmp/api" >&2
  exit 0
fi
go build -o tmp/api ./cmd

# serve-up.sh (before process-compose up)
./scripts/serve-build-api.sh

# process-compose.yaml
command: ./scripts/serve-process.sh ./scripts/serve-api.sh
# serve-api.sh ends with: exec "${root}/tmp/api" serve
```

PROHIBITED:
```bash
# serve-up always:
go build -o tmp/api ./cmd
# and always: templ generate
# GOCACHE is not a skip
```

PROHIBITED:
```yaml
command: go tool wgo run ./cmd/my-daemon
# TUI shows Running while go tool link runs; HEALTH stays -
```

**CONSTRAINT:** When a watcher rebuilds a process-compose service, it MUST start from the narrowest directory containing the watched source, then add only the other source roots required by that service. MUST NOT start the watcher from a repository root that contains unrelated content, generated output, vendored trees, or workspace artifacts. MUST verify whether watcher flags restrict the root or add another root before relying on them.

- MUST: use the watcher's working-directory option or `cd` into the primary source directory before starting it
- MUST: use explicit additional roots for source directories outside that working directory
- MUST: watch only relevant source suffixes (`.go`, `.templ`, or the equivalent)
- MUST NOT: treat `-dir` or `-root` as an exclusion mechanism without checking the watcher's documented semantics and startup output
- Enforcement: inspect the watcher command and startup output; confirm it does not enumerate unrelated repository trees before the first service exec
- Violation: STOP, narrow the working directory and explicit roots, re-verify startup

CORRECT:
```bash
cd cmd/my-daemon
exec wgo -file .go -root internal/my-daemon ./scripts/serve-inner.sh
```

PROHIBITED:
```bash
cd .
exec wgo -file .go ./scripts/serve-inner.sh
# Watches content/, tmp/, and unrelated workspace trees before listening
```

**CONSTRAINT:** When the applicability gate passes, every HTTP listen process in process-compose MUST expose a cheap readiness URL (no auth, no template render, no DB when avoidable) and MUST set `readiness_probe` to `curl -sf` that URL. Non-Go HTTP binaries (for example a static site server) skip compile and still get a probe.

- MUST: mirror probe timing (`initial_delay_seconds`, `period_seconds`, `timeout_seconds`) across services in the same stack
- MUST NOT: rely on TUI Running alone; `-` HEALTH is not proof the port is listening
- Enforcement: count `readiness_probe` blocks vs HTTP processes in `process-compose.yaml`
- Violation: STOP, add `/readyz` or `/health` handler and probe, re-verify

CORRECT:
```yaml
readiness_probe:
  exec:
    command: curl -sf http://127.0.0.1:8080/readyz
  initial_delay_seconds: 2
  period_seconds: 2
```

PROHIBITED:
```yaml
# HTTP API process with no readiness_probe — HEALTH never becomes Ready
```

## Steps

1. **Classify namespaces** — list which process-compose namespaces need Docker vs host-only binaries.
2. **Up path** — add one timed Docker probe; confirm when the probe fails and optional Docker arms were requested.
3. **Down path** — ensure stop scripts never pass volume-removal flags; keep named volumes in compose.
4. **Docs** — document probe timeout, continue/skip env vars, and that down preserves volumes.
5. **Smoke** — with Docker stopped: up must prompt (or exit cleanly on non-TTY) within the probe timeout; with Docker up: sidecars start; down leaves `docker volume ls` entries intact.

## Pre-completion checklist

- [ ] **Serve verbs:** Taskfile or Makefile (if present) exposes `serve` / `serve-down` for the process-compose stack
      Method: `rg -n 'serve|serve-down|dev-down' Taskfile.yml Makefile`
      Pass: `serve` and `serve-down` exist; `dev` only as optional alias
      Fail: Stack only under `dev` → STOP, rename
- [ ] **Timed probe:** Up script cannot hang forever on `docker info`
      Method: Read probe helper; confirm timeout or kill path
      Pass: Bounded wait + reuse once per run
      Fail: Bare `docker info` only → STOP, wrap it
- [ ] **Confirm or escape:** Interactive down-daemon path asks; non-TTY has continue/skip flags
      Method: Trace fail branch of probe
      Pass: Prompt or documented non-TTY exit/continue
      Fail: Silent skip on TTY → STOP, add confirm
- [ ] **Down preserves volumes:** No `-v` / `volume rm` on default down
      Method: `rg -n 'down -v|--volumes|volume rm|volume prune' scripts Makefile`
      Pass: No matches on default stop path
      Fail: STOP, remove destruction from default down
- [ ] **Named volumes:** Sidecar data paths use named volumes when durability matters
      Method: Read compose `volumes:` for each data mount
      Pass: Named volumes present for durable paths
      Fail: STOP, add volumes or get explicit ephemeral approval
- [ ] **Go prebuild:** Go services build before `process-compose up` and exec the binary
      Method: `rg -n 'go run|wgo run' process-compose.yaml scripts/serve*.sh` when gate applies
      Pass: No listen-process `go run` / `wgo run`; `serve-build` + `exec` present
      Fail: STOP, add prebuild script and exec wrapper
- [ ] **Skip if fresh:** Prebuild scripts skip compile when the binary is newer than watched sources
      Method: compare `stat` mtime of `tmp/<name>` before and after a second `serve-build`
      Pass: mtime equal and reuse stderr
      Fail: STOP, add timestamp check
- [ ] **Watcher root:** File watchers start from narrow source roots
      Method: Read the watcher command and its startup watch list
      Pass: No unrelated content, generated, vendor, or workspace trees are enumerated before the first service exec
      Fail: STOP, narrow the watcher working directory and explicit additional roots
- [ ] **HTTP readiness_probe:** Every HTTP process has `readiness_probe`
      Method: Count HTTP processes vs `readiness_probe` in `process-compose.yaml`
      Pass: Each HTTP row has a probe URL that matches listen address
      Fail: STOP, add handler and probe
