---
name: dspy-go-debugging
description: >-
  Debug dspy-go structured output failures: empty mandatory fields, validation vs
  parse mismatches, retry exhaustion, interceptor wiring, and refinement-loop
  exits. Use when a module fails validation, fields appear in raw logs but not in
  parsed output, or a refinement loop stops unexpectedly.
---

# DSPy-Go debugging

Decision tree for runtime failures. Parser and phase details: `.cursor/skills/dspy-xml-structured-output/SKILL.md`. Job/orchestration contracts: `.cursor/skills/pipeline-client-module-pattern/SKILL.md`.

**Related:** `.cursor/skills/dspy-module-patterns/SKILL.md` (interceptor wiring).

---

## When to load

Module **fails validation**, returns **empty/nil fields**, retries exhaust, or a **refinement loop** exits early.

---

## Decision tree

```
Error mentions "empty fields" or mandatory validation?
├─ Yes → §1 Empty field (then XML skill)
└─ No → LLM / timeout / retry exhausted?
    ├─ Retry exhausted after validation → §1 then §3 Retry
    ├─ LLM / API error → §4 LLM layer
    └─ Refinement / orchestration → §5 Orchestration
```

---

## 1. Empty mandatory field

**Symptom:** `empty fields: [field_name]` but the raw trace looks full.

Do **not** restate parser tables here. Load `.cursor/skills/dspy-xml-structured-output/SKILL.md` (§2–§5) and:

1. List `available fields` from the error — missing key vs present-but-empty.
2. Missing key: signature name ≠ XML tag, or phase filter dropped the field.
3. Present empty: empty tags, whitespace only, or nested children under a **plain string** field.
4. Check `raw_response_preview` in validation logs.
5. Add a parser unit test with the failing XML snippet.

**Do not** fix with `strings.Contains` on raw output or `outputs["response"]`.

---

## 2. Interceptor wiring

- `ChainOfThought` → `EnableStructuredOutput` on the **inner Predict** (`internal/dspy/factory/interceptor_setup.go`).
- Factory `Setup*` ran at registration.
- After `Process`, keys MUST be top-level field names. A single `response` string means interceptors are not active.

---

## 3. Retry

Validation failure SHOULD trigger `RetryModuleInterceptor` within budget.

- Retries fire but keep failing → prompt/parser mismatch, not LLM noise.
- No retries → validation bypassed or error thrown before the retry hook.
- After exhaustion: fail clearly. NEVER inject synthetic `feedback` or filler.

---

## 4. LLM layer

- API key, model ID, timeout on the provider for **this** module.
- Rate limits / token limits truncating XML mid-tag (breaks parse).
- Long rationale **before** later sibling tags → truncation; reorder emit rules in the prompt.
- Tracing: `core.WithExecutionState(ctx)` and per-module prompt/response steps.

---

## 5. Orchestration / refinement

| Symptom | Likely cause |
|---------|----------------|
| `MaxVersionsReached` immediately | `ShouldSkipMaxVersions` / cap; check `Force` |
| Score decreases, loop stops | Healing not configured or policy rejects |
| Per-item loop wrong length | `ItemCount` vs seed slice; re-sync in `LoadContext` |
| Partial regen overwrites all | Missing seed copy; merge in `SaveVersion` |
| Nil version ID on success | Early-exit returned `uuid.Nil` — use selection fallback (pending → approved → any) |

Details: pipeline-client-module-pattern skill (refinement, early-exit, selection fallback).

---

## 6. Evaluators

- Empty `feedback` → validation error (intentional).
- Consolidated feedback missing a criterion → `CriterionIDs` misaligned with the score prompt.
- `previous_feedback` polluted → look for synthetic injection (must not exist).

---

## 7. Minimal reproduction

1. Isolate XML from `raw_response_preview`.
2. Parser unit test with that snippet.
3. Confirm parsed map key/value.
4. Fix **parser or prompt** — not both without knowing which was wrong.
