---
name: product-configuration
description: >-
  Design a short product setup: one job per screen, defaults already on, and
  a first success before extra choices. Load when designing onboarding,
  first-run, connect, or configuration. The person comes from product-persona.
  The place of setup in the journey comes from product-journey.
---

# Product configuration

## When to load

Load when the human asks how setup, onboarding, first-run, or connect should work.

The person is already a hypothesis from `product-persona`. The journey already has a configuration span from `product-journey`. This skill decides the screens inside that span.

## Core constraints

**CONSTRAINT:** Configuration MUST be the whole setup, from install through the first success. MUST NOT treat the sign-in button as the whole setup.

- Enforcement: the written setup names install, the consent or disclosure, and the first success as one sequence.
- Violation: STOP, add the missing screens, re-verify

CORRECT:
```text
Install, with no folder question.
One disclosure, then the browser.
The first result is already on screen.
```

PROHIBITED:
```text
Configuration is the Connect button.
```

**CONSTRAINT:** Each screen MUST have one job. A screen with two jobs MUST be split.

```text
Candidate: [screen]
Jobs on this screen: [list]
Count is 1: YES / NO
Decision: KEEP | SPLIT
If SPLIT: the two screens and the single job of each
```

- Enforcement: every screen in the setup has a KEEP or SPLIT gate before it is written.
- Violation: STOP, split the screen, re-verify

**CONSTRAINT:** Defaults MUST already be chosen for folder, model, and file when the product can choose them. The person MUST NOT be asked for those before the first success.

- Enforcement: the first-success screen states that those choices were already made. Any earlier screen that asks for them is absent.
- Violation: STOP, move the question to after the first success, re-verify

CORRECT:
```text
The first result uses the default batch. A different batch is offered after that result is on screen.
```

PROHIBITED:
```text
Before the first result, pick a folder, a model, and a config file.
```

**CONSTRAINT:** After an external consent, the person MUST return to a screen where the new thing is already listed. MUST NOT land in a settings form.

- Enforcement: the return screen names the connected item as already present.
- Violation: STOP, rewrite the return, re-verify

**CONSTRAINT:** A second account, device, or address MUST reuse the same action, and MUST wait until the first success is on screen.

- Enforcement: the second item is the same control, placed after the first success.
- Violation: STOP, move it, re-verify

**CONSTRAINT:** One disclosure or system prompt MAY sit immediately before external consent. It MUST state what stays on the machine and what the request sends out. It MUST NOT be a tour.

- Enforcement: count prompts before the browser or system sheet. More than one is a fail.
- Violation: STOP, keep one prompt, re-verify

## Steps

1. **Mark the span** as install through first success.
2. **Run the screen gate** so each screen has one job.
3. **Put defaults under the first success.** Move extra choices after it.
4. **Write the return** so the new item is already listed.
5. **Place the second item** on the same control, after that success.

## Pre-completion checklist

- [ ] **Whole setup:** install, consent, and first success are one sequence
      Method: read the sequence
      Pass: all three are present
      Fail: only a login button → STOP, add the rest
- [ ] **One job:** no screen asks for two decisions
      Method: read each screen's gate
      Pass: every gate is KEEP with one job, or SPLIT is already applied
      Fail: a screen still has two jobs → STOP, split it
- [ ] **Defaults first:** folder, model, and file questions are after the first success, or the product cannot default them and the human said so
      Method: read the screens before first success
      Pass: those questions are absent there
      Fail: a setup form precedes the result → STOP, move it
- [ ] **Return state:** the new item is already listed
      Method: read the screen after consent
      Pass: the item is present
      Fail: a settings form → STOP, show the item
