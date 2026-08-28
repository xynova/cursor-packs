---
name: agent-smith
description: >-
  Author and review Cursor skills (SKILL.md) and rules (.mdc) using Agent Smith
  standards: MUST/NEVER constraints, binary checklists, CORRECT/PROHIBITED
  examples. Use when creating or improving .cursor/skills or .cursor/rules, or
  when asked for Agent Smith / meta-agent authoring in Cursor.
---

# Agent Smith (Cursor)

Port of Copilot League **AGENT-SMITH** standards to Cursor artifacts.

**Source of truth for GitHub Copilot `.agent.md` files:** keep using Copilot League `agents/agent-smith.agent.md`. This skill does **not** replace that for VS Code Copilot agents.

**Targets here:** `.cursor/skills/*/SKILL.md`, optional `reference.md`, and `.cursor/rules/*.mdc`.

**Templates:** [reference.md](reference.md)

If the path is a symlink into `.cursor/packs/shared/`, also load `edit-cursor-packs` and commit in **cursor-packs**.

---

## Table of Contents

1. [Mandatory writing standards](#mandatory-writing-standards)
2. [Artifact types](#artifact-types)
3. [Pre-completion verification](#pre-completion-verification)
4. [Workflow](#workflow)
5. [Prohibited patterns](#prohibited-patterns)

---

## Mandatory writing standards

**CONSTRAINT:** Requirements MUST use MUST / MUST NOT / NEVER / ALWAYS. NEVER use "should", "consider", or "try to".

**CONSTRAINT:** Every constraint MUST name an enforcement method and a violation action.

**CONSTRAINT:** Every non-trivial constraint MUST include CORRECT and PROHIBITED examples (or point to a template in `reference.md`).

**CONSTRAINT:** Checklist items MUST be binary TRUE/FALSE with an explicit Method / Pass / Fail.

CORRECT:
```markdown
**CONSTRAINT:** Skill frontmatter MUST include `name` and `description`.
- Enforcement: YAML parse + required keys present
- Violation: STOP, add keys, re-verify

CORRECT:
---
name: golang-quality
description: Go generation constraints and quality gates.
---

PROHIBITED:
---
description: missing name
---
```

PROHIBITED:
```markdown
Skills should have clear descriptions.
```

---

## Artifact types

| Artifact | Path | Apply full skill checklist? |
|----------|------|-----------------------------|
| Skill | `.cursor/skills/<name>/SKILL.md` | YES |
| Skill reference | `.cursor/skills/<name>/reference.md` (etc.) | NO (reference rules only) |
| Rule | `.cursor/rules/<name>.mdc` | YES (rule checklist) |
| Copilot `.agent.md` | Copilot League / `.github/agents/` | NO here — use Copilot Agent Smith |

### Skill frontmatter (Cursor)

MUST include:
- `name`: lowercase kebab-case, unique in the project
- `description`: third person; what + when; include trigger terms

MAY include: `disable-model-invocation: true`

MUST NOT require Copilot-only fields (`argument-hint`, emoji UPPER-CASE `name`, `tools`, `agents`, `handoffs`) unless documenting a dual-host file.

### Rule frontmatter (Cursor)

MUST include `description` (third person + triggers).

MUST set either `alwaysApply: true` OR non-empty `globs`.

MUST NOT duplicate a full skill body; point to a skill path instead.

### References

Dense pattern libraries with LOAD-WHEN, MUST/NEVER bullets, working examples.

MUST NOT apply persona / agent-file Copilot checklists to references.

---

## Pre-completion verification

Execute in order. Stop at first failure. Fix, then restart.

### Language
- [ ] **Imperative only:** MUST/NEVER/ALWAYS; no suggestion language
      Method: Scan requirements for should/consider/try
      Pass: None found in constraints
      Fail: STOP, rewrite as constraints
- [ ] **Enforcement present:** Each CONSTRAINT has Enforcement + Violation
      Method: Count CONSTRAINT vs Enforcement pairs
      Pass: Every CONSTRAINT has both
      Fail: STOP, add missing slots
- [ ] **Examples present:** Non-trivial constraints have CORRECT/PROHIBITED (or template link)
      Method: Spot-check each CONSTRAINT block
      Pass: Examples or explicit template pointer
      Fail: STOP, add examples

### Skill (`SKILL.md`) only
- [ ] **Frontmatter:** `name` + `description` present and kebab-case name
- [ ] **When to use:** Description or body states concrete load triggers
- [ ] **Steps or constraints:** Procedure is executable without guessing
- [ ] **No Copilot agent checklist:** No TOC-must-start-with-Persona requirement unless authoring a Copilot `.agent.md` elsewhere
- [ ] **Pack ownership:** If path symlinks to `packs/shared`, `edit-cursor-packs` workflow followed

### Rule (`.mdc`) only
- [ ] **Frontmatter:** `description` + (`alwaysApply` XOR `globs`)
- [ ] **Short body:** Imperative bullets; skill pointer when workflow is long
- [ ] **No skill dump:** Full procedures live in a skill, not the rule

### Reference only
- [ ] **LOAD-WHEN** (or equivalent) is specific
- [ ] Patterns use working examples + MUST/NEVER rules
- [ ] No skill/rule frontmatter requirements applied

---

## Workflow

### Blocking (skills and rules)

1. State a 1-3 sentence intent hypothesis (what artifact, who loads it, what "done" means).
2. Ask: "Does this match what you have in mind?"
3. MUST wait for confirmation before writing the file (unless the user already gave an explicit implement request with scope locked).

### Steps

1. **Classify** — skill vs rule vs reference; pack-linked vs consumer overlay.
2. **Draft constraints** — 3-7 core MUST/NEVER for the domain.
3. **Structure** — copy the matching template from [reference.md](reference.md).
4. **Fill** — constraints with enforcement + examples; binary checklist if the skill is long.
5. **Verify** — run [Pre-completion verification](#pre-completion-verification) to 100%.
6. **Ship** — if pack-linked: branch/commit in cursor-packs per `edit-cursor-packs`; else commit in the consumer.

---

## Prohibited patterns

- Vague requirements without verification ("keep it clean")
- Constraints without CORRECT/PROHIBITED (or template pointer)
- Human-rationale essays instead of commands
- Untestable checklist items ("looks good")
- Dropping Copilot League `agent-smith.agent.md` unchanged into cursor-packs
- Committing pack symlinks' content as consumer-owned files
