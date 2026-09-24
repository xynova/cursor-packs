---
name: golang-quality
description: >-
  Go generation and completion workflow: resource cleanup, error wrapping, nil
  guards, context propagation, CLI-service-client layering, structured logging,
  OpenTelemetry / OpenInference observability, config create constructors,
  outbound failsafe-go resilience, quality gates, self-documenting Makefile
  verb lists, shared Make verb names (build, test, serve), and HTTP/CLI
  service-layer error boundaries. Use when generating, completing, or fixing
  Go code, authoring a Makefile, or before claiming a Go change is done.
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

**CONSTRAINT 8 — Context propagated; nil and outbound deadlines fail closed.** NEVER replace a received `ctx` with `context.Background()`. Check `ctx.Done()` before expensive work. When a function or Options struct takes a `context.Context` (including optional `opts.Context` fields) for work that can cancel, time out, or call the network/LLM: IF that context is **nil** → return an error and MUST NOT substitute `context.Background()`. Callers MUST pass a non-nil context (usually with a deadline from the job entrypoint). Outbound hops that need a caller-supplied bound (HTTP `Do`, forge CLI / network `exec`, LLM/gateway calls, remote `git` push/fetch) MUST require `ctx.Deadline()` (or the request’s context deadline) **before** the call: IF missing → return an error and MUST NOT call the downstream. MUST NOT invent a fallback `time.Duration` / `http.Client.Timeout` / `WithTimeout` at the leaf to “save” a missing deadline. Process entrypoints and gateways MAY call `context.WithTimeout` / `WithDeadline` once to set the job budget; that is the caller bound, not a leaf fallback. See `.cursor/rules/go-outbound-resilience.mdc` and review Stage B.
- Enforcement: Stage 5 / Stage B greps for `if ctx == nil` / `if opts.Context == nil` followed by `context.Background()`; greps outbound packages for leaf `Timeout:` / `WithTimeout` when the hop’s `ctx` is unchecked; generation fails closed on nil and on missing deadline.
- Violation: STOP, return an error on nil context (no Background substitute), fail closed on missing deadline, move any budget `WithTimeout` to the caller/entrypoint, re-check.

CORRECT:
```go
if opts.Context == nil {
    return fmt.Errorf("dispatch: context is required")
}
if _, ok := opts.Context.Deadline(); !ok {
    return fmt.Errorf("outbound: missing deadline")
}
return client.Do(req.WithContext(opts.Context))
```

PROHIBITED:
```go
ctx := opts.Context
if ctx == nil {
    ctx = context.Background() // papers over a missing caller bound
}
timeout := 60 * time.Second
if d, ok := ctx.Deadline(); ok {
    timeout = time.Until(d)
}
// still calls Do when deadline was missing
c := &http.Client{Timeout: timeout}
```

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
Edit one pipeline-step instruction; only verification path is a 10-minute full-chain reseed.
Gate merge_ids by scraping markdown headings from a free-text field.
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

**CONSTRAINT 19 — Standard Go package layout.** Classify the module first, then place every new file. See [reference-patterns.md](reference-patterns.md#package-layout-library-vs-application). Host architecture rules (if present) take precedence for local forbids.
- **Kit** (consumed by other modules): MUST expose public API from `pkg/<domain>/` (or one exported root package). MUST keep hidden implementation in `internal/` (domain folders when there is more than a handful of packages). MUST put runnable examples in `examples/` or focused integration tests in `tests/`. MUST NOT put types other modules need under `internal/` (importers cannot use them).
- **Product kit** (ships `cmd/` binaries **and** is imported by hosts, CI, or smoke tools): MUST treat the **module as the product package**. MUST expose the stable public contract (`Serve`, `Smoke`, client helpers, and similar) from `pkg/<product>/` (or clearly named `pkg/...` packages). MUST keep thin entrypoints in `cmd/<bin>/`. MUST keep implementation, wiring, extension guts, and quality/smoke **runners** in `internal/`. MUST NOT invent a side-car “helper product” in `pkg/` while leaving the real product surface stuck under `internal/` forever when consumers need it. MUST NOT treat the module as scripts-plus-binary with no importable package when CI or hosts need one.
- **App-only** (produces `cmd` binaries; nothing outside the module imports it): MUST keep `cmd/<app>/main.go` as wiring only (flags, config/root, observability init, listen/`os.Exit`, one `Mount`/`Run` call). MUST put business logic and HTTP handlers under `internal/<domain>/`. MUST NOT put mux handlers, routing predicates, or domain logic in `package main`. MUST NOT add a mixed `pkg/` of host types “for cleanliness” when nothing imports this module. Prefer publishing reusable API from a kit or product-kit module rather than pretending an app-only tree is a library.
- **Placement:** MUST put new code in the domain directory that already owns that concern. MUST nest related packages under `internal/<domain>/` instead of adding another sibling at `internal/` root. MUST NOT create grab-bag packages (`util`, `common`, `helpers`, `shared`, `misc`, `tools`). MUST NOT scatter loose implementation `.go` files at the repo root. MUST NOT turn `internal/` into a flat dumping ground (dozens of sibling packages with no parent domain directories).
- Enforcement: Before adding a file, name kit vs product kit vs app-only; kits and product kits import from `pkg/`; app mains stay wiring-only; `ls internal/` shows domain folders, not a sibling forest; no new grab-bag names. Stage 5 scores the same detects.
- Violation: STOP, move the file to the owning domain (or `pkg/<domain>/` for kit/product-kit API), thin `main`, nest siblings, rename grab-bags; do not add a new top-level `internal/<leaf>` to dodge the nest.

CORRECT (kit):
```text
pkg/billing/           # other modules import this
internal/ledger/       # hidden
internal/validate/
examples/invoice/
```

CORRECT (product kit):
```text
pkg/product/           # Serve, Smoke — hosts and CI import this
internal/gateway/      # implementation
internal/smoke/        # quality probes (not the public product name)
cmd/product/
cmd/product-smoke/
```

CORRECT (app-only):
```text
cmd/invoice-api/main.go          # flags + listen + invoiceapi.Mount
internal/invoice/                # domain
internal/invoice/invoiceapi/     # HTTP mount
internal/pay/
```

PROHIBITED:
```text
# kit / product kit: public types only under internal/ (consumers cannot import)
internal/billing/client.go

# product kit: side-car helper in pkg/ while the real product stays stuck under internal/
pkg/smokehelper/
internal/product/serve.go

# product kit: scripts+binary only when CI/hosts need an importable package
cmd/product/ + scripts/ only; no pkg/

# app-only: fat main + flat internal forest
cmd/invoice-api/main.go          # mux, CORS, handlers, routing
internal/util/
internal/common/
internal/invoiceapi/             # sibling dump, no domain parent
internal/payapi/
internal/ledger/
internal/helpers/
```

**CONSTRAINT 20 — Makefile verb list.** When a Go module has a `Makefile`, bare `make` (and `make help`) MUST print every operator-facing target (verb) with a one-line description. MUST set `.DEFAULT_GOAL := help`. Every phony verb operators run (`format`, `lint`, `vet`, `test`, `build`, `serve`, license helpers, and similar) MUST carry a `## description` on the target line so the help recipe can list it. Recipe-only helpers MAY omit `##` so they stay off the list. MUST NOT ship a Makefile whose first response is "No targets" or a silent first recipe when quality or serve verbs exist. See [reference-patterns.md](reference-patterns.md#makefile-verb-list).
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

**CONSTRAINT 21 — Shared Make verbs.** When a Go module `Makefile` exposes operator verbs, MUST use the shared names below for those jobs. Help descriptions MUST be one short line. Product names and host paths MAY appear only in the host Makefile help text, never as pack-required brand strings. See [reference-patterns.md](reference-patterns.md#shared-make-verbs).

| Verb | Job |
|------|-----|
| `build` | Build Go binaries |
| `test` | Run Go tests |
| `vet` | `go vet ./...` |
| `tidy` | `go mod tidy` |
| `lint` | golangci-lint (skip or `go run` when not installed, per host) |
| `format` | gofumpt / goimports (or project formatter) |
| `ci` | When present: tidy + gofmt check + vet + race tests + build |
| `init` | When the app has a config file: create it under `~/.config/<app>/` (or `$XDG_CONFIG_HOME`) if missing |
| `serve` | Long-running local stack via process-compose (TUI; rebuild on change when air/hot-reload is wired) |
| `serve-down` | Stop this project's process-compose stack (preserve Docker named volumes; see process-compose-docker) |

- MUST: name the long-running local stack `serve` / `serve-down` when process-compose (or equivalent) is the up path
- MUST: keep host-only verbs (`smoke-*`, `docker-build`, `sync`, license helpers, and similar) in the host Makefile; MUST NOT invent pack constraints that require every host to ship them
- MUST NOT: use `dev` / `dev-down` as the only names for the long-running stack on a new or rewritten Makefile
- MAY: keep `dev` / `dev-down` as thin aliases that invoke `serve` / `serve-down` during migration
- Enforcement: Read `.PHONY` and `##` help lines; shared jobs use the table names; process-compose up/down are `serve` / `serve-down` (aliases optional)
- Violation: STOP, rename to shared verbs (add aliases if needed), re-run `make help`

CORRECT:
```makefile
serve: ## process-compose TUI; rebuilds on file changes
	./scripts/pc-up.sh

serve-down: ## Stop this process-compose project
	./scripts/pc-down.sh

# Optional migration alias (hidden or listed):
dev: serve
```

PROHIBITED:
```makefile
# Long-running stack only under a non-shared name:
dev: ## Start local stack
	process-compose up
dev-down:
	process-compose down
# no serve / serve-down
```

**CONSTRAINT 22 — Outbound resilience (failsafe-go).** Outbound process execution (`exec.Command`, `exec.CommandContext`, or a project exec wrapper) and outbound HTTP client calls (`http.Client.Do`, or equivalent) MUST run under [failsafe-go](https://pkg.go.dev/github.com/failsafe-go/failsafe-go) policies: retry with exponential backoff and jitter, plus a circuit breaker for shared network-backed dependencies (forge CLIs such as `gh`/`glab`, HTTP APIs, LLM endpoints). MUST honor the caller `context.Context` (stop when canceled or the deadline fires; MUST NOT invent a longer deadline than remaining budget). MUST classify retryable failures (timeout, process killed, transport errors, HTTP 429/5xx) versus permanent failures (bad argv, auth/config misuse, most other 4xx); MUST NOT blind-retry every non-zero exit or every HTTP status. MUST NOT scatter ad-hoc `time.Sleep` retry loops for outbound I/O. Local-only lookups that do not call a remote dependency (for example `exec.LookPath`) MAY stay unretriable. Test fakes that implement the exec/HTTP interface MAY omit failsafe. Standing Cursor rule: `.cursor/rules/go-outbound-resilience.mdc`. See [reference.md](reference.md#outbound-resilience-failsafe-go) and review appendix pattern 19.
- Enforcement: Stage 5 scans client/exec packages for bare `Do` / `Command` / `CommandContext` hops without a failsafe `Run` / `Get` (or project wrapper that embeds those policies); generation places policies at the shared exec/HTTP seam; when outbound hops are in scope Stage 5 MUST Read `go-outbound-resilience.mdc`.
- Violation: STOP, wrap the hop with failsafe-go (retry + breaker where the dep is shared/networked), classify retryable errors, re-check.

CORRECT:
```go
out, err := failsafe.With(breakerFor(name), retryPolicy).
    WithContext(ctx).
    Get(func() ([]byte, error) {
        return runOnce(ctx, name, args...)
    })
```

PROHIBITED:
```go
cmd := exec.CommandContext(ctx, "glab", args...)
err := cmd.Run() // bare outbound; no retry, no breaker
// or: for i := 0; i < 3; i++ { time.Sleep(...); if err := do(); err == nil { return } }
```

**CONSTRAINT 23 — HTTP and app entry map service-layer errors.** Inbound HTTP handlers, CLI command wiring, and other app entry packages (`internal/server`, `cmd/...` thin mains, gateway mux) MUST map status and operator messages from the **service / commands** package they call (typed domain error, `errors.Is` / `As` on that package’s sentinels or helpers). MUST NOT import a deeper kit or leaf package (`pkg/<kit>`, another domain’s internals) solely to `errors.Is` that leaf’s sentinel when the service hop already (or should) own the operation. The service layer MUST wrap or re-export leaf causes (`fmt.Errorf("%w", leafErr)` with a service sentinel, or `IsFoo(err) bool` on the service package) so entry code depends on one public error surface. Leaf packages MAY still define sentinels for their own callers; entry code reaches them only through `Unwrap` / `errors.Is` on the service-wrapped value, not by importing the leaf. See [reference-patterns.md](reference-patterns.md#error-wrapping-and-domain-errors) and CONSTRAINT 5.
- Enforcement: Stage 5 / Architecture scan entry packages for new imports of kit/leaf packages used only in `errors.Is`/`As` beside HTTP status mapping; generation wraps at the service hop first.
- Violation: STOP, add a service-layer sentinel or `Is*` helper, map that in HTTP/CLI, drop the leaf import from the entry package.

CORRECT:
```go
// pkg/dashboard (service/commands)
var ErrMutationCanceled = localgit.ErrMutationCanceled // or wrap with a dashboard sentinel

func IsMutationCanceled(err error) bool {
    return errors.Is(err, ErrMutationCanceled)
}

// internal/server
if dashboard.IsMutationCanceled(err) {
    http.Error(w, err.Error(), http.StatusGatewayTimeout)
    return true
}
```

PROHIBITED:
```go
// internal/server imports pkg/localgit only to map a sentinel the dashboard already returns
import "…/pkg/localgit"

if errors.Is(err, localgit.ErrMutationCanceled) {
    http.Error(w, err.Error(), http.StatusGatewayTimeout)
}
```

**CONSTRAINT 24 — Numbered SQL migrations.** When a Go module owns durable relational schema (Postgres or other SQL), MUST keep schema changes as numbered migration files (for example `migrations/000001_init.up.sql` / `.down.sql`, or an equivalent versioned directory) and apply **pending** versions once through a migrate path (open/store bootstrap, `migrate up` CLI, or equivalent). MUST record applied versions in a version table (or the chosen migrator’s bookkeeping). MUST NOT re-run ad-hoc `CREATE TABLE IF NOT EXISTS` / full DDL on every insert, publish, or request path. MUST NOT embed a growing one-shot schema string that is executed on each write. In-memory or throwaway test DBs MAY use create-if-not-exists when they never back durable production data. SQL driver packages (providers) SHOULD stay separate from domain packages that only need DTOs so non-SQL callers do not pull a database driver. See [reference-patterns.md](reference-patterns.md#numbered-sql-migrations).
- Enforcement: Stage 5 scans new or changed SQL schema / store open paths; flag DDL inside hot write paths and missing versioned migration dirs when durable tables are introduced.
- Violation: STOP, extract numbered migrations, apply pending once at bootstrap/migrate, keep write paths DML-only, re-check.

CORRECT:
```text
migrations/000001_conform_runs.up.sql
migrations/000001_conform_runs.down.sql
→ store Open / migrate CLI applies pending versions once
→ Publish / Insert only upserts rows
```

PROHIBITED:
```go
func (s *Store) Publish(...) error {
    _, err := s.db.Exec(schemaSQL) // full CREATE TABLE IF NOT EXISTS on every write
    // ...
}
```

**CONSTRAINT 25 — Injectable clocks.** Timestamps that affect durable state, fingerprints, ordering, manifests, or cache records (`CreatedAt`, `GeneratedAt`, job `Options.Now` consumers, identity filenames from unix nano) MUST come from an injected clock (`Options.Now`, `store.Now`, `Clock func() time.Time`, or equivalent). MUST NOT call `time.Now()` at those write sites. Process or job entrypoints MAY call `time.Now()` once to fill the injected clock when the caller omitted it. Leaf helpers and stores MUST NOT invent a wall-clock fallback when their clock field is zero or nil (fail closed). Latency and metrics timers that are not persisted as domain state MAY use local `time.Now()`. Standing Cursor rule: `.cursor/rules/go-injectable-clock.mdc`. See review Stage C and Stage 5.
- Enforcement: Stage 5 / Stage C greps `time.Now` next to durable stamp fields and `Store*` / manifest writers; generation places the job clock on Options and threads it; stores error when the clock is missing.
- Violation: STOP, inject the clock, remove leaf `time.Now()` fallbacks on durable stamps, re-check.

CORRECT:
```go
now := opts.Now
if now.IsZero() {
    now = time.Now().UTC() // job entry only
}
store := &DigestStore{Dir: dir, Now: now}
```

PROHIBITED:
```go
CreatedAt: time.Now().UTC().Format(time.RFC3339)
// or inside Store*: if s.Now.IsZero() { t = time.Now() }
```

---

## Steps

1. **Load patterns** — Read [reference.md](reference.md) for templates.
2. **Implement** — Apply all 25 constraints during generation. First param on I/O functions: `ctx context.Context`.
3. **Self-check changed functions** — For each: resource deferred? errors wrapped and returned? context propagated and outbound deadlines fail closed (C8)? logger injected? clock injected for durable stamps (C25)? LLM path spanned? AI dumps durable? Generator/evaluator isolatable (C17)? Multi-field construction uses config create (C18)? Package layout: kit vs product kit vs app-only classified and the new file sits in `pkg/<domain>/` or `internal/<domain>/` (C19)? If a Makefile exists or was edited: `make` lists every operator verb (C20) and shared jobs use shared names (C21)? Outbound exec/HTTP under failsafe-go with classified retries (C22)? HTTP/CLI map service-layer errors, not leaf kit sentinels (C23)? Durable SQL uses numbered migrations applied once, not DDL on every write (C24)? PASS or fix.
4. **Run quality gates** on changed packages. Prefer project Makefile targets when they exist; otherwise use the Go toolchain directly:

```bash
# Prefer (if Makefile defines them):
make          # or: make help — lists verbs (CONSTRAINT 20)
make format   # or: gofumpt -w . && goimports -w .
make lint     # or: golangci-lint run ./...
make vet      # or: go vet ./...
make test     # or: go test ./...
```

Scope to `./cmd/...` `./internal/...` `./pkg/...` (or the packages the project uses) when that is the local convention. If dependencies changed: `go mod tidy`.

Do NOT complete while any of these fail. Fix, re-run, then complete.

5. **Report** — Which constraints were verified and the command results.

---

## Pre-completion checklist

### Tooling

- [ ] Makefile help: if a `Makefile` exists, `make` / `make help` lists every operator verb (CONSTRAINT 20)
- [ ] Makefile shared verbs: shared jobs use `build` / `test` / `vet` / `tidy` / `lint` / `serve` / `serve-down` (and `init` / `ci` when applicable); no serve-only-as-`dev` (CONSTRAINT 21)
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
- [ ] HTTP/CLI map service-layer errors (C23); entry packages do not import kit/leaf packages only for `errors.Is` on leaf sentinels
- [ ] Constructor nil panics; pointer params nil-checked
- [ ] No `context.Background()` inside a function that already has `ctx`; nil `opts.Context` / param fails closed (no Background substitute); outbound hops fail closed without `ctx.Deadline()` (C8; no leaf Timeout fallback)
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
- [ ] Package layout (C19): kit vs product kit vs app-only classified; kit/product-kit API in `pkg/<domain>/`; thin `cmd/`; implementation and quality/smoke runners in `internal/`; no grab-bags or flat `internal/` forest
- [ ] AI work dumps (RLM TraceDir, runreport, inference-failure JSON) survive process exit; not only under `defer RemoveAll` scratch; path logged or returned
- [ ] Multi-field construction uses config create (`cfg.Create*` / `CreateModule`); no long parallel arg lists beside a half-empty Config
- [ ] Makefile verbs (C20–C21): help lists operators; shared jobs use shared names (`serve` not only `dev`)
- [ ] Outbound resilience (C22): exec/HTTP hops use failsafe-go (retry + breaker); no bare Do/Command; no ad-hoc sleep retry loops
- [ ] Error boundary (C23): inbound HTTP/CLI map service-package errors; no leaf-kit import only for sentinel checks
- [ ] SQL migrations (C24): durable schema uses numbered up/down (or equivalent) applied once; no full DDL on every write/publish path
- [ ] Injectable clocks (C25): durable stamps use injected `Now` / Clock; no leaf `time.Now()` on CreatedAt / manifests / cache Store*
