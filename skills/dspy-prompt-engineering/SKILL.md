---
name: dspy-prompt-engineering
description: >-
  Compact dspy-go prompt contract: signature vs instruction vs field descriptions,
  list/map wording for the XML parser, generator rationale helpers, and evaluator
  envelope. Use when writing or revising module prompts, generator/evaluator
  signatures, or XML examples in *_modules.go.
---

# DSPy prompt engineering (this repo)

Compact contract. Full theory and templates: `.cursor/rules/rules-for-prompts.mdc`. Parser alignment: `.cursor/skills/dspy-xml-structured-output/SKILL.md`. Job layout: `.cursor/skills/pipeline-client-module-pattern/SKILL.md`.

After this skill, **load `rules-for-prompts.mdc`** for bias mitigation, CoT, and longer templates.

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
| Rationale | Shared helpers (below) |

Descriptions MUST match XML examples in `{job}_modules.go`.

---

## Generator rationale contract

1. **Objective recitation first:** `VOICE:`, `MUST:`, `ANTI_PATTERN:` (persona/objectives).
2. **Then action-chain:** short bullets of what was done (cap ~5 lines unless the job defines a longer plan).
3. **Plain text only** inside rationale — no XML/JSON nested in that field.
4. Fix drift in **output fields**, not by rewriting rationale to match weak prose.

Helpers: `RationaleDescriptionWithContext(taskFocus)`, `RationaleDescriptionWithExtra(taskFocus, extraConstraints)`.

`GeneratorObjectiveRecitation` is appended by `CreateGeneratorModule`. Evaluators use `DefaultChainedEvaluatorSignature()` and do **not** get generator recitation.

---

## ChainOfThought generators

- Task rules in **instruction**; per-field format in **output descriptions** + XML examples.
- Do not duplicate output fields in the instruction that the signature already exposes.
- Phased jobs: emit **this phase only** (XML skill §6).

---

## Evaluator prompts (chained)

Envelope (`DefaultChainedEvaluatorSignature`):

- Inputs: `generator_input`, `generator_output` (maps — inner keys are job-specific).
- Outputs: `criterion_scores`, `feedback`, `rationale`.

Score keys MUST match `ChainedEvaluatorConfig.CriterionIDs`. Empty `feedback` when issues exist is a contract violation.

`ToMap()` is generate-only. `EvaluationMap()` is the evaluator view. Inner keys MUST exist in the maps the prompts name.

---

## XML examples in prompts

- Tag names MUST match signature output fields.
- Lists: multiple `<item>` siblings under one parent field tag.
- Phased output: only tags valid for that phase.

Then load `.cursor/rules/rules-for-prompts.mdc`.
