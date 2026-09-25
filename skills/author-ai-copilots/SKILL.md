---
name: author-ai-copilots
description: >-
  Author and wire library-owned ai-copilots harnesses (AGENTS.md, BOOTSTRAP,
  skills, agents) for Cursor, GitHub Copilot, Claude Code, and Codex. Use when
  creating or migrating a library operator pack, standardizing skills as
  ai-copilots, or linking a Go module dependency's copilots into a host IDE.
---

# Author ai-copilots

**Moral:** Libraries that expect AI to operate them ship an in-module `ai-copilots/` tree. Hosts wire discovery via BOOTSTRAP; they do not copy skill bodies. Go imports never expose markdown, so dependency consumers resolve the module Dir then symlink.

**Templates:** [reference.md](reference.md) (layout, `AGENTS.md` stub, portable `BOOTSTRAP.md`).

**Related:** skill bodies use [agent-smith](../agent-smith/SKILL.md). Pack-owned edits use [edit-cursor-packs](../edit-cursor-packs/SKILL.md).

---

## When to load

- Creating `ai-copilots/` or `AGENTS.md` for a library or CLI module
- Migrating top-level `skills/` into `ai-copilots/skills/`
- Wiring a dependency's copilots into `.cursor/`, `.github/`, `.claude/`, or `.codex/`
- Reviewing whether a Go library that agents must operate ships in-module skills

When the baseline is missing, load [ai-readiness](../ai-readiness/SKILL.md) first.

---

## Layout contract

**CONSTRAINT:** Canonical operator content MUST live under the library module root as `ai-copilots/`.

- MUST include: `ai-copilots/README.md`, `ai-copilots/BOOTSTRAP.md`, `ai-copilots/skills/<name>/SKILL.md`
- MAY include: `ai-copilots/agents/<name>.md` (subagent manifests), skill shards next to `SKILL.md`
- MUST ship inside the published Go module (not gitignored) so `go get` / module cache / vendor receive the tree
- MUST NOT use a top-level `skills/` alone as the long-term canonical path; migrate to `ai-copilots/skills/`

Enforcement: tree exists at module root; `go list -m -f '{{.Dir}}' <module>` contains `ai-copilots/skills/`
Violation: STOP, create or move into `ai-copilots/`, re-verify

CORRECT:
```text
<module-root>/
  AGENTS.md
  ai-copilots/
    README.md
    BOOTSTRAP.md
    agents/optional-operator.md
    skills/
      my-lib-operator/SKILL.md
```

PROHIBITED:
```text
<module-root>/skills/only-here/SKILL.md
# no ai-copilots/, no BOOTSTRAP, host copies bodies into .cursor/skills/
```

---

## AGENTS.md contract

**CONSTRAINT:** Root `AGENTS.md` MUST be the product-neutral entry that points agents into `ai-copilots/`.

- MUST list load order (index → operator / journey skills)
- MUST stay portable (no host brand, no private host layout paths)
- MUST NOT embed full skill bodies; link to `ai-copilots/skills/.../SKILL.md`
- MUST document optional IDE symlink via BOOTSTRAP (or a short pointer to it)

Enforcement: open `AGENTS.md`; first skill links resolve under `ai-copilots/`
Violation: STOP, rewrite pointers, re-verify

---

## Authoring checklist

When writing or reviewing skill bodies under `ai-copilots/skills/`:

1. Load [agent-smith](../agent-smith/SKILL.md) and apply its skill checklist.
2. Keep commands runnable from the library repo (or documented consumer CLI).
3. MUST NOT spill one host product's brand, private paths, or workflows into the library harness ([repository-boundaries](../../rules/repository-boundaries.mdc)).

- [ ] **Frontmatter:** each `SKILL.md` has `name` and `description`
      Method: YAML parse
      Pass: keys present
      Fail: STOP, add keys
- [ ] **In-module:** `ai-copilots/` is not gitignored and is present in module Dir
      Method: `go list -m -f '{{.Dir}}' <module>` + `test -d .../ai-copilots`
      Pass: directory exists
      Fail: STOP, un-ignore or move tree
- [ ] **Entry:** `AGENTS.md` points at `ai-copilots/`
      Method: Read links
      Pass: all skill links under `ai-copilots/`
      Fail: STOP, fix links

---

## Consumer wire modes

**CONSTRAINT:** Before creating host discovery links, MUST resolve the library module root in this order:

1. `go list -m -f '{{.Dir}}' <module-path>` from a module that requires the library (honors `replace`, `go.work`, cache, vendor)
2. Known nested checkout path only when `go list` is unavailable and the path clearly contains `ai-copilots/`
3. Fail closed with a clear message (MUST NOT invent a path)

Enforcement: print resolved Dir; confirm `ai-copilots/BOOTSTRAP.md` exists
Violation: STOP, fix module require/`replace`, re-resolve

**CONSTRAINT:** Host discovery paths MUST prefer symlink (macOS/Linux) or junction (Windows) to the canonical `ai-copilots/` tree. MUST NOT copy skill bodies unless links fail and the user approves copy fallback.

**CONSTRAINT:** After a module version bump that changes the cache Dir, MUST re-run BOOTSTRAP wire (old symlinks go stale).

### IDE discovery matrix

| IDE | Agents | Skills |
|-----|--------|--------|
| Cursor | `<workspace-root>/.cursor/agents/*.md` | `.cursor/skills/**/SKILL.md` |
| GitHub Copilot | `.github/agents/*.agent.md` | `.github/skills/**/SKILL.md` |
| Claude Code | `.claude/agents/*.md` | `.claude/skills/**/SKILL.md` |
| Codex | `.codex/agents/*.md` | `.codex/skills/**/SKILL.md` |

Ask IDE and OS before wiring when unknown. Full portable procedure: [reference.md](reference.md) § BOOTSTRAP template.

CORRECT:
```bash
MOD="$(go list -m -f '{{.Dir}}' github.com/example/lib)"
ln -snf "$MOD/ai-copilots/skills/lib-operator" .cursor/skills/lib-operator
```

PROHIBITED:
```bash
cp -R "$(go env GOMODCACHE)/.../skills/" .cursor/skills/lib-operator
# no go list; guessed cache path; duplicated bodies
```

---

## Dependency vs nested checkout

| Mode | How code arrives | How agents get skills |
|------|------------------|------------------------|
| Nested checkout / submodule | `replace` or path under `providers/` | Resolve Dir (or known path) → BOOTSTRAP symlink |
| Pure Go dependency | `go get` → module cache / vendor | `go list -m -f '{{.Dir}}'` → BOOTSTRAP symlink |
| Skills only in cursor-packs | N/A for library-specific ops | Wrong place for a single library's operator pack; move into that library's `ai-copilots/` |

Cross-product shared skills (for example generic Go quality) MAY stay in cursor-packs. Library-specific operate/author skills and domain vocabulary MUST live in that library's `ai-copilots/` and reach the host by **link** (BOOTSTRAP), never by adding them to cursor-packs.

**CONSTRAINT:** MUST NOT create or expand cursor-packs skills/rules/personas for a single library's operator content. Load `edit-cursor-packs` membership gate; if question (2) is yes, write under `ai-copilots/` only.

- Enforcement: Proposed path is under `<module>/ai-copilots/` or fails the pack gate
- Violation: STOP, move out of cursor-packs, wire via BOOTSTRAP

---

## Workflow

1. Confirm ownership: library repo vs host vs cursor-packs.
2. Run [ai-readiness](../ai-readiness/SKILL.md) audit first. If the baseline is
   missing, scaffold with that skill (or continue here using the same layout).
3. Create or migrate `ai-copilots/` using [reference.md](reference.md) layout.
4. Write `AGENTS.md` entry + skill bodies (agent-smith).
5. Add `BOOTSTRAP.md` from the portable template (fill module path and skill names).
6. Wire host discovery (wire-only mode) when the user asks.
7. Verify: `ls -la` links resolve; `go list -m` Dir contains `ai-copilots/`;
   ai-readiness checklist passes.

---

## Pre-completion verification

- [ ] **Layout:** `ai-copilots/README.md`, `BOOTSTRAP.md`, and at least one `skills/*/SKILL.md` exist
- [ ] **AGENTS.md:** points into `ai-copilots/` only for skill load order
- [ ] **Resolve:** documented `go list -m` recipe uses the real module path
- [ ] **No spill:** pack template and library harness have no single-host private paths
- [ ] **Agent-smith:** skill bodies pass Agent Smith skill checklist when newly authored
