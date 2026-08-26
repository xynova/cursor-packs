---
name: dspy-module-patterns
description: >-
  dspy-go module wiring: Predict vs ChainOfThought, custom structured-output
  interceptors, EnableStructuredOutput on inner Predict, Create* constructors with
  WithXMLFormatting, and testing parsed maps. Use when creating modules, enabling
  XML structured output, wiring interceptors, or choosing module types.
---

# DSPy module patterns (this repo)

Short wiring guide. Full module encyclopedia: `.cursor/rules/rules-for-dspy-go.mdc`. Parser/validation: `.cursor/skills/dspy-xml-structured-output/SKILL.md`. Jobs: `.cursor/skills/pipeline-client-module-pattern/SKILL.md`.

Modules are the only supported path to LLM calls (in-process dspy-go).

---

## When to load

Creating modules, enabling XML structured output, wiring interceptors, or choosing Predict / ChainOfThought / ReAct / Parallel.

---

## Core rules

1. Always use modules (`NewPredict`, `NewChainOfThought`, …) with a signature.
2. Signatures define contracts; attach behavior with `.WithInstruction()`.
3. Configure LLM via factory/config — never hardcode API keys.
4. Structured output on **Predict**. For `ChainOfThought`, configure the **inner** `module.Predict`.
5. Use `factory.InterceptorSetup.EnableStructuredOutput(cot)` — not stock `WithXMLOutput` alone. This repo's parser needs raw XML passthrough (`enablePredictRawXMLPassthrough`).

---

## Module types (when)

| Module | Use for |
|--------|---------|
| **Predict** | Single-shot generation or classification |
| **ChainOfThought** | Most pipeline generators (step-by-step) |
| **ReAct** | Tool-using agents with a tool registry |
| **Refine** | Iterative quality inside one module |
| **Parallel** | Batch independent items concurrently |

---

## Structured output wiring

```go
// After creating ChainOfThought and setting LLM:
interceptorSetup.EnableStructuredOutput(cot)
```

Typical chain: Format → Parse (custom XML → `map[string]any`) → Validate mandatory fields → Retry on validation failure.

After `Process`, output keys MUST be top-level signature field names. A nested `response` string means interceptors are not active. Do not add nested-`response` fallbacks.

---

## WithXMLFormatting in Create*

Apply **`WithXMLFormatting`** inside **Create\*** functions, not at call sites:

| Module kind | Where |
|-------------|--------|
| Generators | `CreateGeneratorModule` (also appends `GeneratorObjectiveRecitation`) |
| Chained evaluator | `CreateChainedEvaluatorModule` |
| Consolidator | `CreateDefaultConsolidatorModule` |

See pipeline-client-module-pattern skill §5.1.

---

## Interceptor semantics

- Do **not** inject synthetic text into outputs to pass mandatory validation.
- Do let validation fail so retry runs; after exhaustion, fail clearly.
- Empty evaluator `feedback` is invalid, not "all criteria met."

---

## Testing

- Mock LLMs and external APIs.
- Assert **parsed maps** and typed structs, not substrings of raw prompts.
- Parser changes: table-driven tests in `internal/dspy/structured_output/xml`.
