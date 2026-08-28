# Project-specific review patterns

LOAD-WHEN: staged review stages 3, 4, or 5 (or when tracing a Go change in this repo).

These are bugs this codebase actually hits. Full architecture anti-patterns: `.cursor/rules/always-rules-2-architecture.mdc`. Generation workflow: `.cursor/skills/golang-quality/SKILL.md`.

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
