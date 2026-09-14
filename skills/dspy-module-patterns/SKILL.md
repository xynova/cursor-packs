---
name: dspy-module-patterns
description: >-
  dspy-go module wiring on strop: Predict vs ChainOfThought, structured-output
  interceptors, EnableStructuredOutput on inner Predict, config create
  (GeneratorConfig / RLMConfig CreateModule), WithXMLFormatting in Create*, and
  testing parsed maps. Use when creating modules, enabling XML structured output,
  wiring interceptors, RLM construction, or choosing module types.
---

# DSPy module patterns (strop)

Short wiring guide. **Deep encyclopedia:** [reference.md](reference.md). Parser/validation: `.cursor/skills/dspy-xml-structured-output/SKILL.md`. Jobs: `.cursor/skills/strop-pipeline-pattern/SKILL.md`.

Modules are the only supported path to LLM calls (in-process dspy-go via strop).

---

## When to load

Creating modules, enabling XML structured output, wiring interceptors, or choosing Predict / ChainOfThought / ReAct / Parallel.

---

## Core rules

1. Always use modules (`NewPredict`, `NewChainOfThought`, …) with a signature.
2. Signatures define contracts; attach behavior with `.WithInstruction()`.
3. Configure LLM via `strop/dspy/factory` — never hardcode API keys.
4. Structured output on **Predict**. For `ChainOfThought`, configure the **inner** `module.Predict`.
5. Use `factory.InterceptorSetup.EnableStructuredOutput(cot)` — not stock `WithXMLOutput` alone. strop's parser needs raw XML passthrough on Predict.

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

**Code:** `strop/dspy/factory/interceptor_setup.go`.

---

## WithXMLFormatting in Create*

Apply **`WithXMLFormatting`** inside **Create\*** functions, not at call sites:

| Module kind | Where |
|-------------|--------|
| Generators | `CreateGeneratorModule` (+ `SharedInstructions.GeneratorObjectiveRecitation`) |
| Chained evaluator | `CreateChainedEvaluatorModule` |
| Consolidator | `CreateDefaultConsolidatorModule` |

See `strop-pipeline-pattern` skill §4.

---

## Config create (recommended)

House name: **config create**. Same idea as golang-quality CONSTRAINT 18.

Fill a typed config with everything the module needs to construct, then call `CreateModule()` (no parallel long arg list).

**Generators** (signature/prompt shape; LLM still via factory `CreateGenerator`):

```go
genCfg := stropdspy.GeneratorConfig{Name: name, Signature: sig, SystemPrompt: prompt}
mod, err := genCfg.CreateModule()
```

**RLM** (LLM must live on the config because `NewFromLLM` needs it at construct time; run via `RLMComplete`, not `Process`):

```go
rlmCfg := stropdspy.RLMDefaults()
rlmCfg.LLM = llm // after factory.LLMFactory.CreateLLM (and optional retry wrap)
rlmCfg.Timeout = timeout
rlmCfg.TraceDir = traceDir
module, err := rlmCfg.CreateModule()
answer, result, err := stropdspy.RLMComplete(ctx, module, contextPayload, query)
```

Prefer `cfg.CreateModule()` over `CreateRLMModule(llm, cfg)` at host call sites. `factory.CreateRLM` remains available when starting from `ProviderConfig` only.

---

## Interceptor semantics

- Do **not** inject synthetic text into outputs to pass mandatory validation.
- Do let validation fail so retry runs; after exhaustion, fail clearly.
- Empty evaluator `feedback` is invalid, not "all criteria met."
- Reader-facing prose evaluation MUST attach strop `ai_cadence` (`dspy.AppendAICadenceEvaluator`, cheap model via `roleProviders`) the same way modules MUST wire `RetryModuleInterceptor`. Do **not** attach on sayings fluff or structural extractors. Details: `strop-pipeline-pattern` skill §3.

---

## Testing

- Mock LLMs and external APIs.
- Assert **parsed maps** and typed structs, not substrings of raw prompts.
- Parser changes: table-driven tests in `strop/dspy/structured_output/xml`.
