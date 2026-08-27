# Agent Smith (Cursor) templates

LOAD-WHEN: authoring or reviewing Cursor `SKILL.md`, `.mdc`, or skill `reference.md` under Agent Smith standards.

Adapted from Copilot League `agents/agent-smith.agent.md` and `agents/templates/*` for Cursor hosts.

---

## Constraint with enforcement

```markdown
**CONSTRAINT:** [Specific requirement]

- MUST: [Required behavior]
- MUST NOT: [Prohibited behavior]

Enforcement: [command, grep, checklist step, or structural check]
Violation: STOP, [fix], re-verify

CORRECT:
[minimal example]

PROHIBITED:
[anti-pattern]
```

---

## Binary checklist item

```markdown
- [ ] **[Item name]:** [Verifiable condition]
      Method: [exact check]
      Pass: [TRUE looks like]
      Fail: [FALSE looks like] → STOP, [fix]
```

---

## Cursor skill template (`SKILL.md`)

```markdown
---
name: skill-name
description: >-
  Third-person what + when. Include trigger terms. Max ~1024 chars.
---

# Skill Name

## When to load

Load when [specific task, path, or failure mode].

## Core constraints

**CONSTRAINT:** ...
- Enforcement: ...
- Violation: ...

## Steps

1. **[Name]** — exact action; pass/fail signal
2. **[Name]** — ...

## Pre-completion checklist

- [ ] **...:** ...
      Method: ...
      Pass: ...
      Fail: ...
```

---

## Cursor rule template (`.mdc`)

```markdown
---
description: >-
  Third-person what + when. Include trigger terms.
globs:
  - path/pattern/**
alwaysApply: false
---

# Short title

- MUST ...
- MUST NOT ...
- For the full workflow: `.cursor/skills/<name>/SKILL.md`
```

Use `alwaysApply: true` and omit `globs` when the rule is global.

---

## Reference template (`reference.md`)

Use this shape (do not nest triple-backtick fences inside a markdown code block when editing live files; copy the structure):

- Title + `LOAD-WHEN:` one sentence
- `## [Domain] [Concern]`
- `### [Pattern name]`
- Working code fence
- `**Rules:**` MUST/NEVER bullets
- Optional PROHIBITED code fence

File length target: roughly 200-600 lines; split by concern above that.

---

## Copilot vs Cursor (do not mix)

| Concern | Copilot League agent | Cursor skill/rule |
|---------|----------------------|-------------------|
| Name | emoji + UPPER-CASE | kebab-case `name` |
| Host path | `.github/agents/*.agent.md` | `.cursor/skills`, `.cursor/rules` |
| Persona / TOC-first Persona | Required for agents | Not required for skills/rules |
| `argument-hint` / `tools` / `handoffs` | Copilot agent fields | Omit unless dual-host doc |
| Meta author for agents | `@agent-smith` in Copilot | This skill in Cursor |
