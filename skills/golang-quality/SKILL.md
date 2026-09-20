---
name: golang-quality
description: >-
  Go generation and completion workflow: resource cleanup, error wrapping, nil
  guards, context propagation, CLI-service-client layering, structured logging,
  OpenTelemetry / OpenInference observability, config create constructors,
  quality gates, and self-documenting Makefile verb lists. Use when generating,
  completing, or fixing Go code, or before claiming a Go change is done.
---

# Go Quality

Prevention-first Go workflow. This skill is the **procedure**. Project architecture / domain rules (if present) still apply.

**Deep reference:** [reference.md](reference.md) (full encyclopedia). **Compact patterns:** [reference-patterns.md](reference-patterns.md).

**Related:** `.cursor/skills/review-code-staged/SKILL.md` for staged review (**Stage 5** Generation Gates applies these Core constraints at review, not only while writing); `.cursor/skills/review-member-visibility/SKILL.md` for export audits. Report layouts: `.cursor/rules/go-structured-strings.mdc`.

### External readability baseline

Cite these for idiomatic Go taste. They are **not** a second checklist to score line-by-line.

- [Go Code Review Comments](https://go.dev/wiki/CodeReviewComments)
- [Uber Go Style Guide](https://github.com/uber-go/guide/blob/master/style.md)

**CONSTRAINT:** Agents MUST enforce and review against this skill's Core constraints (and project rules). MUST NOT fail a change solely because an external guide prefers a different spelling of the same idea. When promoting a house pattern (for example config create), MUST put it here as a numbered constraint so write-time and Stage 5 share one bar.
- Enforcement: Generation and Stage 5 checklists map to Core constraints 1–N only; external links appear as citations, not scored rows.
- Violation: STOP, score the house constraint (or add one), drop the raw external-guide finding.

CORRECT:
```text
Stage 5: fail C18 (config create). Citation: Uber/Code Review Comments favor clear constructors from config-shaped inputs.
```

PROHIBITED:
```text
Stage 5: 40 findings copied from Uber Go Style Guide sections with no map to C1–CN.
```

---

## When to load

- Generating or editing `.go` files
- Finishing a Go implementation, fix, or refactor
- User asks to lint, format, vet, or verify Go quality
- Staged review **Stage 5 (Generation Gates)** is running (load this skill and apply Core constraints as a detect checklist)

---

## Core constraints

Apply these **while writing** and again when staged review **Stage 5** runs. Do not treat review Stage 4 (clarity) as a substitute for these gates.

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

**CONSTRAINT 16 — Durable AI work dumps.** When a job writes RLM `TraceDir` JSONL, strop `runreport` JSON, olly-style inference-failure dumps, or equivalent AI work-story files, those paths MUST remain readable after the process exits. MUST NOT place the only copy under a directory removed by `defer os.RemoveAll` (analysis clones, digests cache worktrees, or other scratch trees). MUST log or return the durable root (flag, env, or result field) so operators can reopen traces without guessing OS temp paths. Spans (C15) do not replace on-disk dumps for local AI testing. See [reference-patterns.md](reference-patterns.md#durable-ai-work-dumps) and review appendix pattern 15. Strop wiring: `.cursor/skills/strop-pipeline-pattern/SKILL.md` (durable TraceDir / runreport).
- Enforcement: Trace every `MkdirTemp` / `RemoveAll` paired with TraceDir, runreport `Dir`, or failure-dump roots; confirm dumps land outside deleted trees; CLI/result exposes the path.
- Violation: STOP, move dumps to a durable work-story root (or copy before cleanup), log/return the path, re-check.

CORRECT:
```go
workStory := filepath.Join("tmp", "digest-runs", repoID+"-"+stamp)
rlmCfg.TraceDir = filepath.Join(workStory, "rlm-traces", task)
rrCfg.Dir = filepath.Join(workStory, "logs", "runs")
// analysisDir may still be MkdirTemp + RemoveAll; dumps do not live only there.
logf("INFO", "AI work story dir=%s", workStory)
```

PROHIBITED:
```go
analysisDir, _ := os.MkdirTemp("", "majordomo-typology-*")
defer os.RemoveAll(analysisDir)
rlmCfg.TraceDir = filepath.Join(analysisDir, "rlm-traces", task) // only copy, wiped on exit
// Operator has no work_story_dir / flag after a successful local run.
```

**CONSTRAINT 17 — AI module isolation and structured contracts.** When adding or changing a dspy-go generator or evaluator used in a pipeline, discrete machine outputs MUST be signature fields with structured XML (`dspy-xml-structured-output` §0 / §0.1). MUST provide or extend an env-gated live opt-in replay test that loads Process inputs from a module-trace / TraceDir fixture and runs that module alone, OR document in the PR why offline-only is enough for this change. MUST NOT rely on a full pipeline reseed as the only way to exercise the module. Keep C15 spans and C16 dumps on for live replay. See `.cursor/skills/dspy-pipeline-isolation/SKILL.md` and review appendix pattern 16.
- Enforcement: For staged generator/evaluator/signature diffs, search for `LIVE_` / env `Skip` + `Generate(` / `Evaluate(`; confirm gates read typed signature fields, not scraped `*_md`.
- Violation: STOP, add structured fields and/or opt-in live replay (or write the offline-only rationale), re-check.

CORRECT:
```text
testdata/<task>_span.json from module-traces → offline zip gate →
MAJORDOMO_LIVE_<TASK>_REPLAY=1 go test -run Live… → then rejoin JobRunner.
```

PROHIBITED:
```text
Edit typology_cluster instruction; only verification path is a 10-minute full digest reseed.
Gate merge_ids by scraping cluster_proposal_md headings.
```

**CONSTRAINT 18 — Config create.** When a type needs several construction inputs (deps, budgets, prompts, optional hooks), MUST put them on a typed `Config` (or `*Config`) and expose `CreateX` / `CreateModule` that takes no construction args beyond what the method signature already needs for runtime (`ctx` only when creation itself performs I/O). Call sites MUST fill the config, then call create. MUST NOT pass a long parallel argument list beside a half-empty config. Prefer this over ad-hoc `NewFoo(a, b, c, d, e)` when the same bundle is reused or will grow. Package-level `CreateFoo(cfg)` MAY wrap `cfg.CreateFoo()` for discoverability.
- Enforcement: New multi-field constructors use config create; scan for `Create*` / `New*` with ≥4 related parameters that already have a Config type.
- Violation: STOP, move fields onto Config, add `Create*`, update call sites.

CORRECT:
```go
cfg := stropdspy.RLMDefaults()
cfg.LLM = llm
cfg.Timeout = timeout
cfg.TraceDir = traceDir
module, err := cfg.CreateModule()
```

PROHIBITED:
```go
module, err := stropdspy.CreateRLMModule(llm, rlmCfg) // llm already belongs on the config
NewClient(url, token, timeout, retries, logger, tracer, metrics) // no Config
```

**CONSTRAINT 19 — Standard Go package layout.** Classify the module first, then place every new file. See [reference-patterns.md](reference-patterns.md#package-layout-library-vs-application). Host architecture rules (if present) take precedence for local forbids such as "this app module MUST NOT grow a mixed `pkg/`".
- **Kit** (consumed by other modules): MUST expose public API from `pkg/<domain>/` (or one exported root package). MUST keep hidden implementation in `internal/` (domain folders when there is more than a handful of packages). MUST put runnable examples in `examples/` or focused integration tests in `tests/`. MUST NOT put types other modules need under `internal/` (importers cannot use them).
- **App** (produces `cmd` binaries): MUST keep `cmd/<app>/main.go` as wiring only (flags, config/root, observability init, listen/`os.Exit`, one `Mount`/`Run` call). MUST put business logic and HTTP handlers under `internal/<domain>/`. MUST NOT put mux handlers, routing predicates, or domain logic in `package main`. MUST NOT add a mixed `pkg/` of host types unless this module is also a published kit. MUST publish reusable API from a kit module rather than mixing `pkg/` into an app.
- **Placement:** MUST put new code in the domain directory that already owns that concern. MUST nest related packages under `internal/<domain>/` instead of adding another sibling at `internal/` root. MUST NOT create grab-bag packages (`util`, `common`, `helpers`, `shared`, `misc`, `tools`). MUST NOT scatter loose implementation `.go` files at the repo root. MUST NOT turn `internal/` into a flat dumping ground (dozens of sibling packages with no parent domain directories).
- Enforcement: Before adding a file, name kit vs app; kits import from `pkg/`; app mains stay wiring-only; `ls internal/` (or the module's internal root) shows domain folders, not a sibling forest; no new grab-bag names. Stage 5 scores the same detects.
- Violation: STOP, move the file to the owning domain (or `pkg/<domain>/` for kit API), thin `main`, nest siblings, rename grab-bags; do not add a new top-level `internal/<leaf>` to dodge the nest.

CORRECT (kit):
```text
pkg/billing/           # other modules import this
internal/ledger/       # hidden
internal/validate/
examples/invoice/
```

CORRECT (app):
```text
cmd/invoice-api/main.go          # flags + listen + invoiceapi.Mount
internal/invoice/                # domain
internal/invoice/invoiceapi/     # HTTP mount
internal/pay/
```

PROHIBITED:
```text
# kit: public types only under internal/ (consumers cannot import)
internal/billing/client.go

# app: fat main + flat internal forest
cmd/invoice-api/main.go          # mux, CORS, handlers, routing
internal/util/
internal/common/
internal/invoiceapi/             # sibling dump, no domain parent
internal/payapi/
internal/ledger/
internal/helpers/
```

**CONSTRAINT 20 — Makefile verb list.** When a Go module has a `Makefile`, bare `make` (and `make help`) MUST print every operator-facing target (verb) with a one-line description. MUST set `.DEFAULT_GOAL := help`. Every phony verb operators run (`format`, `lint`, `vet`, `test`, `build`, `dev`, license helpers, and similar) MUST carry a `## description` on the target line so the help recipe can list it. Recipe-only helpers MAY omit `##` so they stay off the list. MUST NOT ship a Makefile whose first response is "No targets" or a silent first recipe when quality or dev verbs exist. See [reference-patterns.md](reference-patterns.md#makefile-verb-list).
- Enforcement: From the module root, run `make` (or `make help`); every operator verb in `.PHONY` that humans run appears with a description; `.DEFAULT_GOAL` is `help`.
- Violation: STOP, add `.DEFAULT_GOAL := help`, annotate missing verbs with `##`, wire the help recipe, re-run `make`.

CORRECT:
```makefile
.DEFAULT_GOAL := help

.PHONY: help test build

help: ## List available make verbs
	@grep -E '^[a-zA-Z0-9_-]+:.*?## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  %-24s %s\n", $$1, $$2}'

test: ## Run unit tests
	go test ./...

build: ## Build the binary into bin/
	go build -o bin/app ./cmd/app
```

PROHIBITED:
```makefile
# No help, no DEFAULT_GOAL; bare `make` errors or runs an opaque first target.
.PHONY: test build
test:
	go test ./...
build:
	go build -o bin/app ./cmd/app
```

---

## Steps

1. **Load patterns** — Read [reference.md](reference.md) for templates.
2. **Implement** — Apply all 20 constraints during generation. First param on I/O functions: `ctx context.Context`.
3. **Self-check changed functions** — For each: resource deferred? errors wrapped and returned? context propagated? logger injected? LLM path spanned? AI dumps durable? Generator/evaluator isolatable (C17)? Multi-field construction uses config create (C18)? Package layout: kit vs app classified and the new file sits in `pkg/<domain>/` or `internal/<domain>/` (C19)? If a Makefile exists or was edited: `make` lists every operator verb (C20)? PASS or fix.
4. **Run quality gates** on changed packages. Prefer project Makefile targets when they exist; otherwise use the Go toolchain directly:

```bash
# Prefer (if Makefile defines them):
make          # or: make help — lists verbs (CONSTRAINT 20)
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

- [ ] Makefile help: if a `Makefile` exists, `make` / `make help` lists every operator verb (CONSTRAINT 20)
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
- [ ] AI work dumps (RLM TraceDir, runreport, inference-failure JSON) survive process exit; not only under `defer RemoveAll` scratch; path logged or returned
- [ ] Multi-field construction uses config create (`cfg.Create*` / `CreateModule`); no long parallel arg lists beside a half-empty Config
- [ ] Package layout (C19): kit vs app classified; kit API in `pkg/<domain>/`; app `main` is wiring only; new files sit in the owning `internal/<domain>/` (not a new root sibling or grab-bag)
