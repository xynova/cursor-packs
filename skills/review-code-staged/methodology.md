# Staged Review Methodology (Go)

LOAD-WHEN: `review-code-staged` skill is active.

---

## Review stage catalogue

Seven stages in two modes. MUST present as a numbered menu and ask which stages to run before executing any stage.

### Detect stages — objective, no dialogue mid-stage

| # | Stage | What it covers |
|---|-------|----------------|
| 1 | Automated Tools | `make vet`, `make lint`, format check; capture exit codes and raw output |
| 2 | Type Safety | `any` / `interface{}`, type assertions, nil before dereference |
| 3 | Error Handling | wrapping, `_ =`, log-without-return, persistence, DB fallback |
| 7 | Code Clarity | naming, godot periods, logs, over-export |

AI finds issues, reports them with code pairs in the plan file. No user input required mid-stage.

### Consultant stages — ask, do not verdict

| # | Stage | What it covers |
|---|-------|----------------|
| 4 | Architecture | SRP, layering, coupling, ISP, CLI→service→client |
| 5 | Robustness | timeouts, resource cleanup, edge cases, LLM-in-transaction |
| 6 | Testability | DI seams, mocks, constructor hooks, mixed concerns |

AI surfaces **concerns as questions**. User answers → finding or non-issue. "I don't know" → open question, move on.

**"All"** runs stages 1–7 in order.

**Rules:**

- MUST present this menu before executing anything.
- MUST ask "Which stages? (numbers, ranges, or 'all')" and wait.
- MUST NOT begin stage execution without explicit stage selection.

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
- [ ] External errors wrapped (`%w` or `errors.NewDomainError`)
- [ ] No log-without-return on error paths
- [ ] Persistence / session-refresh errors returned (see [appendix.md](appendix.md))
- [ ] No DB-query fallback inside transactions (architecture §6.7)
- [ ] Resources closed with `defer` after the error check
- [ ] Named returns not shadowed when `defer` reads `err` (see appendix)

Also load [appendix.md](appendix.md) for this stage.

---

## Stage 4: Architecture — Consultant

**Inspect first:**

- Type with >10 methods spanning unrelated concerns → possible God type
- Package imports >8 other internal packages → possible coupling
- CLI command contains business logic or HTTP → layer violation
- HTTP/`http.Do` outside `internal/clients/` (or a pipeline HTTP client) → client isolation
- Interface with 10+ methods → ISP / god interface
- Domain models mixed with infrastructure DTOs
- Direct `NewClient` / `logrus.New` inside a service

**Then ask (one at a time):**

- "This type has [N] methods across [A] and [B]. Intentional, or split?"
- "This package imports [N] internals. Expected for its role?"
- "The CLI calls [client/repo] directly. Why is the service skipped?"

For a full architecture pass, point at `.cursor/commands/review-architecture.md` instead of duplicating it.

---

## Stage 5: Robustness — Consultant

**Inspect first:**

- HTTP client with no timeout
- Missing `defer` close/cancel/rollback
- Hardcoded URLs, ports, or secrets (must be config/env; see no-secrets rule)
- LLM or external HTTP **inside** a DB transaction (see appendix)
- No `ctx.Done()` check before expensive work
- Config/env missing → raw panic or empty continue instead of fail-fast

**Then ask:**

- "No timeout on [client]. Is a hung downstream acceptable?"
- "LLM call sits inside `WithTransaction`. Intentional, or should I/O move outside?"

---

## Stage 6: Testability — Consultant

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

## Stage 7: Code Clarity — Detect

- [ ] Comments end with a period (`godot`)
- [ ] No `fmt.Print*` for logs (pterm OK for interactive CLI)
- [ ] Log lines include discriminator fields (IDs, job names)
- [ ] Names are specific (not `process` / `handle` / `do` unless the package already uses them)
- [ ] Only essential symbols exported — if unsure, run `.cursor/skills/review-member-visibility/SKILL.md`
- [ ] No TODO/FIXME without explanation
- [ ] String literals used 3+ times extracted as constants (`goconst`)

---

## Consultant stage protocol

For each concern:

1. State what you observed (factual, no verdict).
2. Ask one focused question.
3. Wait.

| User reply | Action |
|------------|--------|
| Confirms it is a problem | Finding in plan file (severity + code pair) |
| Explains it is intentional | Non-issue; write rationale |
| Unsure / "move on" | Open question; continue |

- MUST ask one question at a time.
- MUST NOT block the stage on an unanswered question.

Question shape:

```
I noticed [observation at file:line].
This could mean [consequence A] or it could be intentional if [condition B].
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
**Selected Stages:** <e.g. "1, 2, 5, 6">

## Stages
- [ ] 1. Automated Tools
- [ ] 2. Type Safety
- [ ] 5. Robustness
- [ ] 6. Testability

## Findings

### Stage 1: Automated Tools

## Open Questions

### Stage 5: Robustness
```

- MUST create the plan file before stage 1.
- MUST tick `[x]` only after findings are appended.
- MUST NOT delete previous stage findings.
- Resume: list `tmp/review-*.md`, read the file, next unchecked stage, confirm, then run.

---

## Per-stage chat summary

```
---
**Stage N: <Name>** [Detect / Consultant] — Score: X/10

critical: <count>  medium: <count>  low: <count>  open questions: <count>

- critical: <one-line>
- medium: <one-line>
- low: <one-line>
- open: <one-line>

(or "No issues found." if clean)

---
Next: Stage N+1 — <Name>. Continue?
```

- MUST include score even if 10/10.
- MUST NOT paste full code blocks in chat — those go in the plan file.
- MUST wait for reply before the next stage.
- Severity: critical = architecture / security / resource leaks; medium = missing handling / robustness / testability; low = naming / clarity.

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
  A) Fix all findings (open questions excluded)
  B) Fix here — one finding at a time, highest severity first
  C) Stop — review only; plan file stays in tmp/
```

- MUST present all three options and wait.
- Open questions are NEVER auto-fixed.
