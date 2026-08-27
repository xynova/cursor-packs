---
name: golang-quality
description: >-
  Go generation and completion workflow: resource cleanup, error wrapping, nil
  guards, context propagation, CLI-service-client layering, and quality gates.
  Use when generating, completing, or fixing Go code, or before claiming a Go
  change is done.
---

# Go Quality

Prevention-first Go workflow. Project rules (if present) under `.cursor/rules/` still apply — e.g. `rules-for-golang-coding.mdc`, architecture rules. This skill is the **procedure**.

**Load patterns:** [reference.md](reference.md) for copy-paste examples.

**Related:** `.cursor/skills/code-review-staged/SKILL.md` for staged review; `.cursor/skills/review-member-visibility/SKILL.md` for export audits.

---

## When to load

- Generating or editing `.go` files
- Finishing a Go implementation, fix, or refactor
- User asks to lint, format, vet, or verify Go quality

---

## Core constraints

Apply these **while writing**, not only at review.

**CONSTRAINT 1 — HTTP bodies.** Every `resp.Body` MUST have `defer resp.Body.Close()` immediately after the error check.

**CONSTRAINT 2 — Context cancel.** Every `WithTimeout` / `WithCancel` / `WithDeadline` MUST have `defer cancel()` on the next line.

**CONSTRAINT 3 — Transactions.** Every `Begin` MUST have `defer tx.Rollback(ctx)` immediately after (no-op after successful `Commit`).

**CONSTRAINT 4 — Errors handled.** NEVER discard with `_ =` except inside defer cleanup. NEVER log an error without returning it (except defer where return is impossible).

**CONSTRAINT 5 — Wrap external errors.** MUST wrap with `fmt.Errorf("…: %w", err)` or `errors.NewDomainError(...)`. Message MUST name the failed operation.

**CONSTRAINT 6 — Persistence errors returned.** State-save failures MUST be returned. Log first, then return. Silent continue causes inconsistent state and loops.

**CONSTRAINT 7 — Nil guards.** Constructors MUST panic on nil required dependencies. Public API pointer inputs MUST return an error on nil (do not panic at the call site).

**CONSTRAINT 8 — Context propagated.** NEVER replace a received `ctx` with `context.Background()`. Check `ctx.Done()` before expensive work.

**CONSTRAINT 9 — No unused work / no N+1.** Every declared variable MUST be used. Batch fetches when the same data is needed for many IDs.

**CONSTRAINT 10 — CLI → Service → Client.** HTTP and external API calls ONLY in `internal/clients/<service>/` (or pipeline client packages that wrap HTTP). CLI MUST NOT contain business logic.

**CONSTRAINT 11 — Format and lint.** Comments MUST end with a period (`godot`). Run Makefile gates before completing (see below).

**CONSTRAINT 12 — Focused interfaces.** Interfaces MUST stay ≤ 5–6 methods. Split by caller responsibility.

**CONSTRAINT 13 — Report layouts use templates.** Multi-line operator-facing summaries, ASCII diagrams, and similar human reports MUST use `text/template` (or `html/template` when HTML). MUST NOT assemble those layouts with chained `WriteString` / `Sprintf`. One-line messages and tight loops MAY keep `fmt` / `strings.Builder`. See [reference.md](reference.md#text-templates-for-reports).

Logging: MUST use injected `internal/observability.Logger`. NEVER `fmt.Print*` for logs. Interactive CLI may use pterm (see architecture logging rule).

---

## Steps

1. **Load patterns** — Read [reference.md](reference.md) for templates.
2. **Implement** — Apply all 12 constraints during generation. First param on I/O functions: `ctx context.Context`.
3. **Self-check changed functions** — For each: resource deferred? errors wrapped and returned? context propagated? PASS or fix.
4. **Run quality gates** on changed packages. Prefer project Makefile targets when they exist; otherwise use the Go toolchain directly:

```bash
# Prefer (if Makefile defines them):
make format   # or: gofumpt -w . && goimports -w .
make lint     # or: golangci-lint run ./...
make vet      # or: go vet ./...
make test     # or: go test ./...
```

Scope to `./cmd/...` `./internal/...` (or the packages the project uses) when that is the local convention. If dependencies changed: `go mod tidy`.

Do NOT complete while any of these fail. Fix, re-run, then complete.

5. **Report** — Which constraints were verified and the command results.

---

## Pre-completion checklist

### Tooling

- [ ] Format: `make format` if present, else `gofumpt`/`gofmt` + `goimports`
- [ ] Lint: `make lint` if present, else `golangci-lint run` (gosec/godot via `.golangci.yml` when configured)
- [ ] Vet: `make vet` if present, else `go vet ./...`
- [ ] Test: `make test` if present, else `go test` on changed packages
- [ ] `go mod tidy` if `go.mod` / imports changed

Do **not** require a standalone `gosec` binary or `.gosec.yaml` unless the project documents them. Prefer `gosec` as a golangci linter when enabled.

### Resources

- [ ] Every `resp.Body` has `defer resp.Body.Close()` after the error check
- [ ] Every cancellable context has `defer cancel()`
- [ ] Every `Begin` has `defer tx.Rollback`
- [ ] Files and connections have matching `defer Close()`

### Errors and safety

- [ ] No `_ =` except defer cleanup
- [ ] External errors wrapped; persistence errors returned
- [ ] Constructor nil panics; pointer params nil-checked
- [ ] No `context.Background()` inside a function that already has `ctx`
- [ ] No HTTP outside client packages; no `logrus.New()` / `database.NewClient()` inside business logic

### Quality

- [ ] No unused variables; no N+1 when a batch exists
- [ ] Large structs (3+ fields) passed/returned by pointer
- [ ] Interfaces ≤ 6 methods
- [ ] Only essential symbols exported
- [ ] All comments end with a period
- [ ] Multi-line reports/diagrams use `text/template` (not chained `WriteString`)
