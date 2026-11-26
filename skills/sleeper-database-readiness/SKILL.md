---
name: sleeper-database-readiness
description: >-
  Keep scale-to-zero / suspend-on-idle databases (Neon, similar Postgres)
  asleep during local serve: cheap /readyz that does not query the store,
  connection pools that close idle conns before the sleeper's idle window,
  wake only on real application traffic. Use when editing readyz, healthz,
  pgxpool, process-compose probes, Neon compute hours, CU-hours, idle
  database, scale-to-zero, or a probe that Ping()s a catalog pool.
---

# Sleeper database readiness

**Moral:** Ready means the process will accept work that may wake the store. It does not mean the store is already hot.

Related: skill `process-compose-docker` owns cheap HTTP probes for process-compose stacks. This skill owns the sleeper-store case of that probe and of the connection pool.

## When to load

Load when any of these is true:

- Editing `/readyz`, `/healthz`, or a process-compose `readiness_probe`
- Opening a pgx / SQL pool against a database that suspends on idle
- Diagnose compute-hour, CU-hour, or "exceeded the quota" spend while a local stack is up
- The user names Neon, scale-to-zero, sleeper database, or idle catalog

## Applicability gate

Before changing a probe or pool, complete this gate in working memory:

```text
Candidate: [process, probe URL, or pool]
Backing store suspends after idle (scale-to-zero): YES: [quote] / NO
Decision: apply sleeper constraints | skip (always-on local store)
```

IF NO (local always-on Postgres, Docker Postgres with no suspend) → this skill's pool idle and no-probe-query constraints do not apply. Cheap process-compose probes still follow `process-compose-docker`.

IF YES → apply every constraint below.

## Core constraints

**CONSTRAINT:** Liveness and readiness HTTP handlers MUST NOT query a sleeper database. MUST NOT call `Ping`, `SELECT 1`, or equivalent on that pool from `/readyz` or `/healthz`. MUST NOT point a process-compose `readiness_probe` at a URL that performs that query.

- MUST: `/readyz` (or the probed URL) return success when the process is listening and will accept work
- MUST NOT: treat "database is already awake" as Ready
- Enforcement: grep the probed handler for `Ping`, `Query`, `Exec` against the sleeper pool; grep `process-compose.yaml` probe URLs and read those handlers
- Violation: STOP, remove the query from the probed path, re-verify

CORRECT:
```go
func (g *gateway) handleReadyz(w http.ResponseWriter, _ *http.Request) {
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte("ready"))
}
```

PROHIBITED:
```go
func (g *gateway) handleReadyz(w http.ResponseWriter, r *http.Request) {
	if err := g.pool.Ping(r.Context()); err != nil {
		http.Error(w, err.Error(), http.StatusServiceUnavailable)
		return
	}
	w.WriteHeader(http.StatusOK)
}
```

**CONSTRAINT:** A sleeper-backed connection pool MUST drop idle connections before the vendor idle-suspend window. MUST set `MinConns` and `MinIdleConns` to 0. MUST set `MaxConnIdleTime` strictly less than that window (Neon Free default suspend is 5 minutes; use 1 minute unless the vendor documents a shorter window). MUST NOT keep a health-check period that recreates idle connections.

- MUST: close unused conns with pool idle timeout / health check destroy, not with a probe `Ping`
- MUST NOT: set `MinConns` / `MinIdleConns` above 0 on a sleeper catalog or similar
- Enforcement: read `pgxpool.Config` (or equivalent) at pool create; confirm MinConns 0, MinIdleConns 0, MaxConnIdleTime < sleeper window
- Violation: STOP, set those fields, re-verify

CORRECT:
```go
cfg.MinConns = 0
cfg.MinIdleConns = 0
cfg.MaxConnIdleTime = time.Minute
cfg.HealthCheckPeriod = 30 * time.Second
```

PROHIBITED:
```go
cfg.MinConns = 2
cfg.MaxConnIdleTime = 30 * time.Minute
// probe or pool Ping every 2s
```

**CONSTRAINT:** Real application traffic MAY open a connection and wake the sleeper. Startup MAY touch the store once when the process cannot listen without it. MUST NOT add a background keep-alive whose only job is to keep the store hot.

- MUST: session, membership, or catalog lookups on `/v1/...` (or equivalent product routes) remain the wake path
- MUST NOT: interval ticks, readiness probes, or pool min-size backfill as keep-alive
- Enforcement: trace who calls the sleeper pool besides product handlers and a single startup check
- Violation: STOP, remove the keep-alive, re-verify

CORRECT:
```text
idle serve → cheap /readyz → no pool traffic → store sleeps
first /v1/me or cataloged API → lookup → store wakes
```

PROHIBITED:
```text
process-compose curls /readyz every 2s → handler Ping() → store never reaches idle
```

## Steps

1. **Classify the store** — run the applicability gate. If it cannot suspend, stop this skill.
2. **Probe** — point compose at a handler that does not query the sleeper. Prefer existing `/readyz` made cheap over deleting the probe.
3. **Pool** — set MinConns 0, MinIdleConns 0, MaxConnIdleTime below the suspend window.
4. **Wake path** — leave product handlers as the only repeating store traffic.
5. **Smoke** — after idle longer than MaxConnIdleTime plus the vendor window, the vendor compute is suspended (or pool Stat shows 0 idle conns) while `/readyz` still returns 200.

## Pre-completion checklist

- [ ] **Probe is cheap:** Probed URL does not query the sleeper
      Method: read the handler behind `readiness_probe` / `/readyz`
      Pass: no `Ping` / `Query` / `Exec` on that pool
      Fail: STOP, remove the query
- [ ] **Pool can empty:** MinConns 0, MinIdleConns 0, MaxConnIdleTime < sleeper window
      Method: read pool config at create
      Pass: all three match
      Fail: STOP, set them
- [ ] **Wake is product traffic:** No interval keep-alive besides pool idle destroy
      Method: grep Ping/Query on that pool from probe, ticker, and min-size backfill
      Pass: only startup-once and product handlers remain
      Fail: STOP, delete the keep-alive
