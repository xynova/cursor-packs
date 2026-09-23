# Staged Review Methodology (Go)

LOAD-WHEN: `review-code-staged` skill is active.

---

## Review stage catalogue

Eight stages in **two groups**. MUST present the menu as those groups first, then the stage tables, and ask which group(s) or stages to run before executing any stage.

**Run order:** mechanical numbers ascending (`1`–`5`), then consultant letters ascending (`A`–`C`). When both groups are selected, run `1, 2, 3, 4, 5, A, B, C`.

### Group aliases (prefer these)

| Selection | Expands to | Meaning |
|-----------|------------|---------|
| `mechanical` | `1, 2, 3, 4, 5` | Detect-only: tools, types, errors, clarity, generation gates. No dialogue mid-stage; no pause between stages. |
| `consultant` | `A, B, C` | Architecture / robustness / testability questions. Dialogue mid-stage; pause only here. |
| `both` or `all` | `1`–`5`, `A`–`C` | Mechanical batch runs without pause, then consultant (`A`–`C`) asks mid-pass. |

Also accept stage IDs, ranges (`1-3`, `A-C`), or mixes (`mechanical, A` → mechanical plus Architecture).

**CONSTRAINT:** The opening menu MUST offer `mechanical`, `consultant`, and `both` as first-class choices (not only raw stage IDs).
- Enforcement: First review chat turn after the target is known includes those three group words and waits.
- Violation: STOP, re-present the group menu; do not start a stage.

CORRECT:
```text
Groups: mechanical | consultant | both
Or stages: 1–5 (mechanical), A–C (consultant). Which?
```

PROHIBITED:
```text
Which stages? (numbers, ranges, or 'all')
→ only that, with no mechanical/consultant group names
```

### Mechanical stages — objective, no dialogue mid-stage

| # | Stage | What it covers |
|---|-------|----------------|
| 1 | Automated Tools | `make vet`, `make lint`, format check; capture exit codes and raw output |
| 2 | Type Safety | `any` / `interface{}`, type assertions, nil before dereference |
| 3 | Error Handling | typed wrap-chain, `_ =`, log-without-return, persistence, DB fallback |
| 4 | Code Clarity | naming, godot periods, structured logs, over-export |
| 5 | Generation Gates | `golang-quality` constraints 1–24 (templates, OTEL, durable AI dumps, resources, layering, config create, package layout, Makefile verb list + shared Make verbs, outbound failsafe-go resilience, HTTP/CLI service-layer error mapping, numbered SQL migrations); `go-structured-strings` for report builders. External Uber / Code Review Comments are citations only. |

AI finds issues, reports them with code pairs in the plan file. No user input required mid-stage or between mechanical stages.

**CONSTRAINT:** When two or more mechanical stages are selected, MUST run them as one continuous batch. After each mechanical stage, append findings and print the per-stage chat summary, then start the next mechanical stage in the same turn chain without asking "Continue?" or waiting.
- Enforcement: No "Continue?" between stages `1`–`5`; only the consultant protocol and the completion handoff wait for the user.
- Violation: STOP asking for Continue on mechanical; finish the remaining mechanical batch, then enter consultant or handoff.

CORRECT:
```text
Stage 1 summary → Stage 2 → … → Stage 5 summary → (if selected) consultant A first question
```

PROHIBITED:
```text
Stage 1 summary
Next: Stage 2. Continue?
→ wait for the user before Stage 2
```

For a full write-time quality story without consultant dialogue, prefer **`mechanical`** (same as `1, 2, 3, 4, 5`).

### Consultant stages — ask, do not verdict

| ID | Stage | What it covers |
|----|-------|----------------|
| A | Architecture | SRP, layering, coupling, ISP, CLI→service→client, typed error wrap-chain, observability init seams |
| B | Robustness | timeouts, missing-deadline fail-closed, resource cleanup, edge cases, LLM-in-transaction, client OTEL vs gateway-only |
| C | Testability | DI seams, mocks, constructor hooks, mixed concerns |

AI surfaces **concerns as questions**. User answers → finding or non-issue. "I don't know" → open question, move on.

### Legacy ID map (pre-reindex)

| Old | New |
|-----|-----|
| 1–3 | 1–3 (unchanged) |
| 4 Architecture | A |
| 5 Robustness | B |
| 6 Testability | C |
| 7 Code Clarity | 4 |
| 8 Generation Gates | 5 |

If a plan file still lists old IDs, map with this table, then continue.

**Rules:**

- MUST present this menu before executing anything.
- MUST ask which group(s) or stages (`mechanical`, `consultant`, `both`/`all`, `1`–`5`, `A`–`C`, or ranges) and wait.
- MUST NOT begin stage execution without explicit selection.
- MUST expand group aliases to stage IDs, then run in order `1`–`5` then `A`–`C` (skipping unselected).
- MUST run the selected mechanical batch without mid-batch "Continue?" waits; MUST pause for user input only on consultant stages (`A`–`C`) and at completion handoff.
- MUST NOT invent a third group; omit stages by ID if the user wants a subset of mechanical or consultant.

---

## Stage 1: Automated Tools — Detect

Run (prefer Makefile when targets exist):

```bash
make vet    # or: go vet ./...
make lint   # or: golangci-lint run
gofmt -l .  # or project packages such as ./cmd ./internal
```

Record exit codes and relevant output. Each reported issue is a finding (severity from the tool when obvious; otherwise Medium). When golangci is configured with `gosec`/`godot`, lint covers those.

Do not fail pre-flight for missing `gocyclo` or `.gosec.yaml`.

---

## Stage 2: Type Safety — Detect

- [ ] No bare `any` / `interface{}` where a concrete type or type parameter is known
- [ ] Type assertions check `ok` (never `v, _ := x.(T)`)
- [ ] Pointers and map lookups are guarded before use when nil/missing is possible
- [ ] Constructor required deps are nil-checked (panic in `New*`)
- [ ] Public API pointer params return an error on nil

---

## Stage 3: Error Handling — Detect

- [ ] No `_ =` except defer cleanup
- [ ] Each hop returns a typed domain error (code, op, optional fields, `Unwrap`); not a bare `err`
- [ ] Cause is wrapped (`Wrap` / `NewDomainError` / `fmt.Errorf("%w")` only at a stdlib leaf, then converted)
- [ ] No `err.Error()` stringify that drops `errors.Is` / `As`
- [ ] No log-without-return on error paths
- [ ] Persistence / session-refresh errors returned (see [appendix.md](appendix.md))
- [ ] No DB-query fallback inside transactions (architecture §6.7)
- [ ] Resources closed with `defer` after the error check
- [ ] Named returns not shadowed when `defer` reads `err` (see appendix)

Also load [appendix.md](appendix.md) for this stage.

---

## Stage 4: Code Clarity — Detect

- [ ] Comments end with a period (`godot`)
- [ ] No `fmt.Print*` for logs (pterm OK for interactive CLI)
- [ ] Logging uses injected `*observability.Logger` (or project equivalent); no ad-hoc `logrus.New()` in services
- [ ] Log lines include discriminator fields (IDs, job/task names)
- [ ] Names are specific (not `process` / `handle` / `do` unless the package already uses them)
- [ ] Only essential symbols exported — if unsure, run `.cursor/skills/review-member-visibility/SKILL.md`
- [ ] No TODO/FIXME without explanation
- [ ] String literals used 3+ times extracted as constants (`goconst`)

Clarity only. Templates, resource defers, CLI→service→client layering, and process/LLM OTEL gates belong in **Stage 5**, not here. If Stage 5 is not selected, note that generation gates were skipped rather than re-checking them under clarity.

---

## Stage 5: Generation Gates — Detect

Same MUSTS as write-time Go generation. MUST Read `.cursor/skills/golang-quality/SKILL.md` **Core constraints** (1–23) and apply them as a checklist against the review target. For multi-section markdown, reports, TOC, or similar human layout builders, also Read and apply `.cursor/rules/go-structured-strings.mdc`. Go Code Review Comments and Uber Go Style Guide are the external taste baseline cited in `golang-quality`; MUST NOT invent Stage 5 findings from those guides unless they map to a Core constraint.

### CLI command surface (when a binary / CLI entrypoint is in scope)

When the review target includes a command-line runner (`cmd/`, daemon `main`, CLI package that owns process argv), MUST also Read `.cursor/skills/cli-command-surface/SKILL.md` and apply its binary checks. These checks are language-agnostic behavior gates; they apply to Go entrypoints in this review and to other-language runners when that is the stated target.

- [ ] Bare invoke (no args) does not Listen/Serve; prints usage and exits non-zero
- [ ] Root `version` (or documented equivalent) prints identity without config / license Gate / network
- [ ] Root help catalog lists start + version + other real root commands
- [ ] Unknown root command does not fall through to serve
- [ ] Makefile / Docker / Air / compose / README start paths use the explicit start command
- [ ] Optional discovery flags (`--config`, `--license`, socket) are not documented as required when defaults exist

### Ownership vs Stage 3

- **Stage 3** keeps error-handling depth (typed wrap-chain, `_ =`, log-without-return, persistence, named returns, DB fallback).
- **Stage 5** owns generation-specific gates Stage 3 does not cover: C1–3 (HTTP/cancel/txn defers), C7–24 (nil, ctx, unused/N+1, layering, format/godot overlap, interfaces, templates, structured logging, OTEL, durable AI dumps, AI module isolation, config create, package layout, Makefile verbs, outbound failsafe-go resilience, HTTP/CLI service-layer error mapping, numbered SQL migrations).
- Apply **C4** and **C6** in Stage 5 **only when Stage 3 was not selected** for this review. If Stage 3 already ran, do not duplicate those findings under Stage 5.

### Checklist (map to golang-quality)

- [ ] C1: every `resp.Body` has `defer Close()` after the error check
- [ ] C2: every `WithTimeout` / `WithCancel` / `WithDeadline` has `defer cancel()` on the next line
- [ ] C3: every `Begin` has `defer tx.Rollback` after the error check
- [ ] C4 / C6 (only if Stage 3 not selected): no `_ =` except defer cleanup; no log-without-return; persistence errors returned
- [ ] C7: constructor nil panics; public pointer params nil-checked
- [ ] C8: no replacing received `ctx` with `context.Background()`; `ctx.Done()` before expensive work; outbound hops fail closed when `ctx`/`req.Context()` has no deadline (no leaf `Timeout` / `WithTimeout` fallback) — see `go-outbound-resilience.mdc`
- [ ] C9: no unused work; no N+1 when a batch exists
- [ ] C10: HTTP / external API only in client packages; CLI has no business logic
- [ ] C11: comments end with period; format/lint gates known for the project (Stage 1 already ran tools when selected)
- [ ] C12: interfaces ≤ 5–6 methods
- [ ] C13: multi-line operator reports / diagrams use `text/template` (or `html/template`); not chained `WriteString` / `Sprintf` spaghetti — see `go-structured-strings.mdc`
- [ ] C14: injected structured logger; no `fmt.Print*` / ad-hoc `logrus.New()` in services
- [ ] C15: LLM/inference entrypoints init OTEL; OTLP when endpoint env is set; client spans on generate/evaluate (not gateway-only); named-return span defers use `err =`
- [ ] C16: AI work dumps (RLM TraceDir, runreport, inference-failure JSON) survive process exit; not only under `defer RemoveAll` scratch; durable path logged or returned
- [ ] C17: when generators/evaluators/signatures change: discrete contracts are structured signature fields; env-gated live opt-in replay exists (or PR documents offline-only); full reseed is not the only exercise path — see `dspy-pipeline-isolation`
- [ ] C18: multi-field construction uses config create (`cfg.Create*` / `CreateModule`); no long parallel arg lists beside a half-empty Config
- [ ] C19: kit vs app classified; kit public API in `pkg/<domain>/` (not trapped in `internal/`); app `main` is wiring only (no mux/handlers/routing in `package main`); new files sit under `internal/<domain>/` rather than a new root sibling or grab-bag (`util`, `common`, `helpers`, `shared`, `misc`, `tools`); `internal/` is not a flat dumping ground; app modules do not grow a mixed host `pkg/` unless they are also a published kit. See appendix pattern 17.
- [ ] C20 / C21: if a Makefile is in scope, help lists operator verbs; shared jobs use shared names (`serve` / `serve-down`, not only `dev`)
- [ ] C22: outbound process exec and HTTP client hops use failsafe-go (retry with exponential backoff + jitter, circuit breaker for shared network-backed deps); flag bare `Do` / `Command` / `CommandContext` in client/exec packages; no ad-hoc sleep retry loops; classify retryable vs permanent errors — MUST Read `.cursor/rules/go-outbound-resilience.mdc` when outbound hops are in scope; see appendix pattern 19
- [ ] C23: inbound HTTP / CLI entry packages map service-layer errors (`errors.Is` / `As` / `Is*` on the commands/service package); MUST NOT import a kit/leaf package solely to check that leaf’s sentinel when the service hop owns the operation
- [ ] C24: when durable SQL schema is in scope, numbered migration files + apply-pending-once; flag DDL (`CREATE TABLE IF NOT EXISTS` / full schema strings) on every write/publish path; SQL provider packages should not force db drivers onto DTO-only importers — see appendix pattern 20

Also load [appendix.md](appendix.md) pattern 14 when LLM paths are in scope, pattern 15 when TraceDir / runreport / failure dumps are in scope, pattern 16 when generator/evaluator/signature diffs are in scope, pattern 17 when package paths, `cmd` mains, or `internal/` layout are in scope, pattern 18 when CLI argv / `serve` / `version` / bare-binary start paths are in scope, pattern 19 when outbound exec/HTTP or forge CLI wrappers are in scope (also Read `.cursor/rules/go-outbound-resilience.mdc`), and pattern 20 when durable SQL schema / store publish paths are in scope.

---

## Stage A: Architecture — Consultant

**Inspect first:**

- Type with >10 methods spanning unrelated concerns → possible God type
- Package imports >8 other internal packages → possible coupling
- CLI command contains business logic or HTTP → layer violation
- HTTP/`http.Do` outside `internal/clients/` (or a pipeline HTTP client) → client isolation
- Bare `http.Client.Do` / `exec.Command*` in client/exec packages without failsafe-go → C22 resilience gap
- Interface with 10+ methods → ISP / god interface
- Domain models mixed with infrastructure DTOs
- Direct `NewClient` / `logrus.New` inside a service
- Request-path package that returns only `fmt.Errorf` / bare `error` with no layer-typed error
- HTTP / CLI entry package imports a kit or leaf package solely to `errors.Is` that leaf’s sentinel (C23; service should wrap or re-export)
- LLM/inference CLI or worker entrypoint with no `observability.Init` (or project OTEL bootstrap)
- Daemon or long-running CLI whose default argv path Listen/Serves without an explicit start command → command-surface violation (also Stage 5 detect; ask naming / migration here)
- Generate/evaluate path with no client OpenInference (or project) spans; only an AI gateway is expected to show traces
- Reusable library API trapped in `internal/`, flat `internal/` sprawl (many sibling leaves, no domain parents), a new top-level `internal/<leaf>` that belongs under an existing domain, grab-bag names (`util`, `common`, `helpers`, `shared`, `misc`, `tools`), fat `cmd` mains, or an app module adding mixed host `pkg/`

**Then ask (one at a time):**

- "This type has [N] methods across [A] and [B]. Intentional, or split?"
- "This package imports [N] internals. Expected for its role?"
- "The CLI calls [client/repo] directly. Why is the service skipped?"
- "[hop] returns fmt.Errorf only. Wrap in a layer domain error with a code, or is a string error enough here?"
- "HTTP maps `pkg/<kit>` sentinel X directly. Keep that import, or re-export / wrap on the service package (C23)?"
- "This LLM entrypoint has no OTEL init / no client spans. Rely on the gateway alone, or wire process tracing?"
- "Is this a reusable library with public API trapped in `internal/`, or should that surface move to `pkg/`?"
- "This `cmd/<app>/main.go` does more than wiring. Should it be thinned to config, observability, and a run call?"
- "This change adds `internal/<leaf>` at the internal root. Does an existing domain folder own it, or is a new domain parent the right nest?"
- "Bare `<bin>` starts the service. Should start be an explicit command (`serve` / `run`), and what breaks if we change launchers?"

For a full architecture pass, point at project `pipelines-x-review-architecture` (if present) instead of duplicating it.

---

## Stage B: Robustness — Consultant

**Inspect first:**

- HTTP client with no timeout
- Outbound hop (HTTP, plugin, proxy) with no `ctx.Deadline()` that invents a fallback duration instead of failing closed
- Missing `defer` close/cancel/rollback
- Hardcoded URLs, ports, or secrets (must be config/env; see no-secrets rule)
- LLM or external HTTP **inside** a DB transaction (see appendix)
- No `ctx.Done()` check before expensive work
- Config/env missing → raw panic or empty continue instead of fail-fast
- LLM path with gateway HTTP traces only (no client OpenInference/OTLP spans) so post-response hangs are invisible (see appendix §14)
- OTLP endpoint documented for the project but process never exports when that env is set
- Named `err` shadowed before `EndSpanWithStatus` / span defer (see appendix §5)

**Then ask:**

- "No timeout on [client]. Is a hung downstream acceptable?"
- "[hop] has no ctx deadline and falls back to [duration]. Fail closed before the call, or is a fallback timeout acceptable?"
- "LLM call sits inside `WithTransaction`. Intentional, or should I/O move outside?"
- "LLM work is only visible in the AI gateway. Is a client-side hang after HTTP 200 acceptable without a Phoenix/OTLP span?"

**CONSTRAINT:** Outbound hops that require a caller-supplied bound MUST fail closed when `ctx` has no deadline: return an error and NEVER call the downstream. MUST NOT invent a fallback timeout. Caller/gateway still MUST set the deadline on normal traffic.
- Enforcement: Stage B inspect lists this hop; the consultant asks the question above in the same turn as Why this matters.
- Violation: Record a finding (or an open question if the user is unsure). Do not treat a fallback duration as an implicit bound.

**CONSTRAINT:** LLM generate/evaluate (and equivalent inference hops) MUST be observable from the calling process via OpenTelemetry / OpenInference spans exported when an OTLP endpoint is configured. MUST NOT treat AI-gateway HTTP traces as the sole observability plan for client parse, evaluate, or hang failures after the response.
- Enforcement: Stage B inspect lists gateway-only or missing-init cases; consultant asks the Phoenix/OTLP question above with Why this matters.
- Violation: Record a finding (or open question). Do not clear as non-issue solely because the gateway shows HTTP 200.

CORRECT:
```go
if _, ok := ctx.Deadline(); !ok {
    return errors.New(errors.CodeFailedPrecondition, hop, "missing deadline")
}
// then call downstream with ctx
```

PROHIBITED:
```go
timeout := 300 * time.Second
if d, ok := ctx.Deadline(); ok {
    timeout = time.Until(d)
}
// still calls downstream when deadline is missing
```

MUST NOT flag tests, `context.Background()` at process start, or in-process work with no outbound I/O.

---

## Stage C: Testability — Consultant

**Inspect first:**

- External dep constructed inside the type instead of injected
- Package-level mutable state
- `time.Now()` / `uuid.New` not injectable where tests need control
- Function 40+ lines with mixed concerns
- Unit test hitting a real network or database

**Then ask:**

- "[Type] constructs [dep] in `New`/`method`. Do tests need a mock seam?"
- "[Function] is [N] lines covering [concerns]. Split in scope?"

---

## Consultant stage protocol

For each concern:

1. Inspect and write the question in the **same loop** (same agent, same turn). Do not split “find” and “ask” across a subagent.
2. State what you observed (factual, no verdict).
3. Ask one focused question, then a short **Why this matters**.
4. Wait.

| User reply | Action |
|------------|--------|
| Confirms it is a problem | Finding in plan file (severity + code pair) |
| Explains it is intentional | Non-issue; write rationale |
| Unsure / "move on" | Open question; continue |
| `explain` / “what do people normally do” | Expand in the **same turn**: usual practice, trade-offs, tables. MUST NOT start the next stage or the next concern. |

- MUST ask one question at a time.
- MUST NOT block the stage on an unanswered question.
- MUST keep inspect + question + Why this matters in the same loop.
- MUST NOT launch a subagent only to explain a concern. Subagents do not display text to the user; the parent still has to relay it.
- MUST add **Why this matters** after the question (2-5 lines: consequence of A vs B, not a lecture).
- MAY launch a research subagent only when the fork depends on an upstream or library fact that is not in this repo (for example provider docs). That is research, not display.

**CONSTRAINT:** Consultant questions MUST include Why this matters in the same turn as the question.
- Enforcement: Chat turn that asks a stage A–C question also contains a Why this matters block of 2-5 lines.
- Violation: Add the block before waiting; do not start the next concern.

CORRECT:
```
I noticed Handler has 15 methods at internal/gateway/server.go:85.
This could mean a God type, or it could be intentional if one facade is the product boundary.
Why this matters: Split handlers are easier to test; one type grows every new route.
Is keeping all of those on one Handler intentional, or should capabilities split?
(If you're not sure, say so and I'll log it as an open question.)
```

PROHIBITED: Compact question only, with no Why this matters, then waiting.
PROHIBITED: `Task` / subagent whose only job is to write the explanation.
PROHIBITED: Starting the next stage because the user said `explain`.

Question shape:

```
I noticed [observation at file:line].
This could mean [consequence A] or it could be intentional if [condition B].
Why this matters: [2-5 lines]
Is [specific question]?
(If you're not sure, say so and I'll log it as an open question.)
```

---

## Review plan file

**Location:** `tmp/review-<slug>-<YYYY-MM-DD>.md`

**slug:** target path with slashes replaced by dashes, max 30 chars.

```markdown
# Review Plan: <slug>
**Date:** <YYYY-MM-DD>
**Target:** <file or directory>
**Selected Stages:** <e.g. "mechanical" or "1, 2, 3, 4, 5" or "A, B, C">

## Stages
- [ ] 1. Automated Tools
- [ ] 2. Type Safety
- [ ] 3. Error Handling
- [ ] 4. Code Clarity
- [ ] 5. Generation Gates
- [ ] A. Architecture
- [ ] B. Robustness
- [ ] C. Testability

## Findings

### Stage 1: Automated Tools

## Open Questions
```
- MUST create the plan file before the first selected stage.
- MUST tick `[x]` only after findings are appended.
- MUST NOT delete previous stage findings.
- Resume: list `tmp/review-*.md`, read the file, run from the first unchecked stage. Remaining mechanical stages continue as a batch (no confirm); consultant stages resume the ask/wait protocol.

---

## Per-stage chat summary

### Mechanical stages (`1`–`5`)

Print the score block after each mechanical stage. Do **not** ask "Continue?". If another mechanical stage remains, continue into it. If the next selected stage is consultant, say that consultant dialogue starts next, then begin Stage A (or the first selected letter) with its first question in a following turn after the mechanical batch is fully written to the plan file.

```
---
**Stage <ID>: <Name>** [Mechanical] — Score: X/10

critical: <count>  medium: <count>  low: <count>  open questions: <count>

- critical: <one-line>
- medium: <one-line>
- low: <one-line>
- open: <one-line>

(or "No issues found." if clean)

---
Continuing: Stage <ID> — <Name>.
```

(or, after the last mechanical stage when consultant is selected:)

```
---
Mechanical batch complete. Starting consultant Stage <ID> — <Name>.
```

### Consultant stages (`A`–`C`)

Same score block after the stage’s inspect pass when the stage completes. Between concerns, use the consultant question shape (observation + question + Why this matters) and **wait**. When a consultant stage finishes (all concerns answered or logged open) and another consultant stage remains, start that stage’s first concern without a separate "Continue?" prompt.

```
---
**Stage <ID>: <Name>** [Consultant] — Score: X/10

critical: <count>  medium: <count>  low: <count>  open questions: <count>

- critical: <one-line>
- medium: <one-line>
- low: <one-line>
- open: <one-line>

(or "No issues found." if clean)

---
Next: Stage <ID> — <Name>. (consultant — will ask before verdicts)
```

- MUST include score even if 10/10.
- MUST NOT paste full code blocks in chat — those go in the plan file.
- MUST NOT wait for "Continue?" between mechanical stages.
- MUST wait for user replies during consultant questions (and at completion handoff).
- Severity: critical = architecture / security / resource leaks; medium = missing handling / robustness / testability; low = naming / clarity.
- MUST record Low findings in the plan file the same way as Medium/High. Severity is priority order, not a license to skip.

**CONSTRAINT:** MUST NOT bypass Low concerns when they are fixable.
- Enforcement: Every Low finding has a recommendation; Fix option A includes all recorded findings (Low included). Chat MUST NOT say Low can be ignored or left for later solely because they are Low.
- Violation: Restore the Low finding; include it in the fix set unless the user explicitly declines that item.

CORRECT: Lint S1017 / godot / unused close listed as Low and included when the user picks "Fix all findings".
PROHIBITED: "Only Medium+ matter; skip Low naming/clarity."
PROHIBITED: Omitting a tool-reported Low from the plan because it is "nitpicky."

### Plan file finding

```markdown
#### <Severity> <Category>: <Short title>
**Location:** `path/to/file.go:line`
**Severity:** High / Medium / Low

**Current Code:**
(exact snippet)

**Recommendation:**
(working alternative)

**Rationale:** <Impact>: <consequence>
```

### Plan file open question

```markdown
#### Open <Category>: <Short title>
**Location:** `path/to/file.go:line`
**Observation:** <factual>
**Question:** <unanswered>
**Possible outcomes:**
- If [A]: classify as [severity] → [action]
- If [B]: non-issue
```

---

## Completion handoff

```
## Review Complete: <slug>

| Stage | Score | Open Qs |
|-------|-------|---------|
| 1. Automated Tools | X/10 | — |
| **Overall** | X/10 | N open |

**Top findings:**
- ...

**Open questions:** (if any)
- Stage N: ...

Fix options:
  A) Fix all findings including Low (open questions excluded)
  B) Fix here — one finding at a time, highest severity first, then fixable Low
  C) Stop — review only; plan file stays in tmp/
```

- MUST present all three options and wait.
- Open questions are NEVER auto-fixed.
- MUST NOT drop Low findings from option A. Prefer fixing fixable Low concerns with the rest.
- When the user picks A or B, MUST treat Low the same as other findings for inclusion; B only orders by severity.
