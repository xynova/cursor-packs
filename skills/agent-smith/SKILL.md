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

**Candidate gates:** [gates.md](gates.md)

If the path is a symlink into `.cursor/packs/shared/`, also load `edit-cursor-packs` and commit in **cursor-packs**.

---

## Table of Contents

1. [Intent gate](#intent-gate)
2. [Mandatory writing standards](#mandatory-writing-standards)
3. [Artifact types](#artifact-types)
4. [Pre-completion verification](#pre-completion-verification)
5. [Workflow](#workflow)
6. [Prohibited patterns](#prohibited-patterns)

Candidate-filter patterns live in [gates.md](gates.md).

---

## Intent gate

This skill is a skill-named task, so always-rules-01-human-interaction loads neither Intent-First nor Consultant. This section is the skill's own front door.

**CONSTRAINT:** MUST NOT write or edit an artifact until the artifact type, its loader, and its done state are known.

- Known: the user asked to port, fix, or review a named existing file (the source fixes the scope), or asked to create an artifact and stated its scope and what done looks like. Proceed to [Workflow](#workflow).
- Unknown: anything else, including a request that names only the artifact type ("make me a skill for X"). State in 1-3 sentences what artifact you would build, what it covers, what loads it, and what done looks like. Ask one question about the part you are least sure of. Wait.
- Enforcement: before the first write, quote the user's words that fix the scope. If none exist, it is Unknown.
- Violation: STOP, revert the write, state the hypothesis, wait.

**CONSTRAINT:** MUST present numbered options only when two artifact choices would ship different files or behavior (for example skill vs always-on rule). MUST recommend one first. MUST NOT end with `Does this match what you have in mind?`

- Enforcement: collapsing any two options would change what gets built.
- Violation: delete the menu, recommend one, ask whether to do it.

CORRECT (only the type is named):
```markdown
I would make a project skill that reviews your uncommitted changes for correctness bugs, reports each finding with the quoted line, and edits nothing until you pick which to fix. It would load when you ask for a review.

Should it cover only bugs, or also style and naming?
```

CORRECT (scope already locked):
```markdown
I would put the wait-before-write pause in pack Agent Smith and drop the scripted confirmation line.

Want me to write it?
```

PROHIBITED:
```markdown
1. Skill
2. Rule
3. Skill plus rule

Does this match what you have in mind?
```

---

## Mandatory writing standards

**CONSTRAINT:** Requirements MUST use MUST / MUST NOT / NEVER / ALWAYS. NEVER use "should", "consider", or "try to".

**CONSTRAINT:** Every constraint MUST name an enforcement method and a violation action.

**CONSTRAINT:** Every non-trivial constraint MUST include CORRECT and PROHIBITED examples (or point to a template in `reference.md`).

**CONSTRAINT:** Checklist items MUST be binary TRUE/FALSE with an explicit Method / Pass / Fail.

**CONSTRAINT:** Any step of the form "for each X, decide Y" or "only include X if Z" MUST use the Forced Intermediate State gate from [gates.md](gates.md), not a prose rule.

- Enforcement: grep the draft for `for each`, `only include`, `decide whether`; each hit sits inside a gate template from [gates.md](gates.md).
- Violation: STOP, rewrite the step as a gate.

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

### Intent
- [ ] **Scope known before first write:** artifact type, loader, and done are fixed
      Method: Quote the user's words that lock those three, or confirm this turn waited with one question
      Pass: quoted lock, or no write on an Unknown ask
      Fail: STOP, revert the write, state the hypothesis, wait

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
- [ ] **Gates for candidate filtering:** "for each / only include / decide whether" uses [gates.md](gates.md)
      Method: Grep the draft for `for each|only include|decide whether`
      Pass: every hit is inside a gate template, or the file has no candidate loop
      Fail: STOP, convert to a gate

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

1. **Gate:** pass [Intent gate](#intent-gate).
2. **Classify** — skill vs rule vs reference; pack-linked vs consumer overlay.
3. **Draft constraints** — 3-7 core MUST/NEVER for the domain.
4. **Structure** — copy the matching template from [reference.md](reference.md).
5. **Fill** — constraints with enforcement + examples; gates for candidate filtering; binary checklist if the skill is long.
6. **Verify** — run [Pre-completion verification](#pre-completion-verification) to 100%.
7. **Ship** — if pack-linked: branch/commit in cursor-packs per `edit-cursor-packs`; else commit in the consumer.

---

## Prohibited patterns

- Vague requirements without verification ("keep it clean")
- Constraints without CORRECT/PROHIBITED (or template pointer)
- Human-rationale essays instead of commands
- Untestable checklist items ("looks good")
- Dropping Copilot League `agent-smith.agent.md` unchanged into cursor-packs
- Committing pack symlinks' content as consumer-owned files
- The scripted line `Does this match what you have in mind?`
- A prose "for each X, decide Y" or "only include X if Z" step with no gate from [gates.md](gates.md)
