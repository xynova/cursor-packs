---
name: explain-implementation
description: >-
  After finishing an implementation that changed files, explain in plain
  English what happened and how it is put together: enough for a developer to
  follow, no fluff, no forced template. Use when claiming work is done,
  summarizing an implementation, or when the user asks what you did / how it
  was built.
---

# Explain implementation

**Moral:** After you change the product, the developer must be able to re-tell
what landed and how the pieces connect without reading the whole diff. Say
enough. Do not pad.

**Voice:** Still follow `.cursor/rules/always-rules-01-human-interaction.mdc`
(fluent consultant, no icon-prefixed reply headings). This skill owns the
**content** of the post-implementation explain, not a rigid reply template.

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

**CONSTRAINT:** The final reply after an implementation MUST explain, in plain English, (1) what is different now and (2) how the change is put together (the important steps or moving parts). MUST NOT require fixed heading names, a fixed section count, or filler paragraphs.

- MUST: cover outcome + how it fits together, briefly.
- MUST NOT: invent “what stayed the same”, “who wrote key pieces”, or other sections when they add nothing.
- MUST NOT: pad with restating the task, praising the approach, or repeating the same point.
- Enforcement: Before send, a cold reader could answer “what changed?” and “how does it work now?” from the reply alone.
- Violation: STOP, tighten or fill the gap, then send.

CORRECT (compact; headings optional):
```markdown
Digest can now open a product PR that promotes the refined typology catalog onto default when the confirmed catalog drifted.

After the context PR finishes, Go compares confirmed vs refined YAML. On drift it pushes `majordomo-typology/…-update` and opens a PR against default. No new LLM calls; the PR body reuses findings digest already wrote.
```

CORRECT (when a short walkthrough helps):
```markdown
The promote path is mechanical and runs after the usual digest:

1. Skip unless survey mode was reuse.
2. Compare confirmed and refined catalogs.
3. On drift, write `.typology/typology.yaml` on a default-targeted branch and open/restack the product PR.
```

PROHIBITED:
```markdown
Changed typology_promote.go, run.go, poll.go, and the docs.
Tests pass. Want me to commit?
```

PROHIBITED (fluff / rigid ceremony):
```markdown
## Short answer
Great question — here's what I accomplished for you today...

## What stayed the same
Many things stayed the same...

## What is new
## Who wrote key pieces
(empty sections or filler to satisfy a template)
```

**CONSTRAINT:** When you describe steps, they MUST be behavior a developer can follow in their head (inputs, decisions, outputs). MUST NOT replace the explain with only paths, symbol names, or commit hashes. Identifiers MAY appear after the prose or in parentheses.

- Enforcement: The reply has at least one behavior sentence; not a bare file list.
- Violation: STOP, rewrite in behavior language.

**CONSTRAINT:** MUST NOT use icon-prefixed headings (`✅`, `🔍`, `🧭`, `➡️`, `❓`). MUST NOT ship a telegraph dump (one path per line with no why).

- Enforcement: Scan before send.
- Violation: Rewrite in fluent prose.

**CONSTRAINT:** When a reader might wrongly assume an LLM wrote a piece (PR body, config, docs), MUST say in one plain sentence whether that piece is mechanical, LLM-backed, or human-owned. MUST NOT add an authorship essay when nothing is confusable.

- Enforcement: Only if confusion is plausible.
- Violation: STOP, add or remove that one sentence.

---

## Agent procedure

1. **Detect** — File-changing implement/fix, or user asked what you did.
2. **Say what is different** — Outcome in plain English.
3. **Say how it is put together** — Only the steps or parts that matter; omit the rest.
4. **Clarify authorship** — One sentence only if LLM vs mechanical could be confused.
5. **Evidence lightly** — Optional short path list after the prose.
6. **Stop** — No filler. One next-step question is fine when useful.

---

## Pre-completion checklist

- [ ] **Enough explain:** Reply answers what changed and how it fits together
      Method: Cold-reader test
      Pass: Both clear without opening the diff
      Fail: STOP, add the missing beat
- [ ] **No fluff / no forced template:** No empty ceremonial sections; no padding
      Method: Scan for filler and mandatory-looking empty headings
      Pass: Every sentence earns its place
      Fail: STOP, cut or rewrite
- [ ] **Not a file dump:** Behavior is present; paths are secondary
      Method: Read first screen of reply
      Pass: Prose first
      Fail: STOP, rewrite
- [ ] **No icon template:** No ✅/🔍/🧭 reply scaffolding
      Method: Scan headings
      Pass: Ordinary markdown or plain paragraphs
      Fail: STOP, rewrite
