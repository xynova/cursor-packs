---
name: review-code-staged
description: >-
  Staged Go code review with mechanical (1–5) vs consultant (A–C) stage groups,
  a group menu, Makefile tool slots, and a tmp/review plan file. Use when the
  user asks to review, audit, rate quality, check code, or check production
  readiness of Go changes.
---

# Staged Code Review (Go)

Menu-driven review. Do **not** dump every checklist into chat before the user picks stages.

**Load:** [methodology.md](methodology.md) for stage checklists, plan file, and report format. Load [appendix.md](appendix.md) for this repo's unique bug patterns (LLM-in-transaction, silent persistence, named-return shadowing, gateway-only LLM tracing).

**Related:** `.cursor/skills/golang-quality/SKILL.md` (write-time gates; **Stage 5** applies the same constraints at review). When a CLI entrypoint is in scope, **Stage 5** also applies `.cursor/skills/cli-command-surface/SKILL.md` (bare invoke, `version`, root help, explicit start). When outbound HTTP or process-exec network hops are in scope, **Stage 5** also applies `.cursor/rules/go-outbound-resilience.mdc` (failsafe-go / C22). External Go taste (Go Code Review Comments, Uber Go Style Guide) is cited there as baseline only; review scores house Core constraints, not those guides as a second checklist. Structured report strings: `.cursor/rules/go-structured-strings.mdc` (Stage 5). Exports: `.cursor/skills/review-member-visibility/SKILL.md`. If the project has them: architecture reviews via project `pipelines-x-review-architecture` (if present); smells via `.cursor/skills/review-code-smells/SKILL.md`.

---

## When to load

User asks to "review", "audit", "rate quality", "check code", or "production readiness" for Go.

---

## Steps

1. **Ask for target** — file, package, or directory. Default: changed files in the current work.
2. **Present the group menu** (from methodology) and wait. MUST offer `mechanical`, `consultant`, and `both` as first-class choices, plus optional stage IDs. MUST NOT start a stage until the user picks a group, IDs, a range, or `all`/`both`. `mechanical` = `1, 2, 3, 4, 5`. `consultant` = `A, B, C`. `both`/`all` = `1`–`5` then `A`–`C`.
3. **Create** `tmp/review-<slug>-<YYYY-MM-DD>.md` before the first selected stage (`tmp/` is gitignored). If it does not exist, create it.
4. **Expand aliases**, then run selected stages in order `1`–`5` then `A`–`C` (skip unselected).
   - **Mechanical (`1`–`5`):** run the whole selected mechanical batch in one go. After each mechanical stage, write findings and print the per-stage chat summary, then continue immediately to the next mechanical stage. MUST NOT ask "Continue?" and MUST NOT wait between mechanical stages.
   - **Handoff to consultant:** when any of `A`–`C` is still selected after the mechanical batch (or when starting consultant-only), print a short note that consultant dialogue begins, then start the first consultant stage.
   - **Consultant (`A`–`C`):** these are the only stages that pause for the user (one question at a time; see step 5).
5. **Consultant stages (A–C):** ask one question at a time, with a short Why this matters in the same turn (see methodology consultant protocol). Do not verdict before the user replies. User says `explain` → expand in the same agent; do not spawn an explain subagent. Unanswered → open question, move on. MUST wait for the user’s reply before the next consultant question or stage.
6. **Stage 5 (Generation Gates):** MUST Read `golang-quality` Core constraints and apply them; for multi-section builders also apply `go-structured-strings.mdc` (see methodology Stage 5). When a CLI / daemon entrypoint is in scope, MUST also Read and apply `cli-command-surface` binary checks. When outbound HTTP `Do`, forge CLI exec, or network `git`/SCM hops are in scope, MUST also Read and apply `.cursor/rules/go-outbound-resilience.mdc` (C22 / appendix pattern 19). MUST NOT score raw Uber / Code Review Comments items unless they map to a Core constraint.
7. **When all selected stages are done:** completion handoff (fix with agent / fix here / stop). Wait for the user. Open questions are NEVER auto-fixed. Fixable Low findings MUST NOT be skipped when fixing.

Resume: if the user says "continue" / "resume" / "next stage" without context, list `tmp/review-*.md`, pick the file, and run from the first unchecked stage. If that stage is mechanical, finish the remaining mechanical batch without further confirmation; if it is consultant, resume the dialogue protocol. Map legacy IDs via methodology if needed.

---

## Tool slots

Do **not** stop because a standalone `gosec` or `gocyclo` binary is missing. Do **not** require `.gosec.yaml`.

Prefer Makefile targets when present; else the Go toolchain:

| Slot | Prefer | Fallback |
|------|--------|----------|
| Static analysis | `make vet` | `go vet ./...` |
| Lint + security | `make lint` | `golangci-lint run` |
| Format check | `gofmt -l .` (or project pkgs) | note `make format` would rewrite |
| Complexity | Optional via golangci/`gocritic` | skip if unavailable |

Pre-flight: confirm lint and vet can run. If lint fails because golangci-lint is missing, report that and stop Stage 1 only.

---

## Rules

- MUST wait for stage or group selection (`mechanical`, `consultant`, `both`/`all`, `1`–`5`, `A`–`C`, or ranges).
- MUST expand group aliases before running stages.
- MUST run selected mechanical stages (`1`–`5`) back-to-back without "Continue?" or other mid-batch waits.
- MUST pause for user input only during consultant stages (`A`–`C`) and at the final completion handoff.
- MUST write findings to the plan file (code pairs live there, not in the chat summary).
- MUST use [appendix.md](appendix.md) on stages 3, A, B, and 5 (pattern 14 when LLM paths are in scope).
- MUST load `golang-quality` when running Stage 5; MUST NOT treat Stage 4 as a substitute for generation gates.
- MUST load `cli-command-surface` during Stage 5 when a CLI / daemon entrypoint is in scope; MUST NOT treat missing `version` / bare-start as Stage 4 clarity only.
- MUST load `.cursor/rules/go-outbound-resilience.mdc` (and golang-quality C22 / appendix pattern 19) during Stage 5 when changed code performs outbound HTTP `Do`, forge CLI exec, or network `git`/SCM hops; MUST NOT treat homemade sleep-retry as compliant.
- MUST score Stage 5 Go gates against `golang-quality` Core constraints only (plus `cli-command-surface` when in scope, plus outbound resilience when in scope); MUST NOT treat Go Code Review Comments or Uber Go Style Guide as a parallel scored checklist.
- MUST NOT bypass, omit, or deprioritize **Low** findings when they are fixable. Prefer fixing them with the rest of the findings (see methodology completion handoff).
- If the project has `/review-architecture` or `/review-code-smells`, point the user there when that is the whole ask — do not replace those commands.
