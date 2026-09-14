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

**Related:** `.cursor/skills/golang-quality/SKILL.md` (write-time gates; **Stage 5** applies the same constraints at review). External Go taste (Go Code Review Comments, Uber Go Style Guide) is cited there as baseline only; review scores house Core constraints, not those guides as a second checklist. Structured report strings: `.cursor/rules/go-structured-strings.mdc` (Stage 5). Exports: `.cursor/skills/review-member-visibility/SKILL.md`. If the project has them: architecture reviews via project `pipelines-x-review-architecture` (if present); smells via `.cursor/skills/review-code-smells/SKILL.md`.

---

## When to load

User asks to "review", "audit", "rate quality", "check code", or "production readiness" for Go.

---

## Steps

1. **Ask for target** — file, package, or directory. Default: changed files in the current work.
2. **Present the group menu** (from methodology) and wait. MUST offer `mechanical`, `consultant`, and `both` as first-class choices, plus optional stage IDs. MUST NOT start a stage until the user picks a group, IDs, a range, or `all`/`both`. `mechanical` = `1, 2, 3, 4, 5`. `consultant` = `A, B, C`. `both`/`all` = `1`–`5` then `A`–`C`.
3. **Create** `tmp/review-<slug>-<YYYY-MM-DD>.md` before the first selected stage (`tmp/` is gitignored). If it does not exist, create it.
4. **Expand aliases**, then **run one stage at a time** in order `1`–`5` then `A`–`C` (skip unselected). After each stage: write findings into the plan file, print the per-stage chat summary, ask "Continue?".
5. **Consultant stages (A–C):** ask one question at a time, with a short Why this matters in the same turn (see methodology consultant protocol). Do not verdict before the user replies. User says `explain` → expand in the same agent; do not spawn an explain subagent. Unanswered → open question, move on.
6. **Stage 5 (Generation Gates):** MUST Read `golang-quality` Core constraints and apply them; for multi-section builders also apply `go-structured-strings.mdc` (see methodology Stage 5). MUST NOT score raw Uber / Code Review Comments items unless they map to a Core constraint.
7. **When all selected stages are done:** completion handoff (fix with agent / fix here / stop). Wait for the user. Open questions are NEVER auto-fixed. Fixable Low findings MUST NOT be skipped when fixing.

Resume: if the user says "continue" / "resume" / "next stage" without context, list `tmp/review-*.md`, pick the file, run the first unchecked stage after confirmation. Map legacy IDs via methodology if needed.

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
- MUST write findings to the plan file (code pairs live there, not in the chat summary).
- MUST use [appendix.md](appendix.md) on stages 3, A, B, and 5 (pattern 14 when LLM paths are in scope).
- MUST load `golang-quality` when running Stage 5; MUST NOT treat Stage 4 as a substitute for generation gates.
- MUST score Stage 5 against `golang-quality` Core constraints only; MUST NOT treat Go Code Review Comments or Uber Go Style Guide as a parallel scored checklist.
- MUST NOT bypass, omit, or deprioritize **Low** findings when they are fixable. Prefer fixing them with the rest of the findings (see methodology completion handoff).
- If the project has `/review-architecture` or `/review-code-smells`, point the user there when that is the whole ask — do not replace those commands.
