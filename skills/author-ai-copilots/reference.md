# author-ai-copilots reference

LOAD-WHEN: scaffolding `ai-copilots/`, writing portable `BOOTSTRAP.md` / `AGENTS.md`, or wiring a Go module dependency into a host IDE.

Replace `<module-path>`, `<LibName>`, and `<skill-name>` for the library.

---

## Target tree

```text
<module-root>/
  AGENTS.md
  ai-copilots/
    README.md
    BOOTSTRAP.md
    agents/                 # optional
      <skill-name>.md
    skills/
      README.md             # optional index
      <skill-name>/
        SKILL.md
        # optional shards: troubleshooting.md, reference.md, …
```

---

## Example `AGENTS.md` stub

```markdown
# Agents

This module is a library and/or CLI. Humans read [README.md](README.md).

**Load these skills before you operate or extend this module:**

1. [ai-copilots/skills/README.md](ai-copilots/skills/README.md) (index)
2. [ai-copilots/skills/<skill-name>/SKILL.md](ai-copilots/skills/<skill-name>/SKILL.md)

## Wire host discovery

Skills ship under `ai-copilots/`. They are not bound to one agent product.
Execute [ai-copilots/BOOTSTRAP.md](ai-copilots/BOOTSTRAP.md) in **wire mode**
to symlink into `.cursor/`, `.github/`, `.claude/`, or `.codex/`.

Resolve the module root when this library is only a Go dependency:

`go list -m -f '{{.Dir}}' <module-path>`

MUST keep host links pointing at this module's `ai-copilots/` tree.
MUST NOT copy skill bodies into the host unless links fail and the user approves.
```

---

## Example `ai-copilots/README.md` stub

```markdown
# <LibName> ai-copilots

Operator / author agent pack for this module.

Canonical source lives here. Wiring is done by the AI copilot when you ask it
to execute [BOOTSTRAP.md](BOOTSTRAP.md).

**Minimal prompt:**

> Wire <LibName> ai-copilots using BOOTSTRAP.md
```

---

## Portable `BOOTSTRAP.md` template

Copy into `ai-copilots/BOOTSTRAP.md`. Fill placeholders. Keep product-neutral.

```markdown
# BOOTSTRAP — <LibName> ai-copilots

**Audience:** Any AI agent (Cursor, GitHub Copilot, Claude Code, Codex) in a
workspace that depends on or checks out this module.

**Goal:** Wire host IDE discovery to canonical content under `ai-copilots/`.
Optionally refresh content. **MUST NOT** copy skill bodies unless symlinks or
junctions fail and the user approves copy fallback.

**Module path:** `<module-path>`

---

## When to run

| Mode | Phases |
|------|--------|
| **Wire only** | 0 → 2 → 3 → 4 |
| **Refresh content + wire** | 0 → 1 → 2 → 3 → 4 |

---

## Phase 0 — Resolve module root

From a Go module that requires `<module-path>` (or this checkout):

```bash
MOD="$(go list -m -f '{{.Dir}}' <module-path>)"
test -d "$MOD/ai-copilots" || { echo "missing ai-copilots under $MOD"; exit 1; }
echo "Module Dir: $MOD"
```

If `go list` is unavailable, use a known nested checkout path only when it
clearly contains `ai-copilots/`. MUST NOT invent a path.

Re-run wire after module version bumps (cache Dir can change).

---

## Phase 1 — Refresh content (optional)

Edit only files under `$MOD/ai-copilots/`. Load author-ai-copilots + agent-smith
when authoring skills.

Target tree:

```text
ai-copilots/
  README.md
  BOOTSTRAP.md
  agents/          # optional
  skills/<skill-name>/SKILL.md
```

---

## Phase 2 — Ask IDE and OS if unknown

1. IDE: Cursor, GitHub Copilot, Claude Code, Codex
2. OS: macOS/Linux symlink vs Windows junction/copy
3. Workspace: library alone vs nested under a parent monorepo vs dependency-only

---

## Phase 3 — Wire discovery

Canonical sources:

| Artifact | Path under `$MOD` |
|----------|-------------------|
| Agent (optional) | `ai-copilots/agents/<skill-name>.md` |
| Skill tree | `ai-copilots/skills/<skill-name>/` |

Discovery paths:

| IDE | Agents | Skills |
|-----|--------|--------|
| Cursor | `.cursor/agents/*.md` | `.cursor/skills/**/SKILL.md` |
| GitHub Copilot | `.github/agents/*.agent.md` | `.github/skills/**/SKILL.md` |
| Claude Code | `.claude/agents/*.md` | `.claude/skills/**/SKILL.md` |
| Codex | `.codex/agents/*.md` | `.codex/skills/**/SKILL.md` |

**Cursor example (macOS/Linux)** from the **host workspace root**:

```bash
MOD="$(go list -m -f '{{.Dir}}' <module-path>)"
mkdir -p .cursor/agents .cursor/skills
# optional agent:
# ln -snf "$MOD/ai-copilots/agents/<skill-name>.md" .cursor/agents/<skill-name>.md
ln -snf "$MOD/ai-copilots/skills/<skill-name>" .cursor/skills/<skill-name>
```

When the library is nested and the workspace root is the library itself,
relative links are fine:

```bash
ln -snf ../ai-copilots/skills/<skill-name> .cursor/skills/<skill-name>
```

**Windows:** prefer junction or developer-mode symlink; copy fallback only with
user approval.

**Idempotency:** skip if the link already resolves to the canonical path; ask
before overwriting stale copies.

**Parent monorepo:** some IDEs discover agents only at workspace-root
`.cursor/agents/`. Link the agent there when the user wants root discoverability.
MUST NOT edit parent skill indexes unless the user asks.

---

## Phase 4 — Verify

```bash
MOD="$(go list -m -f '{{.Dir}}' <module-path>)"
ls -la .cursor/skills/<skill-name>
test -f .cursor/skills/<skill-name>/SKILL.md
test -f "$MOD/ai-copilots/BOOTSTRAP.md"
```

Ask the user before committing host wiring (`.cursor/`, `.github/`, etc.).
```

---

## Resolve cheatsheet

```bash
# From engine/ or any consumer module that requires the library:
go list -m -f '{{.Dir}}' <module-path>

# Confirm harness:
MOD="$(go list -m -f '{{.Dir}}' <module-path>)"
ls "$MOD/ai-copilots/skills"
```

`replace` directives and `go.work` make `.Dir` point at the local checkout.
Pure cache installs point at the module cache version directory.
