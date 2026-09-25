# AI readiness reference

LOAD-WHEN: auditing or scaffolding `AGENTS.md` / `ai-copilots/` for any repo.

## Audit checklist (binary)

Run from the repository git root.

| # | Check | Method | Pass | Fail |
|---|--------|--------|------|------|
| 1 | Git root resolved | `git rev-parse --show-toplevel` | Prints expected path | Wrong tree or not a git repo |
| 2 | `AGENTS.md` present | `test -f AGENTS.md` | File exists | Missing |
| 3 | AGENTS points into ai-copilots | Open `AGENTS.md`; skill links under `ai-copilots/` | All skill links resolve under `ai-copilots/` | Links missing or point elsewhere |
| 4 | `ai-copilots/README.md` | `test -f ai-copilots/README.md` | Exists | Missing |
| 5 | `ai-copilots/BOOTSTRAP.md` | `test -f ai-copilots/BOOTSTRAP.md` | Exists | Missing |
| 6 | At least one skill | `ls ai-copilots/skills/*/SKILL.md` | One or more files | None |
| 7 | No committed secrets | Scan harness for tokens, passwords, DB URLs | Clean | Secret found |
| 8 | Wire documented | BOOTSTRAP has wire steps for at least one IDE | Present | Missing |

Optional (report, do not block baseline claim if files pass):

| # | Check | Method |
|---|--------|--------|
| 9 | Cursor links | `test -f .cursor/skills/<name>/SKILL.md` after wire |
| 10 | GitHub Copilot links | `test -f .github/skills/<name>/SKILL.md` after wire |

## Scaffold sequence

1. `mkdir -p ai-copilots/skills/<operator-name>`
2. Copy stubs from `author-ai-copilots` reference (`AGENTS.md`, README, BOOTSTRAP, skill).
3. Fill module path, operator skill name, and load order.
4. Author skill body with agent-smith (MUST/NEVER, enforcement, examples).
5. Re-run checklist items 2–8.
6. Wire when the user asks (BOOTSTRAP wire-only).

## Default recommendation

Prefer a **minimal portable operator skill** plus AGENTS load order plus BOOTSTRAP
wire. Expand into multiple domain skills only after the baseline passes.

## Related

- `author-ai-copilots` for layout templates
- `edit-cursor-packs` when changing pack-owned readiness artifacts
- Library domain skills stay under that library's `ai-copilots/skills/`
