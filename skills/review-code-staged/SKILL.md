---
name: review-code-staged
description: >-
  Staged Go code review with mechanical (1–5) vs consultant (A–C) stage groups,
  a group menu, Makefile and go.mod tool slots (go tool golangci-lint,
  gofumpt, gocognit via golangci), and a tmp/review plan file. Use when the
  user asks to review, audit, rate quality, check code, or check production
  readiness of Go changes.
---

# Staged Code Review (Go)

Menu-driven review. Do **not** dump every checklist into chat before the user picks stages.

**Load:** [methodology.md](methodology.md) for stage checklists, plan file, and report format. Load [appendix.md](appendix.md) for this repo's unique bug patterns (LLM-in-transaction, silent persistence, named-return shadowing, gateway-only LLM tracing).

**Related:** `.cursor/skills/golang-quality/SKILL.md` (write-time gates; **Stage 5** applies the same constraints at review). When a CLI entrypoint is in scope, **Stage 5** also applies `.cursor/skills/cli-command-surface/SKILL.md` (bare invoke, `version`, root help, explicit start) and golang-quality **C27** (Go binaries use Cobra; no new hand-rolled argv dispatch). When outbound HTTP or process-exec network hops are in scope, **Stage 5** also applies `.cursor/rules/go-outbound-resilience.mdc` (failsafe-go / C22). When durable or test-sensitive timestamp writes are in scope, **Stage 5** / **Stage C** also apply `.cursor/rules/go-injectable-clock.mdc` (C25). When `go.mod` or embedded SQLite (`sql.Open`, sqlite store open paths) are in scope, **Stage 5** also applies golang-quality **C26** (modernc.org/sqlite; no mattn/CGO for SQLite). When release CI is in scope (`.github/workflows/*release*`, `.gitlab/ci/*release*`, `**/auto-patch-release.yml`, `.goreleaser.yaml`, `scripts/auto-patch-decide.sh`, `scripts/auto-patch-path-predicates.sh`), **Stage 5** also applies **CI Quality**: `.cursor/skills/manage-go-releases/SKILL.md` and `.cursor/rules/go-releases.mdc` (checklist in manage-go-releases `reference.md`). External Go taste (Go Code Review Comments, Uber Go Style Guide) is cited there as baseline only; review scores house Core constraints, not those guides as a second checklist. Structured report strings: `.cursor/rules/go-structured-strings.mdc` (Stage 5). Exports: `.cursor/skills/review-member-visibility/SKILL.md`. If the project has them: architecture reviews via project `pipelines-x-review-architecture` (if present); smells via `.cursor/skills/review-code-smells/SKILL.md`.

---

## When to load

User asks to "review", "audit", "rate quality", "check code", or "production readiness" for Go.

---

## Steps

1. **Ask for target** — file, package, or directory. Default: changed files in the current work.
2. **Present the group menu** (from methodology) and wait. MUST offer `mechanical`, `consultant`, and `both` as first-class choices, plus optional stage IDs. MUST NOT start a stage until the user picks a group, IDs, a range, or `all`/`both`. `mechanical` = `1, 2, 3, 4, 5`. `consultant` = `A, B, C`. `both`/`all` = `1`–`5` then `A`–`C`.
3. **Create** `tmp/review-<slug>-<YYYY-MM-DD>.md` before the first selected stage (`tmp/` is gitignored). If it does not exist, create it.
4. **Discover library hooks** per methodology (Read linked `ai-copilots/review-hooks.yaml` when in scope).
5. **Expand aliases**, then run selected stages in order `1`–`5`, then in-scope library `*-M*`, then `A`–`C` (skip unselected).
   - **Mechanical (`1`–`5`):** run the whole selected mechanical batch in one go. After each mechanical stage, write findings and print the per-stage chat summary, then continue immediately to the next mechanical stage. MUST NOT ask "Continue?" and MUST NOT wait between mechanical stages.
   - **Handoff to consultant:** when any of `A`–`C` is still selected after the mechanical batch (or when starting consultant-only), print a short note that consultant dialogue begins, then start the first consultant stage.
   - **Consultant (`A`–`C`):** these are the only stages that pause for the user (one question at a time; see step 6).
6. **Consultant stages (A–C):** ask one question at a time, with a short Why this matters in the same turn (see methodology consultant protocol). Do not verdict before the user replies. User says `explain` → expand in the same agent; do not spawn an explain subagent. Unanswered → open question, move on. MUST wait for the user’s reply before the next consultant question or stage.
7. **Stage 5 (Generation Gates):** MUST Read `golang-quality` Core constraints and apply them; for multi-section builders also apply `go-structured-strings.mdc` (see methodology Stage 5). When a CLI / daemon entrypoint is in scope, MUST also Read and apply `cli-command-surface` binary checks. When outbound HTTP `Do`, forge CLI exec, or network `git`/SCM hops are in scope, MUST also Read and apply `.cursor/rules/go-outbound-resilience.mdc` (C22 / appendix pattern 19). When durable or test-sensitive timestamp writes are in scope, MUST also Read and apply `.cursor/rules/go-injectable-clock.mdc` (C25 / appendix pattern 21). When embedded SQLite or sqlite-related `go.mod` deps are in scope, MUST score golang-quality **C26** (modernc driver; grep mattn / `sqlite3` open). When release workflows or GoReleaser config are in scope, MUST also Read and apply `manage-go-releases` and score the **CI Quality** checklist in its `reference.md` (findings category `CI Quality`). MUST NOT score raw Uber / Code Review Comments items unless they map to a Core constraint.
8. **When all selected stages are done:** completion handoff (fix with agent / fix here / stop). Wait for the user. Open questions are NEVER auto-fixed. Fixable Low findings MUST NOT be skipped when fixing.

Resume: if the user says "continue" / "resume" / "next stage" without context, list `tmp/review-*.md`, pick the file, and run from the first unchecked stage. If that stage is mechanical, finish the remaining mechanical batch without further confirmation; if it is consultant, resume the dialogue protocol. Map legacy IDs via methodology if needed.

---

## Tool slots

Do **not** stop because a standalone `gosec` or `gocyclo` binary is missing. Do **not** require `.gosec.yaml`.

Prefer Makefile targets when present; else `go tool` from `go.mod` `tool`; else PATH:

| Slot | Prefer | Fallback |
|------|--------|----------|
| Static analysis | `make vet` | `go vet ./...` |
| Lint + security | `make lint` | `go tool golangci-lint run --timeout 5m`, then PATH `golangci-lint run` |
| Format check | `make format` (dry if the recipe rewrites) | `go tool gofumpt -l .`, then `gofmt -l .` |
| Complexity | golangci `gocognit` via lint | `go tool gocognit` if pinned; skip standalone `gocyclo` |

**CONSTRAINT:** Stage 1 MUST run lint through `make lint` or `go tool golangci-lint` when either exists. MUST NOT treat a missing PATH `golangci-lint` as a Stage 1 stop when `go.mod` lists the tool. IF `make lint` is absent AND `go tool golangci-lint` fails because it is not pinned AND PATH `golangci-lint` is missing → report that and stop Stage 1 only. MUST record gocognit findings from golangci (or `go tool gocognit` when pinned). MUST NOT require `gocyclo`.
- Enforcement: Pre-flight tries `make lint`, then `go tool golangci-lint version`, then PATH; plan file records which slot ran.
- Violation: STOP, rerun via `go tool`; do not skip lint solely because Homebrew golangci-lint is missing.

CORRECT:
```text
make lint
# or: go tool golangci-lint run --timeout 5m ./cmd/... ./internal/...
```

PROHIBITED:
```text
golangci-lint: command not found → skip Stage 1
# even though go.mod has tool github.com/golangci/golangci-lint/v2/cmd/golangci-lint
```

---

## Rules

- MUST run Stage 1 lint via `make lint` or `go tool golangci-lint` when either exists (golang-quality C11); MUST NOT skip lint solely because PATH `golangci-lint` is missing.
- MUST wait for stage or group selection (`mechanical`, `consultant`, `both`/`all`, `1`–`5`, `A`–`C`, or ranges).
- MUST expand group aliases before running stages.
- MUST run selected mechanical stages (`1`–`5`) back-to-back without "Continue?" or other mid-batch waits.
- MUST pause for user input only during consultant stages (`A`–`C`) and at the final completion handoff.
- MUST write findings to the plan file (code pairs live there, not in the chat summary).
- MUST use [appendix.md](appendix.md) on stages 3, A, B, and 5 (pattern 14 when LLM paths are in scope).
- MUST load `golang-quality` when running Stage 5; MUST score **C11** (`go.mod` tool pins, `.golangci.yml` gocognit/gosec/godot) when `go.mod` / Makefile / `.golangci.yml` are in scope; MUST NOT treat Stage 4 as a substitute for generation gates.
- MUST load `cli-command-surface` during Stage 5 when a CLI / daemon entrypoint is in scope; MUST NOT treat missing `version` / bare-start as Stage 4 clarity only.
- MUST score golang-quality **C27** during Stage 5 when changed paths include Go `cmd/`, `internal/cli/`, or daemon `main`; MUST NOT approve new `switch args` / custom CLI routers or extensions to legacy hand-rolled dispatch.
- MUST load `.cursor/rules/go-outbound-resilience.mdc` (and golang-quality C22 / appendix pattern 19) during Stage 5 when changed code performs outbound HTTP `Do`, forge CLI exec, or network `git`/SCM hops; MUST NOT treat homemade sleep-retry as compliant.
- MUST load `.cursor/rules/go-injectable-clock.mdc` (and golang-quality C25 / appendix pattern 21) during Stage 5 / Stage C when changed code stamps durable or test-sensitive time; MUST NOT treat leaf `time.Now()` on `CreatedAt` / manifests / cache stores as compliant.
- MUST score golang-quality **C26** during Stage 5 when changed paths include embedded SQLite (`modernc.org/sqlite`, `sql.Open("sqlite", …)`); MUST NOT treat new `mattn/go-sqlite3` or CGO-for-SQLite build hooks as compliant.
- MUST load `manage-go-releases` / `go-releases.mdc` during Stage 5 **CI Quality** when changed paths include `.github/workflows/*release*`, `.gitlab/ci/*release*`, `**/auto-patch-release.yml`, `.goreleaser.yaml`, or `scripts/auto-patch-decide.sh` / `auto-patch-path-predicates.sh`; MUST NOT approve subject-only auto-patch or tag-wake-only Docker after auto-patch.
- MUST score Stage 5 Go gates against `golang-quality` Core constraints only (plus `cli-command-surface` when in scope, plus outbound resilience when in scope, plus injectable clocks when in scope, plus embedded SQLite C26 when in scope, plus manage-go-releases when release CI is in scope); MUST NOT treat Go Code Review Comments or Uber Go Style Guide as a parallel scored checklist.
- MUST NOT bypass, omit, or deprioritize **Low** findings when they are fixable. Prefer fixing them with the rest of the findings (see methodology completion handoff).
- If the project has `/review-architecture` or `/review-code-smells`, point the user there when that is the whole ask — do not replace those commands.
