---
name: ask-polypus
description: >-
  Consult a second model through the local Polypus OpenAI gateway
  (http://127.0.0.1:1320), defaulting to Gemma 4 on cf_local. Use when the user
  says ask Gemma, ask Polypus, go ask gemma on polypus, second opinion via
  Polypus, or wants a local gateway chat completion without editing Polypus
  itself. Not for operating or debugging the gateway (use polypus-operator).
---

# Ask Polypus (Gemma consult)

**Moral:** When the human wants a second brain through Polypus, call the loopback OpenAI chat API. Do not invent a cloud URL or edit the Polypus repo for a consult.

Upstream product: [behaviorengineering/polypus](https://github.com/behaviorengineering/polypus). Gateway operator skill lives in that repo (`ai-copilots/skills/polypus-operator/`), not here.

## When to load

- User says ask Gemma, ask Polypus, gemma on polypus, or equivalent
- User wants a local second-model review of prose, a plan, or a design choice
- NOT when the task is health, allow-lists, smoke, Switchyard, or `make serve` inside Polypus (load `polypus-operator` in the Polypus checkout instead)

## Defaults

| Setting | Value |
| --- | --- |
| Base URL | `http://127.0.0.1:1320` (override with `POLYPUS_BASE_URL`) |
| Chat path | `POST /v1/chat/completions` |
| Default model | `cf_local/@cf/google/gemma-4-26b-a4b-it` |
| Health | `GET /health` |
| Enabled models | `GET /v1/models` |

## Core constraints

**CONSTRAINT:** Before the consult call, MUST probe `GET ${POLYPUS_BASE_URL:-http://127.0.0.1:1320}/health`. MUST NOT POST chat while health is down.

- Enforcement: Run a bounded curl/http GET; require HTTP 2xx and a JSON body
- Violation: STOP, report gateway down; offer `make serve` in a Polypus checkout (MUST NOT start `bin/polypus` ad-hoc in a random shell)

CORRECT:
```bash
curl -sf --max-time 5 "${POLYPUS_BASE_URL:-http://127.0.0.1:1320}/health"
```

PROHIBITED:
```text
POST /v1/chat/completions without a health check
```

**CONSTRAINT:** Consult chat MUST use the OpenAI-compatible surface on loopback only. MUST send `model` as a prefixed id (default Gemma 4 below). MUST NOT call Cloudflare, Workers AI, or LM Studio URLs directly from the consumer chat.

- Enforcement: Request URL host is `127.0.0.1` or `localhost`; model id starts with `cf_local/`, `lm_studio/`, or `router/`
- Violation: STOP, rewrite to Polypus `:1320` with a prefixed model

CORRECT:
```json
{
  "model": "cf_local/@cf/google/gemma-4-26b-a4b-it",
  "messages": [{"role": "user", "content": "..."}],
  "temperature": 0.2
}
```

PROHIBITED:
```text
https://api.cloudflare.com/.../ai/v1/chat/completions
```

**CONSTRAINT:** When the user names Gemma (or says “ask gemma on polypus”) without another model id, MUST use `cf_local/@cf/google/gemma-4-26b-a4b-it`. When they name another allow-listed model or `router/<name>`, MUST use that id instead.

- Enforcement: Match user wording; default only when Gemma/unspecified
- Violation: STOP, switch model id; re-call if the wrong model already ran

**CONSTRAINT:** The consult prompt MUST include the concrete artifact under review (file excerpt, draft, or constraints). MUST NOT send a vague “what do you think?” with no payload.

- Enforcement: User message contains the text or a clear summary of the artifact plus the ask
- Violation: STOP, gather the artifact, then call

**CONSTRAINT:** After the model replies, MUST bring a short synthesis back to the human in this chat. MUST NOT paste only raw JSON. MUST NOT treat the consult as automatic authority to edit files unless the human already asked to implement.

- Enforcement: Reply states the consult verdict in prose; file edits wait for an implement request
- Violation: STOP, rewrite for the human; revert unsolicited edits

**CONSTRAINT:** MUST NOT confuse this skill with Polypus gateway operations. Config, allow-lists, smoke, TTS/STT, and Switchyard belong to `polypus-operator` in the Polypus repository.

- Enforcement: If the user is debugging `:1320` itself, load polypus-operator instead
- Violation: STOP, switch skills

## Steps

1. **Health** — `GET /health` (fail → tell human; offer Polypus `make serve`).
2. **Model** — Gemma default, or the id the human named.
3. **Prompt** — system role as a concise reviewer/editor; user role = artifact + ask.
4. **Call** — `POST /v1/chat/completions` with a bounded timeout (at least 120s for chat).
5. **Synthesize** — report the useful answer; keep raw model text only when needed.
6. **Next** — recommend one next step in this host chat; ask before implementing.

## Example call

```bash
BASE="${POLYPUS_BASE_URL:-http://127.0.0.1:1320}"
MODEL='cf_local/@cf/google/gemma-4-26b-a4b-it'
curl -sS --max-time 180 "$BASE/v1/chat/completions" \
  -H 'content-type: application/json' \
  -d "$(python3 - <<'PY'
import json
print(json.dumps({
  "model": "cf_local/@cf/google/gemma-4-26b-a4b-it",
  "temperature": 0.2,
  "max_tokens": 1800,
  "messages": [
    {"role": "system", "content": "You are a concise, exacting reviewer."},
    {"role": "user", "content": "ARTIFACT:\n...\n\nASK:\n..."}
  ],
}))
PY
)"
```

Python `urllib` is fine when the shell JSON is awkward. Prefer the gateway host process already running; do not embed CF credentials in the consumer repo.

## Pre-completion checklist

- [ ] **Health checked:** Gateway returned 2xx before chat
      Method: Inspect the health probe result
      Pass: JSON status ok (or equivalent 2xx)
      Fail: STOP, do not POST chat
- [ ] **Loopback + prefix:** URL is local; model is prefixed
      Method: Read the request URL and `model` field
      Pass: `:1320` + `cf_local/` / `lm_studio/` / `router/`
      Fail: STOP, fix routing
- [ ] **Artifact included:** Prompt carries the text under review
      Method: Read the user message
      Pass: Concrete payload present
      Fail: STOP, add artifact
- [ ] **Human synthesis:** Chat reply is prose for the human, not raw transport dump only
      Method: Skim the assistant reply
      Pass: Verdict and next step clear
      Fail: STOP, rewrite
