---
name: product-journey
description: >-
  Map an end-to-end customer journey from first hearing through help, bugs,
  and upgrade. Load when designing a customer journey, a press path, packaging,
  or life after install. The persona comes from product-persona. Setup screens
  come from product-configuration.
---

# Product journey

## When to load

Load when the human asks for a customer journey, a path from first hearing to living with the product, or what happens after someone already has it.

Load `product-persona` first and put that hypothesis above the map. Load `product-configuration` for the setup screens. This skill orders the walk. It does not invent the person or the screen copy.

## Core constraints

**CONSTRAINT:** The map MUST start when the person first hears about the product. MUST NOT start at install.

- Enforcement: the first stage name is hearing, a public sentence, or an equivalent first contact. Install is a later stage.
- Violation: STOP, add the earlier stages, re-verify

CORRECT:
```text
1. They hear about it
2. They read the public sentence
3. They install
```

PROHIBITED:
```text
1. They install
2. They connect
```

**CONSTRAINT:** The map MUST include, after install, a first success, return use, asking for help, submitting a bug, and upgrading. Help, bugs, and upgrade MUST be available on any day after install, not only as a final chapter.

- Enforcement: the written map names those five. The help, bug, and upgrade lines say they can happen in any order after install.
- Violation: STOP, add the missing stage, re-verify

**CONSTRAINT:** Each stage MUST say who acts, the person or the company, and what the person sees.

```text
Candidate: [stage]
Who acts: person | company
What the person sees: [one sentence] / MISSING
Decision: KEEP | REWRITE
If REWRITE: the missing who, or the missing sight
```

- Enforcement: every stage has both fields before it is written into the map.
- Violation: STOP, run the gate, re-verify

CORRECT:
```text
They read the public sentence. The company writes it. The person sees who it is for and what the first result looks like.
```

PROHIBITED:
```text
Press release.
```

**CONSTRAINT:** Two install mechanisms MUST be one stage with two forks. MUST NOT be two journeys or two personas.

- Enforcement: Mac and Windows, or store and direct download, sit under one install stage and again under one upgrade stage.
- Violation: STOP, merge the forks, re-verify

**CONSTRAINT:** When the product stores a credential, the install MUST be a normal program on the machine so the operating system can hold that secret. MUST NOT put the secret only inside a container unless the human already chose that and named where the secret lives.

- Enforcement: if a credential is in the product facts, the install stage names the OS store or the place the human named.
- Violation: STOP, name the store, re-verify

**CONSTRAINT:** The public sentence MUST say what leaves the person's machine when the product sends their data to the company. MUST NOT say the data never leaves if a request sends it.

- Enforcement: quote the product's outbound data. The public-sentence stage matches that quote.
- Violation: STOP, rewrite the sentence, re-verify

## Steps

1. **Place the persona** from `product-persona` above the map. If it is missing, stop and load that skill.
2. **List the stages** from first hearing through upgrade, including help and bugs.
3. **Run the stage gate** on each stage.
4. **Fork install and upgrade** when more than one package exists.
5. **Point setup** at `product-configuration` instead of expanding every screen here.

## Pre-completion checklist

- [ ] **Starts early:** the first stage is hearing or the public sentence
      Method: read stage 1
      Pass: install is not stage 1
      Fail: the map opens on install → STOP, add the front
- [ ] **Life after install:** help, bugs, and upgrade are on the map and can happen any day after install
      Method: read the later stages
      Pass: all three are present and not a locked ending
      Fail: one is missing or only at the end → STOP, add it
- [ ] **One install stage:** package forks share a stage
      Method: count install stages
      Pass: one install stage, one upgrade stage
      Fail: a journey per operating system → STOP, merge
