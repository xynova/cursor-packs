---
name: dspy-prompt-engineering
description: >-
  Compact dspy-go prompt contract: signature vs instruction vs field descriptions,
  list/map wording for the XML parser, DirectivesCoT directives_ack, generator
  task-field rationale helpers, and chained evaluator envelope (feedback +
  directives_ack, not evaluator rationale). Use when writing or revising module
  prompts, generator/evaluator signatures, or XML examples in *_modules.go.
---

# DSPy prompt engineering (strop)

Compact contract. **Deep reference:** [reference.md](reference.md) (bias, CoT, templates). Parser alignment: `.cursor/skills/dspy-xml-structured-output/SKILL.md`. Job layout: `.cursor/skills/strop-pipeline-pattern/SKILL.md`.

Product-specific prompt invariants (if any) live in the consumer under a project prefix such as `pipelines-x-*` — load those after this skill.

---

## When to load

Writing or revising module prompts, generator/evaluator signatures, or XML examples in `{job}_modules.go`.

---

## Signature vs instruction

Signatures define **structure**. Instructions define **behavior**. Field **descriptions** steer XML shape and parser heuristics.

Order of influence: **persona (if any) → instruction → field descriptions → XML format rules** (`WithXMLFormatting` in Create*).

```go
signature := core.NewSignature(inputs, outputs).
    WithInstruction(`You are a specialized evaluator.
- Analyze content objectively
- State uncertainties explicitly`)
```

---

## Field descriptions drive parsing

| You want | Write in the description |
|----------|--------------------------|
| Scalar text | Plain description; text goes directly in the tag |
| List | **"list of"** or **"array"**; show `<item>` children in XML examples |
| Key-value map | **"map"** or **"dictionary"** — NEVER **"object"** for maps |
| Generator task-field rationale | Shared helpers (below). Evaluator XML MUST NOT add a rationale field. |

Descriptions MUST match XML examples in `{job}_modules.go`.

---

## Generator DirectivesCoT vs task-field rationale

DirectivesCoT (`strop/dspy/modules/directives_protocol.go`) prepends `directives_ack`. VOICE / MUST / ANTI_PATTERN for **that step** live there, not in a stock ChainOfThought `rationale`. `CreateGeneratorModule` MUST NOT append the old rationale-first recitation block.

A generator MAY still declare a **task-field** `rationale` when the signature includes it (helpers below). That field is job output, not evaluator XML.

1. Task-field rationale (only if the generator signature declares it): objective recitation first (`VOICE:`, `MUST:`, `ANTI_PATTERN:`), then a short action-chain (cap ~5 lines unless the job defines a longer plan).
2. Plain text only inside that field — no XML/JSON nested in it.
3. Fix drift in **task output fields**, not by rewriting rationale or `directives_ack` to match weak prose.

Helpers (`strop/dspy`): `RationaleDescriptionWithContext(taskFocus)`, `RationaleDescriptionWithExtra(taskFocus, extraConstraints)`.

Evaluators MUST use `CreateChainedEvaluatorModule` / `DefaultChainedEvaluatorSignature()`. They MUST NOT get generator recitation and MUST NOT copy generator `<rationale>` examples into Feedback Analysis prompts.

---

## ChainOfThought generators

- Task rules in **instruction**; per-field format in **output descriptions** + XML examples.
- Do not duplicate output fields in the instruction that the signature already exposes.
- Phased jobs: emit **this phase only** — load project overlay if phased composition hooks exist.

---

## Evaluator prompts (chained)

**Source of truth:** `strop/dspy/chained_evaluator.go` (`DefaultChainedEvaluatorSignature`, `CreateChainedEvaluatorModule`) and `strop/dspy/modules/directives_protocol.go`.

Combined workflow outputs: `criterion_scores`, `feedback`, `directives_ack`. NEVER `rationale`.
Inputs: `generator_input`, `generator_output` (maps; inner keys are job-specific).

Feedback analysis submodule: task output is `feedback` only. DirectivesCoT prepends `directives_ack` (instructions → VOICE/MUST/ANTI_PATTERN → plan → attention check). Score generation submodule: `criterion_scores` (+ `directives_ack`). Downstream score generation reads `feedback` only.

**CONSTRAINT:** Feedback Analysis job prompts MUST name the **feedback field** (checklist in `<feedback>`). MUST NOT tell FA to emit `<rationale>` or “always output feedback and rationale.”
- Enforcement: FA `CreateChainedEvaluatorModule` signature has no rationale field; `dspymodules.New` drops one if present
- Violation: STOP, rewrite FA copy to feedback-field language; leave generator `<rationale>` on the generator module only

CORRECT:
```text
Provide checklist-based feedback. Always output at least one line in the feedback field. Never leave feedback empty.
```

PROHIBITED:
```text
Always output both feedback and rationale.
REQUIRED XML OUTPUT:
<feedback>...</feedback>
<rationale>...</rationale>
```

Score keys MUST match `ChainedEvaluatorConfig.CriterionIDs`. Empty `feedback` when issues exist is a contract violation.

`ToMap()` is generate-only. `EvaluationMap()` is the evaluator view. Inner keys MUST exist in the maps the prompts name.

---

## XML examples in prompts

- Tag names MUST match signature output fields.
- Lists: multiple `<item>` siblings under one parent field tag.
- Phased output: only tags valid for that phase.

Then load project `pipelines-x-*` prompt overlays if present.
