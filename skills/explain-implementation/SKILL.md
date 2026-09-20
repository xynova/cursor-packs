---
name: explain-implementation
description: >-
  After finishing an implementation that changed files, explain what changed
  in plain English: short answer, what stayed the same, what is new step by
  step, and who wrote key pieces (LLM vs mechanical code). Use when claiming
  work is done, summarizing an implementation, or when the user asks what you
  did / how it was built.
---

# Explain implementation

**Moral:** After you change the product, the developer must be able to re-tell
what landed without reading the whole diff. Your last reply owns that teaching
pass. File lists and SHAs are evidence, not the explanation.

**Voice:** Still follow `.cursor/rules/always-rules-01-human-interaction.mdc`
(fluent consultant, no icon-prefixed reply headings). This skill owns the
**structure** of the post-implementation explain, not a second chat persona.

---

## When to load

Load and follow this skill before the final user-facing reply when **any** of:

- You edited, created, or deleted project files to implement or fix something
- You are about to say the work is done, ready to commit, or ready to PR
- The user asks what you did, how it was built, or to explain the change

MUST NOT skip because the turn also ran tests or opened a PR.

MUST NOT load this skill for pure Q&A with no file changes (unless the user
asks you to explain a prior implementation).

---

## Core constraints

**CONSTRAINT:** The final reply after an implementation MUST include a plain-English explain pass with these sections (use ordinary markdown headings, no icons):

1. **Short answer** — one or two sentences: what the system can do now that it could not before (or what bug is gone).
2. **What stayed the same** — only when useful; name the unchanged path so the reader does not think everything moved.
3. **What is new** — numbered steps in everyday words for the new or changed path (runtime or authoring flow), not a file inventory.
4. **Who wrote key pieces** — when the reader might assume an LLM wrote something: state whether a step is LLM-backed, mechanical code, or human-owned docs. Skip this section when nothing could be confused.

- Enforcement: Before send, check the four section intents appear (2 and 4 MAY be omitted with a one-line reason in the draft only; do not apologize to the user for omitting).
- Violation: STOP, rewrite the explain pass, then send.

CORRECT:
```markdown
## Short answer

Digest can open a product PR that promotes a refined typology catalog onto default when the confirmed catalog drifted.

## What stayed the same

Survey, refine, and the context-branch teaching PR still run as before.

## What is new

1. After the context PR finishes, compare confirmed and refined catalogs.
2. On drift, push a typology promote branch and open a PR against default.
3. Never auto-merge that product PR.

## Who wrote key pieces

No new LLM calls. The PR body is assembled in Go from findings and markdown digest already wrote.
```

PROHIBITED:
```markdown
Changed typology_promote.go, run.go, poll.go, and the docs.
Tests pass. Want me to commit?
```

**CONSTRAINT:** Steps MUST describe behavior a developer can follow in their head (inputs, decisions, outputs). MUST NOT replace steps with only paths, symbol names, or commit hashes. Identifiers MAY follow a step in parentheses or a short list after the prose.

- Enforcement: Each numbered step has a verb about system behavior (compare, write, skip, open), not only “updated X.go”.
- Violation: STOP, rewrite steps in behavior language.

CORRECT:
```markdown
1. Read the typology manifest. If mode is not reuse, skip.
2. Compare confirmed and refined catalogs after normalizing YAML.
```

PROHIBITED:
```markdown
1. typology_promote.go
2. finishDigestRun hook
3. PushForce
```

**CONSTRAINT:** MUST NOT use icon-prefixed headings (`✅`, `🔍`, `🧭`, `➡️`, `❓`) in the explain pass. MUST NOT ship a telegraph dump (one path per line with no why).

- Enforcement: Scan the explain sections before send.
- Violation: Rewrite in fluent prose under ordinary headings.

**CONSTRAINT:** When the implementation added a mechanical path next to an LLM path, MUST say that clearly in **Who wrote key pieces** (or inside **What is new** if section 4 is omitted).

- Enforcement: If the change includes “no new LLM” / template / forge-only / pure compare-write, that fact appears in the reply.
- Violation: STOP, add one plain sentence naming mechanical vs LLM.

---

## Steps (agent procedure)

1. **Detect** — You changed files for an implement/fix, or the user asked what you did. If neither, do not force this skill.
2. **Draft Short answer** — Outcome in plain English first.
3. **Draft What stayed the same** — Only if an old path still runs and confusion is likely; otherwise omit.
4. **Draft What is new** — Numbered behavior steps for the new path end to end.
5. **Draft Who wrote key pieces** — LLM vs mechanical vs human, when relevant.
6. **Attach evidence lightly** — Optional short list of key paths or commands after the prose.
7. **Align voice** — Complete sentences; lead with the answer; one next-step question if useful (commit, PR), not a menu of methods.

---

## Pre-completion checklist

- [ ] **Explain pass present:** Final reply has Short answer + What is new (behavior steps)
      Method: Read draft headings / section intents
      Pass: Both present in plain English
      Fail: STOP, add the explain pass
- [ ] **Steps are behavioral:** Numbered steps use system verbs, not file-name lists
      Method: Read each step
      Pass: A cold reader can retell the flow
      Fail: STOP, rewrite steps
- [ ] **LLM vs mechanical cleared:** Confusable authorship is stated
      Method: Ask “would a reader think a model wrote the PR body / config / docs?”
      Pass: Stated or clearly N/A
      Fail: STOP, add one sentence
- [ ] **No icon template:** No ✅/🔍/🧭 reply scaffolding
      Method: Scan headings
      Pass: Ordinary markdown only
      Fail: STOP, rewrite
