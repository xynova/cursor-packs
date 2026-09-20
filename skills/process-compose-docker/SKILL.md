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

## When to load

- Editing `process-compose.yaml`, `pc-up.sh` / `pc-down.sh`, or `docker-compose.yml` used by those scripts
- `make serve` / `make serve-down` (or equivalent) for a multi-namespace process-compose project
- Serve hangs with no output after the up script starts (classic stuck `docker info`)
- Down scripts, compose stop targets, or volume cleanup discussions

## Core constraints

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

## Steps

1. **Classify namespaces** — list which process-compose namespaces need Docker vs host-only binaries.
2. **Up path** — add one timed Docker probe; confirm when the probe fails and optional Docker arms were requested.
3. **Down path** — ensure stop scripts never pass volume-removal flags; keep named volumes in compose.
4. **Docs** — document probe timeout, continue/skip env vars, and that down preserves volumes.
5. **Smoke** — with Docker stopped: up must prompt (or exit cleanly on non-TTY) within the probe timeout; with Docker up: sidecars start; down leaves `docker volume ls` entries intact.

## Pre-completion checklist

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
