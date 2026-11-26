---
name: product-persona
description: >-
  Write a product persona as a hypothesis: goal, context, current behavior,
  trigger, success, and an anti-persona, with each field marked fact or
  assumption. Load when asking who a product is for, drafting a persona, or
  starting a customer journey. A name, age, or job stays out until research
  shows it changes a design decision.
---

# Product persona

## When to load

Load when the human asks who a product is for, asks for a persona, or starts a customer journey that names an audience.

This skill writes the persona. The journey map is `product-journey`. The setup sequence is `product-configuration`. Load those when the task is the map or the setup, not the person.

A persona for one named host stays in that host. This skill is the method.

## What a persona is

Nielsen Norman Group describes a persona as a fictional user built from research. A detail stays only when it changes a design decision. Until interviews, field study, or a survey exist, the persona is a hypothesis.

## Core constraints

**CONSTRAINT:** A persona MUST be one primary person plus one anti-persona. MUST NOT split install paths, operating systems, or a second account into extra personas unless research shows they decide differently.

- Enforcement: count persona cards before send. Quote the research or product fact that makes a second primary persona decide differently.
- Violation: STOP, merge the variants into the primary persona, re-verify

CORRECT:
```text
Primary: one person on their own computer.
Mac and Windows are how that person installs.
Anti-persona: the builder who already lives in the tool's config files.
```

PROHIBITED:
```text
Persona 1: Mac user.
Persona 2: Windows user.
```

**CONSTRAINT:** Every persona field MUST pass the field gate in working memory before it is written. The fields are goal, context, current behavior, trigger, success, anti-persona.

```text
Candidate: [field]
Evidence the human stated, or a research quote: YES: [quote] / NO
Decision: FACT | ASSUMPTION | OMIT
If FACT: the sentence uses only the quote
If ASSUMPTION: one sentence guess, plus the interview question that would confirm it
If OMIT: the detail does not change a design decision
```

- Enforcement: the written persona labels each kept field FACT or ASSUMPTION. An OMIT field is absent.
- Violation: STOP, run the gate, relabel or cut the field

CORRECT:
```text
Goal (ASSUMPTION): know which items to open first.
Interview: what do they skip today, and what would they call a win?
Context (FACT): they said the files stay on their computer.
```

PROHIBITED:
```text
They want to be more productive and save time.
```

**CONSTRAINT:** A name, age, gender, job, city, photo, or biography MUST stay out until a research quote shows that detail changes a design decision.

```text
Candidate: [name, age, job, or other biography detail]
Research quote that this detail changes a design decision: YES: [quote] / NO
Decision: KEEP | OMIT
If KEEP: the decision it changes
```

- Enforcement: grep the persona for a proper name, an age, or a job title. Each hit has a KEEP gate with a research quote.
- Violation: STOP, delete the detail, re-verify

CORRECT:
```text
No name. No job. The goal and the context are enough to choose the first screen.
```

PROHIBITED:
```text
Alex, 34, product manager in Austin, drinks coffee before standup.
```

**CONSTRAINT:** Success MUST be what the person would see or say. MUST NOT be a company metric.

- Enforcement: the success line names a thing the person can point at.
- Violation: STOP, rewrite from the person's view

CORRECT:
```text
Success (FACT of the flow): a first result is on screen and they did not edit a file.
Whether they call that a success is ASSUMPTION until they say so.
```

PROHIBITED:
```text
Success: activation rate above 40 percent.
```

**CONSTRAINT:** The anti-persona MUST name who the product is not designing for, and one setup or copy choice that person must not force on the primary persona.

- Enforcement: the anti-persona card names a person already in the project (the builder, an admin, a buyer) and one excluded demand.
- Violation: STOP, add the anti-persona, re-verify

**CONSTRAINT:** When any field is ASSUMPTION, the persona MUST say it is a hypothesis, and MUST name the interview that would promote it to FACT. MUST NOT present the persona as research.

- Enforcement: the heading or first line contains "hypothesis" when any ASSUMPTION remains. The next step names who would be interviewed.
- Violation: STOP, label the hypothesis, add the interview

## Steps

1. **Collect facts.** Quote only what the human or the product record already said. Do not add a motive.
2. **Run the field gate** on goal, context, current behavior, trigger, success, and anti-persona.
3. **Run the biography gate** on any name, age, job, or color detail.
4. **Write the primary persona and the anti-persona** with FACT or ASSUMPTION on each kept field.
5. **State the interview** that would test the assumptions. Do not invent the answers.

## Pre-completion checklist

- [ ] **One primary:** install path and account count are not extra personas
      Method: count primary cards
      Pass: one primary card
      Fail: two primaries that differ only by OS or account count → STOP, merge
- [ ] **Fields labeled:** goal, context, current behavior, trigger, success, anti-persona are each FACT, ASSUMPTION, or absent as OMIT
      Method: read the persona labels
      Pass: every kept field has a label
      Fail: an unlabeled motive → STOP, run the field gate
- [ ] **No fake biography:** no name, age, or job without a research quote
      Method: read the persona
      Pass: none, or each has a KEEP quote
      Fail: a stock person → STOP, delete it
- [ ] **Hypothesis marked:** assumptions are called a hypothesis, with an interview named
      Method: read the first line and the last step
      Pass: both are present when any ASSUMPTION exists
      Fail: the persona reads as researched → STOP, label it
