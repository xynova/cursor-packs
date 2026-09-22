# Project-specific review patterns

LOAD-WHEN: staged review stages 3, A, B, or 5 (or when tracing a Go change in this repo).

These are bugs this codebase actually hits. Full architecture anti-patterns: `.cursor/rules/always-rules-2-architecture.mdc`. Generation workflow: `.cursor/skills/golang-quality/SKILL.md` (also checked by staged review **Stage 5** Generation Gates).

---

## 1. LLM / HTTP inside a database transaction

Transactions MUST wrap only fast DB work. LLM and external HTTP can take seconds and hold a pool connection.

WRONG: `WithTransaction` → load row → `RefineProposal` / `Evaluate*` / HTTP → save.

RIGHT: read outside (or short read) → LLM/HTTP outside → short write transaction; re-read inside the write txn to avoid races.

---

## 2. Silent persistence / session refresh

If `AddTranslationVersion`, `CreateVersionAndSupersedeOlder`, `UpdateSession`, or equivalent fails:

WRONG: `logger.Error(err)` and continue (in-memory vs DB diverge → loops / version conflicts).

RIGHT: log, then return a domain error.

Same for session/context refresh: `if err == nil && updated != nil { ... }` with no error return is a silent failure.

Detect: `if err != nil { logger.Error` with no `return`; `_ = persist(...)`; `err == nil &&` without an error branch.

---

## 3. `fmt.Print*` instead of logger

Services and non-interactive commands MUST use `*observability.Logger`. `fmt.Print*` bypasses structured logs.

Exception: interactive CLI/TUI via pterm (not raw `fmt`).

---

## 4. CLI → service → client

- CLI `RunE` delegates to a service; no business logic, no HTTP, no `os.Exit`.
- Services call injected clients; no `http.Post` / `http.Do`.
- HTTP lives in `internal/clients/<service>/` (or a pipeline HTTP client).

---

## 5. Named return shadowed (`err :=` vs `err =`)

When the signature is `(err error)` and `defer` reads `err` (spans, cleanup):

WRONG: `if err := service.Process(...)` — defer sees the named return still nil.

RIGHT: `if err = service.Process(...)`.

Impact: spans marked OK on failure; cleanup misses the error.

---

## 6. Type assertion `ok` ignored

WRONG: `v, _ := m["k"].(string)` — zero value on failure, silent bug.

RIGHT: check `ok`; default or return error.

---

## 7. God interface / over-export

- Interface with 10+ methods, or one repo interface for Saying + Translation + Evaluation → split (ISP, ≤ 6 methods).
- Export only public API interfaces, constructors, shared DTOs. Unexport impl structs and helpers. Skill: `.cursor/skills/review-member-visibility/SKILL.md`.

---

## 8. Domain vs DTO location

Domain (Saying, Translation, Evaluation, ContentPiece) → `internal/database/models.go` (or the pipeline's domain package).

Infrastructure DTOs (Agent, Tool, HTTP payloads) → the client package. NEVER mix.

---

## 9. DB fallback inside a transaction

WRONG: `items, err := tx.Get(...); if err == nil { use items }` and continue; or fallback defaults on query failure.

RIGHT: return the error; let the transaction roll back.

---

## 10. Direct instantiation / logging bypass

WRONG: `client.NewClient(...)` or `logrus.New()` inside a service method.

RIGHT: constructor injection from the container; injected logger.

---

## 11. HTTP body not closed

Every successful `Do` / `doRequest` MUST `defer resp.Body.Close()` immediately after the error check.

---

## 12. Tracing technique (short)

For each changed function: entry point → call chain (CLI → service → client/repo) → every variable created and consumed → every error returned or wrapped → every resource deferred. Disconnects are bugs.

---

## 13. Stringify drops the wrap chain

WRONG: `return fmt.Errorf("hop: %s", err.Error())` or copy only a message string and drop `Unwrap`.

RIGHT: `errors.Wrap(err, code, op, msg)` (optional `.With(k, v)`). When crossing Bifrost, set `ErrorField.Error` to the domain error so `errors.Is` still works.

---

## 14. Gateway-only LLM tracing (missing client OTEL)

AI gateways (Polypus, Bifrost, provider proxies) export HTTP timing and status. That does **not** cover hangs or errors inside the calling libraries after the response (XML parse, evaluate loops, retry wiring).

WRONG: Ship an LLM CLI/worker with no process `observability.Init`, no OpenInference (or project) spans on generate/evaluate, and treat the gateway UI as sufficient.

RIGHT: Init the tracer at the entrypoint; export OTLP when the project's endpoint env is set; span generate/evaluate/parse so Phoenix/Arize shows client failures even when the gateway returned HTTP 200.

Detect: LLM call sites with no span start; `ResolveConfig` / `Init` never called from the command path; docs that say "debug in the gateway" with no client exporter.

Related: golang-quality CONSTRAINT 15; Stage 5 Generation Gates checklist (C15); Stage A/B consultant questions on observability.

---

## 15. AI dumps wiped with scratch trees

Jobs that set RLM `TraceDir`, strop `runreport` `Dir`, or olly inference-failure dump roots often nest those paths under an analysis `MkdirTemp` that `defer os.RemoveAll` deletes. After a local AI test, operators have no JSONL/JSON to reopen even when the run succeeded.

WRONG: `rlmCfg.TraceDir = filepath.Join(analysisDir, "rlm-traces", task)` where `analysisDir` is removed on exit, with no durable work-story copy and no logged/returned path.

RIGHT: Write dumps under a durable root (`tmp/digest-runs/<id>-<ts>`, `--work-story-dir`, or project-documented equivalent); keep analysis clones disposable; log or return `work_story_dir` (or equivalent).

Detect: TraceDir/runreport under the same tree as `RemoveAll`; successful CLI with no dump path in logs/result; docs that say "check rlm-traces" without naming a surviving directory.

Related: golang-quality CONSTRAINT 16; Stage 5 Generation Gates checklist (C16); strop-pipeline-pattern durable TraceDir / runreport.

---

## 16. Generator/evaluator only testable via full reseed

Prompt or signature edits to a pipeline CoT/Predict step that can only be verified by running the whole JobRunner chain (minutes of digest/reseed) hide regressions and make inner-loop tuning unreliable. Scraping `*_md` for machine contracts compounds the same problem.

WRONG: Change one pipeline-step instruction; only check is a full-chain reseed. Gate `merge_ids` by regex on free-text markdown.

RIGHT: Capture Process inputs from `module-traces/` (or TraceDir) into `testdata/`; offline zip/parse gates stay in default `go test`; env-gated live `Generate`/`Evaluate` for that task alone; discrete contracts are signature fields. See `dspy-pipeline-isolation`.

Detect: Staged `*_modules.go` / signatures / generator wiring with no `LIVE_*` replay test and no offline fixture; gates that read markdown instead of structured outs; PR that says "verified by reseed" with no module-level path.

Related: golang-quality CONSTRAINT 17; Stage 5 Generation Gates checklist (C17); `.cursor/skills/dspy-pipeline-isolation/SKILL.md`.

---

## 17. Package layout sprawl and grab-bags

Library roots and application roots drift in different ways. Both break when package names become junk drawers, when public kit API is trapped behind `internal/`, when `cmd` owns handlers, or when `internal/` is a flat sibling forest with no domain parents.

WRONG: `cmd/server/main.go` loads config and also owns mux handlers and routing predicates; `internal/util`, `internal/common`, and `internal/shared` hide unrelated helpers; a kit's consumer types live only under `internal/`; a new feature adds `internal/<leaf>` beside 80 other siblings instead of nesting under the owning domain.

RIGHT: kits keep public API in `pkg/<domain>/`, hidden helpers in `internal/` (still domain-named); apps keep `cmd/<app>/main.go` as wiring (flags, observability, one `Mount`/`Run`) and put handlers under `internal/<domain>/`; outbound HTTP stays in client packages (C10).

Detect (Stage 5 / C19):

- Loose implementation `.go` at the repo root (not `doc.go` / `package` docs at module root when that is the kit's exported root).
- `cmd/<app>/main.go` contains `HandleFunc`, domain calls beyond one `Mount`/`Run`, or routing predicates.
- `ls <module>/internal` is a sibling forest (many leaves, no parent domain directories) or the diff *adds* a new top-level `internal/<leaf>` that belongs under an existing domain.
- Package names `util`, `common`, `helpers`, `shared`, `misc`, `tools`.
- Other modules need types that exist only under `internal/` (kit misclassified as hidden).
- App module grows a mixed `pkg/` of host types without being a published kit (host architecture may forbid this).

Related: golang-quality CONSTRAINT 19; Stage 5 Generation Gates checklist (C19); Stage A architecture questions on library vs application layout; `golang-quality/reference-patterns.md` package layout.

---

## 18. Bare binary starts the service (missing CLI command surface)

Operators expect a catalog (`serve`, `version`, `help`). A daemon whose default argv path Listen/Serves turns `tool -v` and empty invokes into config failures or accidental starts.

WRONG: `main` parses flags and listens when `os.Args` has no subcommand; no root `version`; README says `go run ./cmd/tool` to start the daemon.

RIGHT: Explicit start command (`serve`); bare invoke prints usage and exits non-zero; `version` works without config or license Gate; Makefile / Docker / Air / compose use the start command. See `cli-command-surface`.

Detect (Stage 5 when CLI in scope; Stage A consult):

- Entrypoint falls through to Listen/Serve with no subcommand.
- Missing `version` / root help catalog.
- Launchers still invoke the bare binary after start became explicit.
- Help text marks discovery flags as required when resolvers already default them.

Related: `.cursor/skills/cli-command-surface/SKILL.md`; Stage 5 CLI command surface checklist; Stage A question on implicit start.

---

## 19. Bare outbound exec/HTTP without failsafe-go

Forge CLIs (`gh`, `glab`) and HTTP clients that run once under load produce `signal: killed` / timeout storms and cascade into board or poll failures. Ad-hoc sleep loops hide the same gap.

WRONG: `exec.CommandContext(ctx, "glab", ...).Run()` or `httpClient.Do(req)` in a client/exec package with no failsafe-go retry + breaker; or `for i := 0; i < n; i++ { time.Sleep(...); retry }`.

RIGHT: Shared exec/HTTP seam wraps the hop with failsafe-go (exponential backoff + jitter, circuit breaker keyed by dependency); retries only classified transients (timeout, killed, transport, 429/5xx); honors caller `ctx`.

Detect (Stage 5 / C22):

- New or changed `Command` / `CommandContext` / `http.Client.Do` in client or exec packages without a failsafe `Run` / `Get` (or project wrapper that embeds those policies).
- Hand-rolled sleep/retry around outbound I/O.
- Blind retry of every non-zero exit or every HTTP status.

Related: golang-quality CONSTRAINT 22; Stage 5 Generation Gates checklist (C22); `golang-quality/reference.md` outbound resilience.
