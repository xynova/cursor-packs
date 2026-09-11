---
name: golang-quality
description: >-
  Go generation and completion workflow: resource cleanup, error wrapping, nil
  guards, context propagation, CLI-service-client layering, structured logging,
  OpenTelemetry / OpenInference observability, and quality gates. Use when
  generating, completing, or fixing Go code, or before claiming a Go change is
  done.
---

# Go Quality

Prevention-first Go workflow. This skill is the **procedure**. Project architecture / domain rules (if present) still apply.

**Deep reference:** [reference.md](reference.md) (full encyclopedia). **Compact patterns:** [reference-patterns.md](reference-patterns.md).

**Related:** `.cursor/skills/review-code-staged/SKILL.md` for staged review (**Stage 8** applies these Core constraints at review, not only while writing); `.cursor/skills/review-member-visibility/SKILL.md` for export audits. Report layouts: `.cursor/rules/go-structured-strings.mdc`.

---

## When to load

- Generating or editing `.go` files
- Finishing a Go implementation, fix, or refactor
- User asks to lint, format, vet, or verify Go quality
- Staged review **Stage 8 (Generation Gates)** is running (load this skill and apply Core constraints as a detect checklist)

---

## Core constraints

Apply these **while writing** and again when staged review **Stage 8** runs. Do not treat review Stage 7 (clarity) as a substitute for these gates.

**CONSTRAINT 1 — HTTP bodies.** Every `resp.Body` MUST have `defer resp.Body.Close()` immediately after the error check.

**CONSTRAINT 2 — Context cancel.** Every `WithTimeout` / `WithCancel` / `WithDeadline` MUST have `defer cancel()` on the next line.

**CONSTRAINT 3 — Transactions.** Every `Begin` MUST have `defer tx.Rollback(ctx)` immediately after (no-op after successful `Commit`).

**CONSTRAINT 4 — Errors handled.** NEVER discard with `_ =` except inside defer cleanup. NEVER log an error without returning it (except defer where return is impossible).

**CONSTRAINT 5 — Typed domain errors.** MUST return a typed domain error with a stable code, layer `op`, message, optional fields, and `Unwrap`. MUST wrap the incoming cause at each hop (client → plugin/service → gateway). MUST NOT return a bare `err`. MUST NOT stringify a cause with `err.Error()` and drop the chain. `fmt.Errorf("%w")` MAY wrap a stdlib cause at the leaf, then MUST convert to a domain error before leaving the package.
- Enforcement: Every new or changed error return is a typed wrap; `errors.Is`/`As` still reach the cause.
- Violation: STOP, wrap with the package `internal/errors` (or project equivalent) and re-check.

CORRECT:
```go
return derrors.Wrap(err, derrors.CodeUnavailable, "cloudflare.Synthesize", "post /run").
    With("backend", b.ID)
```

PROHIBITED:
```go
return err
return fmt.Errorf("post /run: %s", err.Error())
```

**CONSTRAINT 6 — Persistence errors returned.** State-save failures MUST be returned. Log first, then return. Silent continue causes inconsistent state and loops.

**CONSTRAINT 7 — Nil guards.** Constructors MUST panic on nil required dependencies. Public API pointer inputs MUST return an error on nil (do not panic at the call site).

**CONSTRAINT 8 — Context propagated.** NEVER replace a received `ctx` with `context.Background()`. Check `ctx.Done()` before expensive work.

**CONSTRAINT 9 — No unused work / no N+1.** Every declared variable MUST be used. Batch fetches when the same data is needed for many IDs.

**CONSTRAINT 10 — CLI → Service → Client.** HTTP and external API calls ONLY in `internal/clients/<service>/` (or pipeline client packages that wrap HTTP). CLI MUST NOT contain business logic.

**CONSTRAINT 11 — Format and lint.** Comments MUST end with a period (`godot`). Run Makefile gates before completing (see below).

**CONSTRAINT 12 — Focused interfaces.** Interfaces MUST stay ≤ 5–6 methods. Split by caller responsibility.

**CONSTRAINT 13 — Report layouts use templates.** Multi-line operator-facing summaries, ASCII diagrams, and similar human reports MUST use `text/template` (or `html/template` when HTML). MUST NOT assemble those layouts with chained `WriteString` / `Sprintf`. One-line messages and tight loops MAY keep `fmt` / `strings.Builder`. See [reference.md](reference.md#text-templates-for-reports).

**CONSTRAINT 14 — Structured logging.** Services and non-interactive commands MUST use an injected `internal/observability.Logger` (or the project's equivalent). MUST NOT use `fmt.Print*` or construct a new logger (`logrus.New()`, etc.) inside business logic. Interactive CLI MAY use pterm for operator UI. Error paths MUST log with discriminator fields (IDs, task/job names) then return the error (CONSTRAINT 4 / 6 still apply).
- Enforcement: Every new or changed log site uses the injected logger; scan for `fmt.Print` / `logrus.New` in services.
- Violation: STOP, inject the logger, replace the bypass, re-check.

CORRECT:
```go
s.logger.WithError(err).WithField("task", task).Error("generator failed.")
return err
```

PROHIBITED:
```go
fmt.Printf("generator failed: %v\n", err)
log := logrus.New()
```

**CONSTRAINT 15 — Process and LLM observability.** Process entrypoints that run LLM or outbound inference MUST initialize the project's OpenTelemetry tracer provider (see `internal/observability` or equivalent). When an OTLP endpoint env is set (`MAJORDOMO_OTEL_ENDPOINT`, `OTEL_EXPORTER_OTLP_ENDPOINT`, or the project's documented equivalent), MUST attach an OTLP exporter so client spans reach Phoenix/Arize (or the configured backend). Generate, evaluate, and other LLM hops MUST create OpenInference (or project-standard) spans around the library work, not only rely on an AI gateway's HTTP traces. Gateway-only visibility is NOT enough: hangs and parse failures after the HTTP response MUST still appear as client spans. When `defer` records span status from a named `err`, MUST assign with `err =` (never `err :=`) so failure status is preserved. See [reference-patterns.md](reference-patterns.md#observability-otel-and-logging) and review appendix pattern 14.
- Enforcement: Entrypoint init installs the tracer; LLM paths have span start/end; OTLP exporter wired when endpoint env is documented for the project; named-return span defers use `err =`.
- Violation: STOP, wire init/export and spans (or document why this binary has no LLM path), re-check.

CORRECT:
```go
otelCfg := observability.ResolveConfig(outputDir)
if _, err := observability.Init(otelCfg); err != nil {
    return err
}
// LLM generate/evaluate under OpenInference module interceptors / StartSpan
```

PROHIBITED:
```go
// Process calls Polypus/OpenAI with no tracer init and no client spans.
// "We can see it in the gateway UI" used as the only observability plan.
```

---

## Steps

1. **Load patterns** — Read [reference.md](reference.md) for templates.
2. **Implement** — Apply all 15 constraints during generation. First param on I/O functions: `ctx context.Context`.
3. **Self-check changed functions** — For each: resource deferred? errors wrapped and returned? context propagated? logger injected? LLM path spanned? PASS or fix.
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
- [ ] Typed domain error at each layer (code, op, Unwrap); persistence errors returned
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
- [ ] Injected structured logger; no `fmt.Print*` / ad-hoc logger in services
- [ ] LLM/inference entrypoints init OTEL; OTLP exporter when endpoint env set; client spans on generate/evaluate (not gateway-only)
