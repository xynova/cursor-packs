---
name: plan-scaffold
description: >-
  Use when the user asks to create an implementation plan, plan a feature,
  write a plan, make a plan technically comprehensive, or when Plan mode is
  designing a multi-step change. Runs sketch, then fixed scaffold slots
  S1-S16, then coherence, before CreatePlan or a plan file is done.
  plan-auditor then scores stages and sketch coherence and may patch plan
  markdown only.
---

# Plan Scaffold (three-pass conductor)

## When to load

Rule `plan-scaffold` decides LOAD, CONTINUE, or SKIP. On LOAD, start at Pass 1 Sketch. On CONTINUE (for example "make this technically comprehensive" on the current plan artifact), start at Pass 2 scaffold slots on that same artifact. On SKIP, do not use this skill.

## Load gate (working memory)

Before Pass 1:

```text
Candidate: [quote the user sentence that might be a plan ask]
Implementation plan: YES: [quote] / NO
Existing plan and comprehensive ask: YES: [quote] plus [plan path or CreatePlan artifact] / NO
Named skill other than plan-scaffold: YES: [quote the skill name] / NO
Implement or code an already chosen plan: YES: [quote] / NO
Decision: LOAD | CONTINUE | SKIP
```

- LOAD: implementation-plan YES, other skill NO, implement-already-chosen NO.
- CONTINUE: comprehensive ask YES on an existing plan artifact.
- SKIP: any other combination.

## Pass order

**CONSTRAINT:** MUST run Pass 1 Sketch, Pass 2 slots S1-S16, Pass 3 coherence, then write once. MUST NOT mark the plan done after the sketch alone. MUST NOT wait for a second human prompt such as "make it comprehensive."

- Enforcement: The artifact contains `## Sketch`, slot decisions S1-S16, coherence section, and executor stages before `CreatePlan` or a final plan file.
- Violation: STOP. Continue Pass 2 on the same artifact. Do not implement product code.

CORRECT: One turn runs sketch, slots, coherence, then `CreatePlan` with the full body.

PROHIBITED: Outline only, then "plan is ready for review."

**CONSTRAINT:** MUST put Sketch under the heading `## Sketch` inside the plan artifact. Chat-only sketch does not count.

- Enforcement: `plan-auditor` can read What, Why, One approach, Out of scope, and Open forks from the file alone.
- Violation: STOP. Paste the sketch block into the artifact before scoring coherence.

CORRECT:

```markdown
## Sketch

- What we're building: ...
- Why: ...
- One approach: ...
- Out of scope: ...
- Open forks: none
```

PROHIBITED: Sketch lives only in the chat; the plan file jumps to implementation phases.

**CONSTRAINT:** On a real fork (two approaches that change different paths or different git repos), MUST call `AskQuestion`, stop, and MUST NOT fill slots or call `CreatePlan`. After the user picks, set `Open forks: none` and the chosen approach in Sketch.

- Enforcement: Two path sets or two owning repos named in the alternatives.
- Violation: STOP. AskQuestion. Do not scaffold both approaches.

CORRECT: User picks one approach; Open forks is `none` with one approach line.

PROHIBITED: `CreatePlan` with "we might use A or B" and no pick.

**CONSTRAINT:** Each slot S1-S16 MUST run the FILL | N/A gate before the slot is written in the artifact. S1 Sketch, S14 Executor stages, and S16 Verification MUST be FILL. `N/A` on S1, S14, or S16 is FAIL.

```text
Candidate: S<n> <name>
Applies: YES: [quote path, type, command, or user sentence] / NO: [quote]
Decision: FILL | N/A
If FILL: section heading: [heading]
         facts: [paths, function names, commands]
If N/A: reason: [one sentence quoting NO evidence]
```

Slot list: S1 Sketch, S2 Reference implementation, S3 Registry, S4 Dependency injection, S5 Factories, S6 Config keys, S7 Migrations, S8 CLI wiring, S9 Resumability, S10 Multi-repo boundaries, S11 Language quality, S12 Data flow, S13 Glue trace, S14 Executor stages, S15 Error handling, S16 Verification.

- Enforcement: Every S1-S16 appears in the artifact with FILL facts or an `N/A` reason.
- Violation: STOP. Return to Pass 2 for the missing slot.

**CONSTRAINT:** Forced dependencies after slot gates:

- If S3, S4, S5, or S8 is FILL, S13 MUST be FILL and a stage Path MUST name the register or constructor function.
- If S7 is FILL, an earlier stage MUST apply the migration before stages that read new tables.
- If S10 is FILL, library commit and host pin MUST be separate stages (one git repository per stage).
- If S9 is FILL, a stage MUST name checkpoint identity, evidence struct, and downstream invalidation.
- S14 stages MUST exist only for FILL slots, plus S16 verification.

- Enforcement: Cross-check slot log against stage Goals and Paths before Pass 3.
- Violation: STOP. Add the missing glue stage or fix S13.

Read `PLAN-SCAFFOLD.md` once for how to fill a slot. MUST NOT copy the YouTube example or paste Phase A-J unless that slot is FILL.

## Pass 3 Coherence

Run before write once. Any FAIL sends the draft back to Pass 2.

Sketch capability (each fact under What, Why, One approach):

```text
Candidate: [sentence]
Owning stage or slot: YES: [quote stage Goal or FILL slot] / NO
Decision: KEEP | FAIL dropped
```

Stage Goal (each S14 stage):

```text
Candidate: [Goal sentence]
Entailed: YES: [quote Sketch or FILL slot] / NO
Decision: KEEP | FAIL invented
```

Named risk (each bullet under `## Coherence`):

```text
Candidate: [risk sentence]
Owner: YES: [quote stage Goal, Out of scope, or accept:] / NO
Decision: KEEP | FAIL orphan
```

Also FAIL: "as discussed", "the rest of the plan", "the conversation"; subjective Pass ("looks good"); any S14 stage missing Goal, Paths, Out of scope, Commands, Pass, Fail closed, or Resume.

## Write once

**CONSTRAINT:** MUST call `CreatePlan` at most once per plan artifact. On CONTINUE, MUST edit the existing plan file in place and MUST NOT call `CreatePlan` again.

- Fork open: no write.
- Plan mode, writes forbidden: score Pass 3 in working memory, then one `CreatePlan` with full body. Defer `plan-auditor` file patches until a path exists and writes are allowed.
- Agent mode with `.cursor/plans/<feature>-plan.md`: write once, invoke `plan-auditor` with path and full markdown, repair FAIL and `Needs from human`.
- CONTINUE on an existing file: edit in place, invoke `plan-auditor` on that path.

- Enforcement: Decision CONTINUE and a second `CreatePlan` in the same thread is a violation.
- Violation: STOP. Merge into the existing artifact.

CORRECT: `CreatePlan` after coherence is clean; comprehensive follow-up edits the same file.

PROHIBITED: First `CreatePlan` is sketch-only; user must ask again.

**CONSTRAINT:** When a plan path exists and writes are allowed, MUST invoke subagent `plan-auditor` before any product implementation. MUST repair FAIL and `Needs from human` before Build.

- Enforcement: No `.go`, `.ts`, or similar product edits until auditor Verdict is PASS or only WARN with `accept:` residuals.
- Violation: STOP. Run plan-auditor and patch plan markdown only.

## Pointers

- Encyclopedia and glue checklists: `skills/plan-scaffold/PLAN-SCAFFOLD.md` (slot map and executor contract).
- Go quality: skill `golang-quality`.
- Boundaries: rule `repository-boundaries`.
- Auditor: `agents/plan-auditor.md`.

## Pre-completion checklist

- [ ] **Pass order:** Sketch, S1-S16, coherence, then one write
      Method: Scan artifact and skill constraints
      Pass: No done-after-sketch path remains
      Fail: STOP, continue Pass 2

- [ ] **Slots:** S1, S14, S16 are FILL; dependencies hold
      Method: Read slot log and S14 stages
      Pass: Forced dependency rules satisfied
      Fail: STOP, fix slot or stage

- [ ] **Auditor:** Invoked when path and writes allowed
      Method: Verdict or scorecard before product code
      Pass: FAIL repaired or `Needs from human` resolved
      Fail: STOP, run plan-auditor