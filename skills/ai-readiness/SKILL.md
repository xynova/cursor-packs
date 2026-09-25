---
name: ai-readiness
description: >-
  Audit and scaffold the required AGENTS.md plus ai-copilots harness so any
  agent can operate a repository. Use when setting up a repo, checking AI
  readiness, missing AGENTS.md or ai-copilots/, wiring BOOTSTRAP, or before
  claiming a checkout is agent-operable.
---

# AI readiness

**Moral:** Every repository agents touch MUST ship a root `AGENTS.md` and an
in-repo `ai-copilots/` tree. Without that harness, operators invent workflows.
This skill audits and scaffolds the baseline; library-specific recipes stay in
that repo's skills.

**Templates:** [reference.md](reference.md). Authorship layouts:
[author-ai-copilots](../author-ai-copilots/SKILL.md). Skill body standards:
[agent-smith](../agent-smith/SKILL.md).

**Persona:** When the human asks if a repo is AI-ready or how to set it up and
a real scaffold fork exists, also Read
`.cursor/personas/ai-readiness.persona.md`.

---

## When to load

- Repo setup, new checkout, or "is this AI ready?"
- Missing `AGENTS.md` or `ai-copilots/`
- Before claiming agents can operate a module
- Before authoring a new library operator skill (audit first, then author)

---

## Ownership

**CONSTRAINT:** Before writing harness files, MUST resolve which git repository
owns the path (`git rev-parse --show-toplevel`).

- Enforcement: print toplevel; confirm it matches the intended repo
- Violation: STOP, change directory to the owning root, re-resolve

**CONSTRAINT:** MUST NOT put one host's brand, private layout, or product-only
workflows into another library's `ai-copilots/`. MUST NOT add library-specific
operator content to cursor-packs.

- Enforcement: review planned paths and skill prose for host spill
- Violation: STOP, keep portable wording; move host spill to the host overlay

---

## Baseline contract

**CONSTRAINT:** A repository is AI-operable only when all of the following are
true at its git root:

1. `AGENTS.md` exists and points skill load order into `ai-copilots/`
2. `ai-copilots/README.md` exists
3. `ai-copilots/BOOTSTRAP.md` exists
4. At least one `ai-copilots/skills/*/SKILL.md` exists
5. Harness files contain no committed secrets
6. BOOTSTRAP documents how to wire IDE discovery (symlink preferred)

- Enforcement: run the audit checklist below
- Violation: MUST NOT claim the repo is agent-operable; report gaps and scaffold
  or wait for a pick when the readiness persona applies

CORRECT:
```text
repo/
  AGENTS.md
  ai-copilots/
    README.md
    BOOTSTRAP.md
    skills/my-operator/SKILL.md
```

PROHIBITED:
```text
repo/ with only README.md
# or AGENTS.md that embeds full skill bodies with no ai-copilots/
```

---

## Modes

### Audit

1. Resolve git root.
2. Run the checklist in [reference.md](reference.md).
3. Report each item as pass or fail with the missing path.
4. If any item fails, state that the repo is not AI-operable yet.

### Scaffold

1. Run audit first.
2. Load [author-ai-copilots](../author-ai-copilots/SKILL.md) and copy the
   portable stubs from its `reference.md`.
3. Create a minimal operator skill named for the product-neutral module role
   (for example `dss-eval-operator`), not a host brand.
4. Write `AGENTS.md` load order that points only into `ai-copilots/`.
5. Fill `BOOTSTRAP.md` module path and skill names.
6. Re-run audit until it passes (wire may still be pending).

### Wire

1. Confirm audit passes for files on disk.
2. Execute `ai-copilots/BOOTSTRAP.md` in wire-only mode from the workspace the
   IDE opens.
3. Prefer symlink or junction; MUST NOT copy skill bodies unless links fail and
   the user approves copy fallback.
4. Verify `test -f .cursor/skills/<name>/SKILL.md` (or the IDE path BOOTSTRAP
   documents).

---

## Fail closed

**CONSTRAINT:** MUST NOT tell the human a repository is ready for agents while
any baseline checklist item fails.

- Enforcement: final reply lists remaining fails, or states all pass
- Violation: STOP, correct the claim, list gaps

**CONSTRAINT:** MUST NOT run domain workflows (eval suites, conformance, deploys)
as a substitute for scaffolding the harness.

- Enforcement: if the ask is readiness or missing AGENTS/ai-copilots, scaffold
  or audit first
- Violation: STOP, return to audit/scaffold

---

## Pre-completion verification

- [ ] **Root:** Work targets the owning git toplevel
      Method: `git rev-parse --show-toplevel`
      Pass: path matches intended repo
      Fail: STOP, change root
- [ ] **Checklist:** Every baseline item is pass or an explicit remaining fail
      Method: Walk reference checklist
      Pass: Binary results recorded
      Fail: STOP, finish audit
- [ ] **No secrets:** New harness files have no passwords, tokens, or DB URLs
      Method: Scan AGENTS.md and ai-copilots/
      Pass: No secret material
      Fail: STOP, remove secrets; use env docs only
- [ ] **Author path:** New skill bodies pass agent-smith when authored
      Method: Frontmatter + MUST/NEVER constraints
      Pass: Checklist green
      Fail: STOP, fix skill body
