---
name: review-code-staged
description: >-
  Staged Go code review with a stage menu, detect vs consultant modes, Makefile
  tool slots, and a tmp/review plan file. Use when the user asks to review, audit,
  rate quality, check code, or check production readiness of Go changes.
---

# Staged Code Review (Go)

Menu-driven review. Do **not** dump every checklist into chat before the user picks stages.

**Load:** [methodology.md](methodology.md) for stage checklists, plan file, and report format. Load [appendix.md](appendix.md) for this repo's unique bug patterns (LLM-in-transaction, silent persistence, named-return shadowing).

**Related:** `.cursor/skills/golang-quality/SKILL.md` (generation gates). Exports: `.cursor/skills/review-member-visibility/SKILL.md`. If the project has them: architecture reviews via project `pipelines-x-review-architecture` (if present); smells via `.cursor/skills/review-code-smells/SKILL.md`.

---

## When to load

User asks to "review", "audit", "rate quality", "check code", or "production readiness" for Go.

---

## Steps

1. **Ask for target** — file, package, or directory. Default: changed files in the current work.
2. **Present the menu** (from methodology) and wait. MUST NOT start a stage until the user picks numbers, a range, or `all`.
3. **Create** `tmp/review-<slug>-<YYYY-MM-DD>.md` before stage 1 (`tmp/` is gitignored). If it does not exist, create it.
4. **Run one stage at a time.** After each stage: write findings into the plan file, print the per-stage chat summary, ask "Continue?".
5. **Consultant stages (4–6):** ask one question at a time, with a short Why this matters in the same turn (see methodology consultant protocol). Do not verdict before the user replies. User says `explain` → expand in the same agent; do not spawn an explain subagent. Unanswered → open question, move on.
6. **When all selected stages are done:** completion handoff (fix with agent / fix here / stop). Wait for the user. Open questions are NEVER auto-fixed. Fixable Low findings MUST NOT be skipped when fixing.

Resume: if the user says "continue" / "resume" / "next stage" without context, list `tmp/review-*.md`, pick the file, run the first unchecked stage after confirmation.

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

- MUST wait for stage selection.
- MUST write findings to the plan file (code pairs live there, not in the chat summary).
- MUST use [appendix.md](appendix.md) on stages 3, 4, and 5.
- MUST NOT bypass, omit, or deprioritize **Low** findings when they are fixable. Prefer fixing them with the rest of the findings (see methodology completion handoff).
- If the project has `/review-architecture` or `/review-code-smells`, point the user there when that is the whole ask — do not replace those commands.
