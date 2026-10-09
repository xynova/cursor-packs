# Go patterns (compact)

Load from `golang-quality`. Full encyclopedia: [reference.md](reference.md).

Project architecture rules (if present) still apply.

---


## Resource management

### HTTP response body

```go
resp, err := client.Do(req)
if err != nil {
    return fmt.Errorf("request failed: %w", err)
}
defer resp.Body.Close()

var result MyResponse
if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
    return fmt.Errorf("failed to decode response: %w", err)
}
```

- MUST call `defer resp.Body.Close()` on the line immediately after the error check.
- NEVER read `resp.Body` without a preceding defer close.

### Context with timeout

```go
ctx, cancel := context.WithTimeout(parentCtx, 5*time.Second)
defer cancel()

if err := client.SendMessage(ctx, agentID, msgs); err != nil {
    return fmt.Errorf("failed to send message: %w", err)
}
```

- MUST defer `cancel()` immediately after `WithTimeout` / `WithCancel` / `WithDeadline`.
- Outbound hops that need a caller bound MUST fail closed when `ctx` has no deadline (golang-quality CONSTRAINT 8 / `go-outbound-resilience.mdc`). MUST NOT invent a leaf `http.Client.Timeout` or `WithTimeout` to cover a missing deadline; set the budget at the process/job entrypoint instead.
- MUST NOT substitute `context.Background()` when a context parameter or `opts.Context` is nil. Fail closed with an error; callers pass a non-nil (usually deadline-bearing) context.

```go
if opts.Context == nil {
    return fmt.Errorf("run: context is required")
}
if _, ok := ctx.Deadline(); !ok {
    return fmt.Errorf("outbound: missing deadline")
}
```

### Injectable clocks

Durable and test-sensitive timestamps MUST use an injected clock (golang-quality CONSTRAINT 25 / `.cursor/rules/go-injectable-clock.mdc`). Job entry MAY call `time.Now()` once to fill `opts.Now`; leaves MUST NOT.

```go
now := opts.Now
if now.IsZero() {
    now = time.Now().UTC()
}
store := &DigestStore{Dir: dir, Now: now}
```

### Database transaction

```go
tx, err := db.Begin(ctx)
if err != nil {
    return fmt.Errorf("failed to begin transaction: %w", err)
}
defer tx.Rollback(ctx) // no-op if Commit succeeds

if err := tx.Commit(ctx); err != nil {
    return fmt.Errorf("failed to commit transaction: %w", err)
}
```

- MUST defer `tx.Rollback(ctx)` immediately after `Begin`.
- NEVER begin a transaction without a deferred rollback.

### File resource

```go
file, err := os.Open(filePath)
if err != nil {
    return fmt.Errorf("failed to open file: %w", err)
}
defer file.Close()
```

---

## Error handling

### Typed domain error at each hop

MUST wrap the incoming cause in a typed domain error (stable code, layer `op`, message, optional fields, `Unwrap`). The `code` argument MUST be an exported `Code*` constant (C5), not a string literal or HTTP status int. Go has no Java-style stack on error values; the Unwrap chain plus fields is the breadcrumb.

```go
if err != nil {
    return errors.Wrap(err, errors.CodeUnavailable, "cloudflare.Synthesize", "post /run").
        With("backend", backendID)
}
```

`NewDomainError(code, message, cause)` is the same wrap when `op` is empty.

- MUST wrap at every layer that can fail (client → plugin/service → gateway).
- MUST NOT return `err` bare.
- MUST NOT stringify with `err.Error()` and drop `errors.Is` / `As`.
- `fmt.Errorf("%w")` MAY wrap a stdlib cause at the leaf, then MUST convert to a domain error before leaving the package.
- Inbound HTTP / CLI entry packages MUST map **service-layer** errors (CONSTRAINT 23). MUST NOT import a deeper kit package solely to `errors.Is` that kit’s sentinel when the service hop owns the call.

CORRECT (entry maps service helper):
```go
if dashboard.IsMutationCanceled(err) {
    http.Error(w, err.Error(), http.StatusGatewayTimeout)
}
```

PROHIBITED (entry imports kit leaf for the same check):
```go
import "…/pkg/localgit"
if errors.Is(err, localgit.ErrMutationCanceled) { /* … */ }
```

PROHIBITED:
```go
return err
return fmt.Errorf("post /run: %s", err.Error())
```

### Persistence errors MUST be returned

```go
if err := contextService.AddTranslationVersion(ctx, evalContext, version, translation); err != nil {
    logger.WithError(err).Error("Failed to persist evaluation results to shared context.")
    return fmt.Errorf("evaluation succeeded but failed to persist results: %w", err)
}
```

- MUST return the error — NEVER log-only when persistence fails.
- Continuing after a persistence failure causes state inconsistency and infinite loops.

### Log-only only inside defer

```go
defer func() {
    if err := file.Close(); err != nil {
        logger.WithError(err).Warn("Failed to close file in defer.")
    }
}()
```

Logging MUST use injected `*observability.Logger`. NEVER `fmt.Print*` or `logrus.New()` for logs.

---

## Nil safety

### Constructor nil guards

```go
func NewService(client ClientInterface, logger *observability.Logger) *Service {
    if client == nil {
        panic("client cannot be nil")
    }
    if logger == nil {
        panic("logger cannot be nil")
    }
    return &Service{client: client, logger: logger}
}
```

- MUST panic on nil for every required dependency in the constructor.

### Nil check at public API boundaries

```go
func Process(config *Config) error {
    if config == nil {
        return fmt.Errorf("config cannot be nil")
    }
    timeout := config.Timeout
    _ = timeout
    return nil
}
```

- Return an error (not panic) for nil inputs at public API boundaries.

---

## Context

### Check cancellation before expensive work

```go
func Process(ctx context.Context) error {
    select {
    case <-ctx.Done():
        return ctx.Err()
    default:
    }
    return client.SendMessage(ctx, agentID, msgs)
}
```

- MUST propagate `ctx` to all callees — NEVER substitute `context.Background()`.

### Long-running loop

```go
func (s *Service) LongRunningTask(ctx context.Context) error {
    ticker := time.NewTicker(1 * time.Second)
    defer ticker.Stop()

    for {
        select {
        case <-ctx.Done():
            return ctx.Err()
        case <-ticker.C:
            if err := s.doWork(ctx); err != nil {
                return fmt.Errorf("work iteration failed: %w", err)
            }
        }
    }
}
```

---

## Dependency injection

Primary pattern: constructor injection. Wire from `internal/container` (or the pipeline container). NEVER instantiate clients or loggers inside business logic.

When construction needs a growing bundle of fields (prompts, budgets, optional hooks, resolved deps), use **config create** (golang-quality CONSTRAINT 18): fill a typed `Config`, then `cfg.CreateX()` / `cfg.CreateModule()`.

```go
type Service struct {
    db     DatabaseClient
    logger *observability.Logger
}

func NewService(db DatabaseClient, logger *observability.Logger) *Service {
    if db == nil {
        panic("db cannot be nil")
    }
    if logger == nil {
        panic("logger cannot be nil")
    }
    return &Service{db: db, logger: logger}
}
```

Config create (when the constructor would grow past a few clear deps):

```go
cfg := RLMDefaults()
cfg.LLM = llm
cfg.TraceDir = traceDir
module, err := cfg.CreateModule()
```

- MUST inject ALL dependencies via constructor.
- MUST use interfaces for external dependencies (HTTP, DB, APIs).
- Outbound HTTP `Do` and process `exec.Command*` MUST use failsafe-go (CONSTRAINT 22); see [reference.md](reference.md#outbound-resilience-failsafe-go).
- Concrete types are acceptable for a single stable adapter (see architecture DI notes).
- MUST prefer config create over a long `NewFoo(a, b, c, d, e)` list when the same bundle is reused or will grow.

## Package layout (library vs application)

**LOAD-WHEN:** adding a Go file, a new package, a `cmd` binary, or reviewing layout (golang-quality C19 / staged review Stage 5).

Classify the module, then place the file. Host architecture rules (if present) win for local forbids.

### Classify

| Kind | Signal | Public API |
|------|--------|------------|
| Kit | Other modules import this `go.mod` | `pkg/<domain>/` (or one exported root package) |
| Product kit | Ships `cmd/` **and** hosts/CI/smoke import this module | `pkg/<product>/` for Serve/Smoke/client surfaces; `internal/` for implementation and quality runners |
| App-only | This module's `cmd/` is the product; nothing outside imports it | `internal/<domain>/` only; no mixed `pkg/` “for cleanliness” |

MUST NOT invent a side-car helper in `pkg/` while the real product stays under `internal/` when consumers need the product. MUST NOT treat a product kit as scripts-plus-binary with no importable package when CI or hosts need one. MUST NOT treat an app-only module as a kit by adding unused `pkg/` “for cleanliness.”

### Kit tree

```text
pkg/<domain>/
internal/<hidden>/
examples/
tests/
```

MUST export what consumers import from `pkg/<domain>/`. MUST NOT put those types only under `internal/`. Hidden `internal/` MUST still use domain folder names when there is more than a handful of packages.

### Product kit tree

```text
pkg/<product>/          # stable public contract (Serve, Smoke, …)
cmd/<product>/
cmd/<product>-smoke/    # thin CLI over pkg
internal/<domain>/      # gateway, router, extensions
internal/smoke/         # quality probes (implementation)
```

MUST keep `cmd/` as wiring only. Quality and smoke **runners** stay in `internal/`; the **product** façade they serve sits in `pkg/<product>/`.

### App-only tree

```text
cmd/<app>/main.go
internal/<domain>/
internal/<domain>/<pkg>/
```

`package main` MUST stay wiring: flags, config/root, observability init, listen / `os.Exit`, one `Mount` / `Run` call. MUST NOT put ServeMux handlers, routing predicates, or domain logic in `main`. HTTP *handlers* belong under `internal/<domain>/` (mount/run packages). Outbound HTTP *clients* still follow C10 (`internal/clients/<service>/` or the project's client packages).

### Placement (authors)

MUST put a new file in the domain directory that already owns that concern. MUST nest a new related package under `internal/<domain>/` instead of adding another sibling at `internal/` root. MUST NOT create `util`, `common`, `helpers`, `shared`, `misc`, or `tools`. MUST NOT leave loose implementation `.go` files at the repo root.

A **dumping ground** is `internal/` as a flat forest: many sibling packages, no parent domain directories. MUST nest before the listing becomes a scroll of unrelated leaves. Dozens of siblings is already a fail; do not wait for a hard count.

CORRECT (product kit):

```text
pkg/product/
internal/gateway/
internal/smoke/
cmd/product/
cmd/product-smoke/
```

CORRECT (app-only):

```text
cmd/invoice-api/main.go
internal/invoice/invoiceapi/
internal/pay/
```

PROHIBITED (product kit side-car / stuck internal):

```text
pkg/smokehelper/       # helper-only pkg while product is not importable
internal/product/      # Serve only here; CI cannot import
```

PROHIBITED (app dumping ground + fat main):

```text
cmd/invoice-api/main.go    # handlers and CORS in main
internal/util/
internal/invoiceapi/
internal/payapi/
internal/ledger/
internal/helpers/
```

---

## Architecture (CLI → Service → Client)

```go
// CLI — delegates only.
func (c *Command) Execute(ctx context.Context) error {
    return c.service.SetupAgents(ctx)
}

// Service — business logic, injected client.
func (s *Service) SetupAgents(ctx context.Context) error {
    resource, err := s.apiClient.Create(ctx, config)
    if err != nil {
        return fmt.Errorf("failed to create agent resource: %w", err)
    }
    return nil
}

// Client — HTTP only, internal/clients/<service>/.
func (c *APIClient) Create(ctx context.Context, cfg AgentConfig) (*Resource, error) {
    req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+"/v1/agents", body)
    if err != nil {
        return nil, fmt.Errorf("failed to build create request: %w", err)
    }
    resp, err := c.httpClient.Do(req)
    if err != nil {
        return nil, fmt.Errorf("create agent request failed: %w", err)
    }
    defer resp.Body.Close()
    return decode(resp)
}
```

- CLI MUST only call service methods.
- Services MUST NOT call `http` directly.
- HTTP MUST live in `internal/clients/<service>/` (or a pipeline HTTP client package).

---

## Interface segregation (ISP)

```go
type SayingRepository interface {
    Create(ctx context.Context, s *Saying) error
    GetByID(ctx context.Context, id uuid.UUID) (*Saying, error)
    Update(ctx context.Context, s *Saying) error
    Delete(ctx context.Context, id uuid.UUID) error
}

type TranslationRepository interface {
    Create(ctx context.Context, t *Translation) error
    GetByID(ctx context.Context, id uuid.UUID) (*Translation, error)
    Update(ctx context.Context, t *Translation) error
    Delete(ctx context.Context, id uuid.UUID) error
}

type TranslationService struct {
    sayings      SayingRepository
    translations TranslationRepository
}
```

- Maximum 5–6 methods per interface.
- Services MUST declare only the interfaces they use.
- Prefer generics over `any` / `interface{}` when a type parameter fits:

```go
type Cache[T any] interface {
    Get(key string) (T, bool)
    Set(key string, value T) error
    Delete(key string) error
}
```

---

## Testing

```go
func TestService_ProcessData(t *testing.T) {
    mockDB := &MockDatabaseClient{
        QueryFn: func(ctx context.Context, sql string, args ...any) ([]Row, error) {
            return []Row{{Data: "test"}}, nil
        },
    }
    logger := observability.NewLogger("debug")
    svc := NewService(mockDB, logger)

    err := svc.ProcessData(context.Background(), []byte("test"))
    if err != nil {
        t.Fatalf("unexpected error: %v", err)
    }
}
```

- MUST mock external dependencies. NEVER hit real APIs or DBs in unit tests.
- Test names: `Test<Type>_<Method>_<Scenario>`.

```go
func setupTestDB(t *testing.T) DatabaseClient {
    t.Helper()
    db, err := database.NewTestClient(context.Background())
    if err != nil {
        t.Fatalf("failed to set up test database: %v", err)
    }
    t.Cleanup(func() { db.Close() })
    return db
}
```

- MUST call `t.Helper()` in test helpers.
- MUST use `t.Cleanup` instead of `defer` for teardown in helpers.

---

## Performance

### Pre-allocate slices

```go
items := make([]Item, 0, len(input))
for _, v := range input {
    items = append(items, Item{Value: v})
}
```

### Batch instead of N+1

```go
agents, err := client.ListAgents(ctx)
if err != nil {
    return fmt.Errorf("failed to list agents: %w", err)
}
agentMap := make(map[string]*Agent, len(agents))
for _, a := range agents {
    agentMap[a.ID] = a
}
```

PROHIBITED: one `GetByID` per ID in a loop when a list/batch exists.

### Large structs by pointer

Pass and return structs with 3+ fields as pointers.

---

## Text templates for reports

Use `text/template` when the output is a multi-line human layout (poll summary, ASCII diagram, status board). Keep a typed view model; put the diagram shape in one `const` template string.

```go
type summaryData struct {
    Configured int
    Pending    int
    Repos      []repoRow
}

const summaryTmpl = `========== summary ==========
 repos : {{.Configured}}
 pending: {{.Pending}}
{{- range .Repos}}
   {{printf "%-24s %s" .ID .Status}}
{{- end}}
==============================
`

var summaryTemplate = template.Must(template.New("summary").Parse(summaryTmpl))

func formatSummary(data summaryData) (string, error) {
    var b bytes.Buffer
    if err := summaryTemplate.Execute(&b, data); err != nil {
        return "", fmt.Errorf("render summary: %w", err)
    }
    return b.String(), nil
}
```

- MUST prefer `text/template` for multi-line operator-facing reports (poll summaries, ASCII diagrams, status boards).
- CLI inspect/status/doctor stdout MAY use labeled `writeln` sections per `cli-command-surface` C9–C10; MUST still keep `--json` stable when the command has a report object.
- MUST NOT build diagram/summary layouts with chained `WriteString` / many `Sprintf` calls.
- MAY use `fmt` / `strings.Builder` for single-line log lines and tight loops.
- SHOULD parse with `template.Must` at package init when the template is static.
- Example in-tree: `internal/poll/summary.go`.

---

## Observability (OTEL and logging)

### Structured logger injection

```go
func NewService(client ClientInterface, logger *observability.Logger) *Service {
    if client == nil {
        panic("client cannot be nil")
    }
    if logger == nil {
        panic("logger cannot be nil")
    }
    return &Service{client: client, logger: logger}
}
```

- MUST inject `*observability.Logger` (or project equivalent). NEVER `fmt.Print*` or `logrus.New()` in services.
- Log error paths with discriminator fields, then return the error.

### Process tracer init and OTLP export

```go
otelCfg := observability.ResolveConfig(outputDir)
if _, err := observability.Init(otelCfg); err != nil {
    return fmt.Errorf("otel init: %w", err)
}
```

- Process entrypoints that call LLMs MUST initialize the tracer provider.
- When `MAJORDOMO_OTEL_ENDPOINT` / `OTEL_EXPORTER_OTLP_ENDPOINT` / `POLYPUS_OTLP_ENDPOINT` (Polypus Phoenix; see `ask-polypus` **Dev env**) or project equivalent is set, MUST export via OTLP so Phoenix/Arize receives client spans.
- Local failure dumps without OTLP MAY still run; they do not replace OTLP when operators expect Phoenix.

### Client spans on LLM hops (not gateway-only)

- Generate, evaluate, and parse paths MUST create OpenInference (or project-standard) spans around library work.
- An AI gateway's HTTP spans (request size, status, model) are NOT sufficient observability for client hangs after the response.
- When `defer` ends a span from named `(err error)`, assign with `err =` so status records the failure.

CORRECT:
```go
func (r *Runtime) Generate(ctx context.Context, task string, fields map[string]interface{}, version int) (out map[string]interface{}, err error) {
    ctx, span := observability.StartSpan(ctx, "judge.Generate")
    defer observability.EndSpanWithStatus(span, &err)
    out, err = r.runner.Generate(ctx, task, fields, version)
    return out, err
}
```

PROHIBITED:
```go
// Call Polypus/OpenAI with no process tracer and no client span.
// Treat gateway UI timing as proof the client path is healthy.
```

### Durable AI work dumps

When the job enables RLM `TraceDir`, strop `runreport`, or olly-style inference-failure dumps, operators MUST be able to reopen those files after exit. Spans and Phoenix do not replace local JSONL/JSON for AI testing.

- MUST write dumps to a durable root (project `tmp/...` run dir, explicit flag/env, or documented work-story path).
- MUST NOT keep the only copy under `MkdirTemp` + `defer os.RemoveAll` analysis/cache worktrees.
- MUST log or return the durable root on the operator path (CLI flag, result JSON field, or INFO line).
- Teaching/context branches are separate: do not commit TraceDir/runreport into product teaching trees unless the project explicitly says so.

CORRECT:
```go
workStory := resolveWorkStoryDir(opts) // survives analysis cleanup
rlmCfg.TraceDir = filepath.Join(workStory, "rlm-traces", task)
runReport.Dir = filepath.Join(workStory, "logs", "runs")
```

PROHIBITED:
```go
defer os.RemoveAll(analysisDir)
rlmCfg.TraceDir = filepath.Join(analysisDir, "rlm-traces", task)
// Successful local run leaves no traces for the next debugging session.
```

### AI module isolation (generators and evaluators)

When changing a dspy-go generator or evaluator in a pipeline, isolate that step before rejoining JobRunner. Full detail: `.cursor/skills/dspy-pipeline-isolation/SKILL.md` (golang-quality C17).

- MUST keep discrete contracts as structured signature fields (not scraped `*_md`).
- MUST capture Process inputs from module-traces / TraceDir into testdata (or document the dump path).
- MUST add or extend env-gated live `Generate`/`Evaluate` for that task when the module is touched, or document why offline-only is enough.
- MUST NOT treat a full pipeline reseed as the only exercise path.

CORRECT:
```text
module-traces → testdata span → offline gate in default go test →
LIVE_<TASK>_REPLAY=1 live Generate/Evaluate → then JobRunner chain.
```

PROHIBITED:
```text
Prompt edit verified only by a multi-minute end-to-end reseed.
```

---

## Config create

House name for fill-a-config-then-construct. Full rule: CONSTRAINT 18 in [SKILL.md](SKILL.md). DSPy examples: `.cursor/skills/dspy-module-patterns/SKILL.md` (Config create). External taste: Go Code Review Comments and Uber Go Style Guide (cited in SKILL.md); score C18, not those guides as a second list.

```go
cfg := stropdspy.RLMDefaults()
cfg.LLM = llm
cfg.Timeout = timeout
cfg.TraceDir = traceDir
module, err := cfg.CreateModule()
```

- MUST put related construction inputs on a typed `Config`.
- MUST expose `CreateX` / `CreateModule` (no long parallel arg list beside the config).
- `ctx` on create ONLY when creation itself performs I/O.
- Package-level `CreateFoo(cfg)` MAY wrap `cfg.CreateFoo()`.

PROHIBITED:
```go
module, err := CreateRLMModule(llm, rlmCfg) // llm belongs on cfg
NewClient(url, token, timeout, retries, logger, tracer)
```

---

## Import organization

```go
import (
    "context"
    "fmt"
    "time"

    "github.com/google/uuid"
    "github.com/spf13/cobra"

    "github.com/xynova/content-pipelines/internal/config"
    "github.com/xynova/content-pipelines/internal/observability"
)
```

- Group: stdlib → third-party → internal, blank lines between groups.
- `make format` runs `go tool gofumpt` (and `goimports` only when the host already uses it).

---

## Go module tools (lint and format)

LOAD-WHEN: scaffolding or editing `go.mod`, `.golangci.yml`, `Taskfile.yml`, `make lint` / `go tool task lint`; golang-quality **CONSTRAINT 11**; staged review Stage 1.

### Rules

- MUST pin `github.com/golangci/golangci-lint/v2/cmd/golangci-lint` and `mvdan.cc/gofumpt` with `go get -tool` (Go 1.24+ `tool` directive).
- User programs (`./cmd/...`): MUST ship root `Taskfile.yml` (version `"3"`); MUST pin `github.com/go-task/task/v3/cmd/task`; listed tasks `format`, `lint`, `vet`, `test`, `build` (C20–C21).
- Library modules: MAY ship root `Makefile` with `help`, `format`, `lint`, `vet`, `test`, `build` when applicable.
- MUST ship root `.golangci.yml` with `version: "2"`.
- MUST enable golangci linters `errorlint`, `exhaustive`, `goconst`, `gocognit`, `gosec`, and `godot`, and formatter `gofumpt`.
- MUST set `gocognit` `min-complexity` explicitly (`20` for new modules; existing hosts MAY raise it until debt is paid).
- MUST invoke those binaries via `go tool` from Task or Make recipes; operators run `go tool task lint` or `make lint`, not bare PATH `golangci-lint`.
- Listed Task recipes MUST use forward slashes, `{{exeExt}}` for binaries, Task `vars:` / `env:` (no `mkdir -p`, `rm`, `export`, heredocs).
- MUST NOT treat a PATH `golangci-lint` / `gofumpt` as the default when `go.mod` has `tool` pins.
- MUST NOT require standalone `gosec` or `gocyclo` binaries.
- MUST NOT lint nested provider or submodule trees from the host config (scope `./cmd/...` `./internal/...` `./pkg/...` when those exist).
- NEVER: add golangci-lint to `require` as a runtime library.

CORRECT:
```makefile
lint: ## Run golangci-lint
	go tool golangci-lint run --timeout 5m ./cmd/... ./internal/...

format: ## Format with gofumpt
	go tool gofumpt -w ./cmd ./internal
```

```yaml
version: "2"

linters:
  enable:
    - errorlint
    - exhaustive
    - gocognit
    - goconst
    - godot
    - gosec
  settings:
    errorlint:
      errorf: true
      asserts: true
      comparison: true
    exhaustive:
      default-signifies-exhaustive: false
    goconst:
      min-len: 3
      min-occurrences: 3
    gocognit:
      min-complexity: 20
    godot:
      period: true
      capital: true

formatters:
  enable:
    - gofumpt
```

```yaml
version: "3"
vars:
  BIN: bin/app{{exeExt}}
tasks:
  default:
    desc: List local-dev tasks
    silent: true
    cmds:
      - go tool task --list
      - |
        echo ""
        echo "  1. go tool task init"
        echo "  2. go tool task serve"
  lint:
    desc: Run golangci-lint
    summary: |
      Runs go tool golangci-lint on ./cmd/... ./internal/....
      Host-only listed extras MAY use domain:verb (example: db:migrate).
    cmds:
      - go tool golangci-lint run --timeout 5m ./cmd/... ./internal/...
```

```text
go get -tool github.com/golangci/golangci-lint/v2/cmd/golangci-lint
go get -tool mvdan.cc/gofumpt
go get -tool github.com/go-task/task/v3/cmd/task
```

PROHIBITED:
```makefile
lint: ## Run golangci-lint
	golangci-lint run
```

```text
brew install gocyclo gosec
# no .golangci.yml; PATH golangci-lint only
```

---

## Taskfile verb list

LOAD-WHEN: authoring or editing a user-program `Taskfile.yml`; Stage 5 / golang-quality CONSTRAINT 20.

### Rules

- MUST give every listed task `desc:` one short line (`go tool task --list`).
- SHOULD give listed tasks `summary:` for `go tool task --summary <name>` (deps, `{{.CLI_ARGS}}` after `--`, platforms).
- MUST use `internal: true` for helpers not meant for `--list`.
- `default` MUST start with `go tool task --list` (not PATH `task --list`). MAY set `silent: true` and print at most four `go tool task <verb>` footer lines plus one short closer.
- Host-only listed sequencers MAY use colon names (`db:migrate`, `check:health`). C21 shared names (`lint`, `build`, …) MUST stay unprefixed.
- MUST NOT reprint the CLI catalog as Task verbs or in footers.

---

## Makefile verb list

LOAD-WHEN: authoring or editing a Go module `Makefile`; Stage 5 / golang-quality CONSTRAINT 20.

### Rules

- MUST set `.DEFAULT_GOAL := help` so bare `make` lists **local-dev** verbs.
- MUST annotate local-dev verbs (`format`, `lint`, `vet`, `test`, `build`, `serve`, `serve-down`, `init`, `hooks-install` when they exist) with `## description` on the target line.
- MUST implement `help` by scanning those annotations (do not hand-maintain a second echo list that can drift).
- MUST NOT treat every `.PHONY` name as help-listed.
- MUST NOT reprint the CLI command catalog (`<binary> help`) as Make `##` verbs. A one-line footer pointing at `<binary> help` MAY follow the list.
- MUST NOT put Make `$(VAR)` in `##` text (grep prints the variable name).
- CI-only lanes, product benches, license/keygen the CLI already documents, recipe-only helpers, and static-export siblings of a live `*-dev` preview MUST omit `##`.
- When a local pipeline needs more than one Make step, `help` MAY print a numbered footer of at most four `make <verb>` lines (run data, doctor, rebuild warehouse, live preview). MUST NOT dump catalog paths, bind mounts, or run-then-publish encyclopedias. The footer helper target MUST omit `##`.
- MUST NOT require operators to open the Makefile to discover `test`, `lint`, `build`, or `serve`.
- Make is the human interface (C20a): the binary MUST write every sidecar a later step or publish needs. MUST NOT add a Make-only finalize or glue verb for a missing file. A CLI backfill verb MAY exist; it MUST omit `##`.
- When a listed verb runs a family of lanes or groups, the default MUST be the full set; optional `VAR=` MAY narrow. MUST NOT require a required `VAR=` for the documented default path.

### Canonical help recipe

```makefile
.DEFAULT_GOAL := help

.PHONY: help format lint vet test build tidy serve serve-down pages pages-dev

help: ## List local-dev make verbs
	@grep -E '^[a-zA-Z0-9_-]+:.*?## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  %-24s %s\n", $$1, $$2}'
	@printf '\n  CLI catalog: run <binary> help\n'
	@$(MAKE) --no-print-directory report-data-flow

format: ## Format with gofumpt
	go tool gofumpt -w .

lint: ## Run golangci-lint
	go tool golangci-lint run --timeout 5m

vet: ## Run go vet
	go vet ./...

test: ## Run unit tests
	go test ./...

tidy: ## go mod tidy
	go mod tidy

build: ## Build the binary into bin/
	mkdir -p bin
	go build -o bin/app ./cmd/app

serve: ## process-compose TUI; rebuilds on file changes
	./scripts/pc-up.sh

serve-down: ## Stop this process-compose project
	./scripts/pc-down.sh

pages-dev: ## Live preview (rebuild warehouse first)

# Hidden: CI static export (no ##).
pages:
	docker compose run --rm pages-build

# Hidden helper (no ##): not listed by `make help`.
_ensure-bin:
	mkdir -p bin

report-data-flow:
	@printf '\n  Reports:\n'
	@printf '    1. make lanes\n'
	@printf '    2. make report-doctor\n'
	@printf '    3. make warehouse\n'
	@printf '    4. make pages-dev\n'
```

### Anti-pattern

```makefile
# Bare `make` fails with "No targets specified" / runs an opaque first recipe.
.PHONY: test build
test:
	go test ./...

# Or: ## on every CI lane; $(VAR) in ##; encyclopedia footer.
ci-lane-a: ## Run lane a
pages: ## Static site from $(REPORT_DUCKDB)
help:
	@printf 'run suites, publish, warehouse, catalog paths\n'
```

---

## Shared operator verbs

LOAD-WHEN: choosing Taskfile task names or Makefile target names; Stage 5 / golang-quality CONSTRAINT 21; aligning hosts with process-compose-docker.

### Shared core (use these names when the job exists)

| Verb | Meaning |
|------|---------|
| `build` | Build Go binaries |
| `test` | Run Go tests |
| `vet` | `go vet ./...` |
| `tidy` | `go mod tidy` |
| `lint` | `go tool golangci-lint` (pinned in `go.mod`) |
| `format` | `go tool gofumpt` |
| `ci` | tidy + gofmt + vet + race tests + build |
| `init` | Create `~/.config/<app>/...` config if missing |
| `serve` | Long-running process-compose local stack |
| `serve-down` | Stop this project's process-compose stack |

### Host extras (stay in the host)

`smoke`, `smoke-*`, `docker-build`, `sync`, license helpers, and similar product verbs stay as host Task or Make targets. The pack MUST NOT require every consumer to define them. Catalog-only reprints of Cobra verbs MUST be `internal: true` or omit `##` (C20). Listed operator-front-door sequencers MAY use colon namespaces (`domain:verb`). Operators still use `<binary> help` for the full CLI catalog.

### Migration

`dev` / `dev-down` MAY alias `serve` / `serve-down`. New Makefiles MUST NOT expose the long-running stack only as `dev`.

CORRECT:
```makefile
serve: ## process-compose TUI (:1325); rebuilds on file changes
	./scripts/pc-up.sh

serve-down: ## Stop this process-compose project
	./scripts/pc-down.sh

init: ## Create operator config if missing
	./bin/app init -config $(CONFIG)
```

PROHIBITED:
```makefile
# Pack-required brand string, or serve job only under another name:
serve: ## Start the AcmeCorp desktop forever-service
	...
dev-only-stack:
	process-compose up
```

---

## Numbered SQL migrations

LOAD-WHEN: adding or changing durable Postgres/SQL schema; Stage 5 / golang-quality CONSTRAINT 24.

### Shape

```text
migrations/
  000001_init.up.sql
  000001_init.down.sql
  000002_add_metrics.up.sql
  000002_add_metrics.down.sql
```

Apply pending versions once (store open, `migrate up`, or bootstrap). Record applied versions. Write paths stay DML-only.

### MUST / MUST NOT

- MUST: versioned up (and preferably down) files for production schema.
- MUST: apply pending once per process/bootstrap (or explicit migrate command).
- MUST NOT: run full `CREATE TABLE IF NOT EXISTS` / schema strings on every insert or publish.
- SHOULD: keep SQL driver/provider packages separate from DTO-only domain packages.
- MAY: use create-if-not-exists only for in-memory or throwaway test databases.

### Detection (Stage 5)

- DDL inside hot write/publish loops.
- New durable tables with no migrations directory or migrator.
- Domain packages blank-importing SQL drivers only because schema lived beside DTOs.

---

## Embedded SQLite (modernc)

LOAD-WHEN: adding or changing embedded SQLite via `database/sql`; Stage 5 / golang-quality CONSTRAINT 26.

### MUST / MUST NOT

- MUST: `import _ "modernc.org/sqlite"` and `sql.Open("sqlite", dsn)`.
- MUST: DSN pragmas via modernc form (`_pragma=foreign_keys(1)`, `_pragma=journal_mode(WAL)`, `_pragma=busy_timeout(5000)`).
- MUST NOT: `github.com/mattn/go-sqlite3`, driver name `sqlite3`, or CGO build flags added only for SQLite.
- SHOULD: `SetMaxOpenConns(1)` on write-heavy embedded sqlite pools unless read/write split is documented.

### CORRECT / PROHIBITED

CORRECT:

```go
import _ "modernc.org/sqlite"

db, err := sql.Open("sqlite", path+"?_pragma=foreign_keys(1)&_pragma=journal_mode(WAL)&_pragma=busy_timeout(5000)")
```

PROHIBITED:

```go
import _ "github.com/mattn/go-sqlite3"

db, err := sql.Open("sqlite3", path+"?_foreign_keys=on")
```

### Detection (Stage 5)

- New or changed `mattn/go-sqlite3` in `go.mod` / blank imports.
- `sql.Open("sqlite3", …)` in first-party code.
- Dockerfile or release `CGO_ENABLED=1` comments/paths tied only to SQLite.
