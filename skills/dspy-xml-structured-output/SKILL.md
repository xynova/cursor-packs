---
name: dspy-xml-structured-output
description: >-
  DSPy structured XML output and strop parser: nested tags vs string fields,
  list/array fields, mandatory validation, and debugging empty fields. Use when
  adding or changing generator output fields, debugging mandatory field validation
  failures, bullet/list XML in signatures, or aligning prompts with parser behavior.
---

# DSPy XML structured output (strop)

**Principle:** The LLM returns XML; **`github.com/behaviorengineering/strop/dspy/structured_output`** parses it into `map[string]any` before **`strop/dspy/validation`** runs. If prompts and parser disagree, fields can look full in logs but parse as **empty** and fail validation.

**Related:** `.cursor/skills/dspy-module-patterns/SKILL.md`, `.cursor/skills/dspy-prompt-engineering/SKILL.md`, `.cursor/skills/dspy-go-debugging/SKILL.md`, `.cursor/skills/strop-pipeline-pattern/SKILL.md`. Product-specific phase hooks (e.g. PostGenerator) may live in a **project overlay** skill if present.

**Anti-pattern:** Do not add fallback parsing of nested `response` maps when XML interceptors are enabled.

---

## 0. Structured output is the primary path

Runtime validation and business logic MUST use **parsed field maps**, not substring checks on model prose.

### Pipeline

```
FormatInterceptor  →  LLM  →  ParseInterceptor  →  ValidationInterceptor  →  client/service
     (XML instructions)              (map[string]any)         (mandatory keys)
```

**Code:** `strop/dspy/structured_output/interceptor.go`, `strop/dspy/factory/interceptor_setup.go` (`EnableStructuredOutput` + raw XML passthrough on inner Predict).

### Do this

- Validate **map keys** from the signature via `ValidateMandatoryFields` or job-specific validators registered at container startup.
- Phase-aware jobs: filter **both** format instructions **and** parse signature with the same helper (app hook via `SetStructuredOutputHooks` when the product needs phased output).
- Fix empty fields by aligning **prompt + XML template + parser + inputs** (§4–§5), not by scraping text.

### Do not do this (runtime)

- `strings.Contains` on LLM output to decide if a field is present.
- Reading nested `response` maps or manual XML walking in services/CLI when interceptors are enabled.
- Regex on model prose as the **primary** extraction path.

### Narrow exceptions (document if you add more)

| Mechanism | When acceptable |
|-----------|-----------------|
| App-specific raw recovery after parse | **Fallback only** when the parser dropped text inside nested tags under a **plain string** field; runs after parse, before validation. Register via product hooks, not in services. |
| Keyword filter on **evaluator feedback** | Free-text feedback is unstructured by nature; intentional scope filters only. |
| `strings.TrimSpace` on **already-parsed** string values | Normal empty check, not parsing. |

### Tests

- Assert **parsed maps**, field lists, or constants — not `strings.Contains` on full prompt blobs.

---

## 1. When to load

- Mandatory field errors: `empty fields: [some_field]` while the raw response **seems** to contain content.
- New generator output that is a **list**, **bullets**, or **repeated items**.
- Changing **XML examples** or field descriptions in `*_modules.go` prompts.
- After changing parser behavior in `strop/dspy/structured_output/xml/parser.go` (add table-driven tests in the same package).
- Deciding whether to add **string/regex** logic — default answer is **no** for validation.

---

## 2. How the XML parser treats fields

| Situation | Typical result |
|-----------|----------------|
| **Plain string field** | Only **direct character data** under the field tag is captured. |
| **Nested child elements** under a plain string field | **Ignored** for that field. Example: `<items><li>a</li></items>` yields **empty** `items` unless the field is an array field or special-cased. |
| **Array field** (`isArrayField` → true) | Repeated **child** elements → `[]interface{}`. Some fields may be **joined to a single string** in product hooks. |
| **Map field** | Nested elements become keys/values (`isMapField`). |

**Code:** `strop/dspy/structured_output/xml/parser.go` — `parseXML`, `isArrayField`, `isMapField`.

---

## 3. Mandatory field validation

**Code:** `strop/dspy/validation/validation_interceptor.go` — `ValidateMandatoryFields`.

- **Strings:** empty after `TrimSpace` → fails.
- **`[]interface{}`:** length `0` → fails.
- **Other non-nil values:** treated as present.

A field that parses as `""` or an **empty slice** trips validation even when the trace shows bullets **inside nested tags** the parser did not flatten.

---

## 4. Checklist: new or list-like output field

1. **Decide shape:** One string with newlines vs true list vs map — match what the **client** and **DB** expect.
2. **Align XML with the parser:**
   - Nested tags (`<item>`, `<li>`, etc.) → field MUST be an **array field** in `isArrayField` or have explicit product handling.
   - Flat text only → prompts MUST NOT rely on nested tags for mandatory content unless the parser collects them.
3. **Update prompts** in `{job}_modules.go`: XML examples MUST match `WithXMLFormatting` / shared XML rules.
4. **Add or extend tests** in `strop/dspy/structured_output/xml/*_test.go` for the shape you rely on.
5. **Interceptors:** Enable via factory; validation runs on parsed outputs — do not “fix” missing fields by reading nested `response` maps in application code.

---

## 5. Debugging “empty field” quickly

1. Confirm the **parsed** type: string vs `[]interface{}` vs missing key (see `available fields: [...]` in the error).
2. Inspect whether the model used **nested XML** inside that field’s tag.
3. If yes, check **`isArrayField`** / **`isMapField`** / product special-case in parser or hooks.
4. Adjust parser (and tests) **or** tighten the prompt to flat XML — **both** MUST stay aligned.
5. On validation failure, check logs for **`raw_response_preview`** — confirms empty tags vs parse bug.

---

## 6. Files (strop)

| Area | Path |
|------|------|
| XML parse + list/map heuristics | `strop/dspy/structured_output/xml/parser.go` |
| Format + parse interceptors | `strop/dspy/structured_output/interceptor.go` |
| Parser tests | `strop/dspy/structured_output/xml/*_test.go` |
| Mandatory field validation | `strop/dspy/validation/validation_interceptor.go` |
| Interceptor wiring + raw passthrough | `strop/dspy/factory/interceptor_setup.go` |
| Global XML / prefix rules | `strop/dspy/signature_helpers.go` (`SharedInstructions.XMLFormatting`) |
| Per-job signatures and prompts | App: `internal/pipelines/<pipeline>/clients/*_modules.go` |
| Product parse/format hooks | App: register via `SetStructuredOutputHooks` at container startup |

If the project has a **local overlay** skill for phased composition or field special-cases, load it after this skill.
