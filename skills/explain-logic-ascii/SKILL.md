---
name: explain-logic-ascii
description: >-
  Explain existing control flow with a self-describing ASCII TIME diagram:
  numbered phases, Goal per phase, parallel vs sequential, what persists, and
  what happens if a shared timer dies. Use when explaining how logic runs,
  sequential vs parallel, prefetch vs persist, pipelines, deadlines, or when
  the user asks for an ASCII diagram of behavior.
---

# Explain logic (ASCII TIME)

**Moral:** A cold reader must see order, fan-out, and durable writes without
decoding symbol names. Name the pieces in one or two sentences, then ship a
timeline that stands alone.

**Voice:** Follow rule `always-rules-01-human-interaction` for prose before the
diagram. This skill owns the figure, not a prose essay.

**Does not replace:** Skill `explain-implementation` (post-change Objective /
Trajectory / Outcome). You MAY add an ASCII TIME block inside `Explanation` when
sequential vs parallel matters. MUST NOT replace those channel headings.

---

## When to load

Load when this turn explains **how existing logic runs**:

- Order of steps, what runs in parallel vs one-at-a-time
- Prefetch or cache vs durable persist
- A shared deadline or context timeout across phases
- User asks for an ASCII diagram, timeline, or "is X sequential?"

MUST NOT load for a yes/no with no mechanism, or when the user only wants a
code citation with no control-flow story.

---

## Core constraints

**CONSTRAINT:** After naming the pieces in prose, MUST include one fenced
`text` ASCII diagram with a TIME axis (top or left).

- MUST: Number phases (`1.`, `2.`, ...).
- MUST: Include a `Goal:` line per phase in everyday words (what the phase is for).
- MUST: Show what is in flight together vs what waits.
- MUST: State what is written (or not) at the end of each phase.
- MUST: When a shared timer or deadline exists, state what happens if it dies
  during each phase that can be cut short.
- MUST NOT: Use Mermaid as the only figure when order, fan-out, or a shared
  deadline is the point.
- MUST NOT: Use unlabeled boxes, identifier-only labels, or icon-prefixed
  headings inside the diagram.
- MUST NOT: Rely on the essay to explain which step persists data.

Enforcement: Read the fenced block alone; if Goal, wait, and persist are
unclear, rewrite before send.
Violation: STOP, add Goal lines and timer-death branch, then send.

CORRECT:

```text
ONE TIMER for the whole job  (e.g. 60 minutes)
|==================================================================|

TIME
  |
  |  1. SKIM
  |     Goal: get a short structured summary for many items.
  |     Not the durable write. Store still empty.
  |
  |     Take 8 items, chat all 8 at once:
  |
  |       item 1 --chat--> |
  |       item 2 --chat--> |   wait until this 8 finishes
  |       ...              |
  |       item 8 --chat--> |
  |
  |     Remember answers in memory.
  |     Then the next 8. Repeat until pending is done OR the timer dies.
  |
  |     If the timer dies here:
  |       memory cache is thrown away
  |       store has no new rows
  |       report shows saved 0
  |
  v
  |  2. WRITE  (one item at a time)
  |     Goal: use the skim if present, decide, persist a row.
  |
  |       item 1: use skim if we have it -> decide -> save row
  |       item 2: ...
  |
  |     Only this step increments saved count.
  |
  v
DONE
```

PROHIBITED:

```text
prefetchEssence -> RunChatLines -> Classify loop
```

PROHIBITED:

```text
[Mermaid flowchart only, no Goal lines or TIME axis]
```

**CONSTRAINT:** Diagram labels MUST use the human's nouns from the thread (job,
timer, store, report) before internal symbol names. MAY add a short symbol list
after the diagram, not inside the timeline.

Enforcement: First line of each phase uses everyday words; symbols only after
the fence.
Violation: STOP, rewrite phase titles and Goal lines, then send.

---

## Steps

1. **Name** — One or two sentences: what runs, what is parallel, what persists.
2. **Diagram** — Build the TIME block per core constraints.
3. **Symbols** — Optional bullet list mapping symbols to diagram phases.
4. **Verify** — Run the pre-completion checklist.

---

## Pre-completion checklist

- [ ] **Prose first:** Pieces named before the fence.
      Method: Read opening paragraph.
      Pass: Everyday nouns present.
      Fail: STOP, add one sentence, then diagram.
- [ ] **TIME axis:** Top or left timeline present.
      Method: Scan fenced block.
      Pass: Clear time direction.
      Fail: STOP, add axis line.
- [ ] **Goal per phase:** Every numbered phase has `Goal:`.
      Method: Count phases vs Goal lines.
      Pass: Equal counts.
      Fail: STOP, add missing Goal lines.
- [ ] **Parallel vs wait:** Fan-out or "one at a time" explicit.
      Method: Each parallel batch shows wait boundary.
      Pass: Reader sees concurrency cap.
      Fail: STOP, add wait line or "sequential" label.
- [ ] **Persist:** Each phase says what is stored or "not yet".
      Method: Scan for store/memory/report outcome per phase.
      Pass: Durable write step identified.
      Fail: STOP, add persist line.
- [ ] **Timer death:** If a shared deadline exists, at least one `If the timer
      dies here:` (or equivalent) branch.
      Method: Search diagram for timer + failure outcome.
      Pass: Empty or partial outcome named.
      Fail: STOP, add branch.
- [ ] **Standalone:** Diagram readable without the essay.
      Method: Read fence only.
      Pass: Story clear.
      Fail: STOP, move facts from prose into Goal lines.
