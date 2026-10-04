---
name: ask-polypus
description: >-
  Consult a second model through the Polypus OpenAI gateway (default
  http://127.0.0.1:1320; override with POLYPUS_BASE_URL for a remote host),
  defaulting to Gemma 4 on cf_local. Use when the user says ask Gemma, ask
  Polypus, go ask gemma on polypus, second opinion via Polypus, or wants a
  gateway chat completion without editing Polypus itself. Not for operating or
  debugging the gateway (use polypus-operator). Also use for dev env: Polypus
  gateway URL, Phoenix / OpenInference OTLP (POLYPUS_OTLP_ENDPOINT).
---

# Ask Polypus (Gemma consult)

**Moral:** When the human wants a second brain through Polypus, call the configured gateway OpenAI chat API (`POLYPUS_BASE_URL` or loopback default). Do not invent a cloud URL or edit the Polypus repo for a consult.

Upstream product: [behaviorengineering/polypus](https://github.com/behaviorengineering/polypus). Gateway operator skill lives in that repo (`ai-copilots/skills/polypus-operator/`), not here.

## When to load

- User says ask Gemma, ask Polypus, gemma on polypus, or equivalent
- User wants a second-model review of prose, a plan, or a design choice (local or remote gateway)
- NOT when the task is health, allow-lists, smoke, Switchyard, or `make serve` inside Polypus (load `polypus-operator` in the Polypus checkout instead)

## Defaults

| Setting | Value |
| --- | --- |
| Base URL | `http://127.0.0.1:1320` (override with `POLYPUS_BASE_URL`) |
| Chat path | `POST /v1/chat/completions` |
| Default model | `cf_local/@cf/google/gemma-4-26b-a4b-it` |
| Health | `GET /health` |
| Enabled models | `GET /v1/models` |

Resolve `BASE` once per consult:

```bash
BASE="${POLYPUS_BASE_URL:-http://127.0.0.1:1320}"
```

## Dev env (gateway + Phoenix / OpenInference OTLP)

Export these in direnv, shell profile, or the MCP/pipelines parent process so **chat and client OTLP share the same Polypus host** (local `make serve` or remote Tailscale URL).

| Env | Role | Loopback default (Polypus `make serve`) |
| --- | --- | --- |
| `POLYPUS_BASE_URL` | OpenAI gateway origin (no `/v1`) | `http://127.0.0.1:1320` |
| `POLYPUS_OTLP_ENDPOINT` | Phoenix OTLP gRPC `host:port` (Arize Phoenix UI reads these traces) | `127.0.0.1:4317` when unset; with remote `POLYPUS_BASE_URL`, derive `<gateway-host>:4317` |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | Generic OTel (optional; Polypus gateway may mirror from `POLYPUS_OTLP_ENDPOINT`) | Same collector as Phoenix when tracing is on |

| Surface | URL |
| --- | --- |
| Phoenix UI (traces) | `http://127.0.0.1:6006` on the Polypus host |
| OTLP gRPC | `host:4317` on the Polypus host (not the gateway `:1320` port) |

**CONSTRAINT:** Consumer YAML MUST use `${POLYPUS_OTLP_ENDPOINT}` for `openinference.endpoint` (or equivalent), not hardcoded `localhost:4317`, when `POLYPUS_BASE_URL` can be remote. Hosts SHOULD register defaults via `operatorconfig` `EnvDefaults` (see `operator-config` skill).

**CONSTRAINT:** MUST NOT put OTLP URLs in `secrets:`; they are operator env, not keyring credentials.

Polypus-only toggles (`POLYPUS_OTEL`, `POLYPUS_PHOENIX`, `POLYPUS_FAILURE_DUMP_DIR`): see `polypus-operator` in the Polypus repo.

Example (remote gateway + derived OTLP):

```bash
export POLYPUS_BASE_URL=https://polypus.example.ts.net
# POLYPUS_OTLP_ENDPOINT unset → consumers derive polypus.example.ts.net:4317
```

Example (local dev):

```bash
export POLYPUS_BASE_URL=http://127.0.0.1:1320
export POLYPUS_OTLP_ENDPOINT=127.0.0.1:4317
```

## Core constraints

**CONSTRAINT:** Before the consult call, MUST probe `GET ${BASE}/health` where `BASE` is `${POLYPUS_BASE_URL:-http://127.0.0.1:1320}`. MUST NOT POST chat while health is down.

- Enforcement: Run a bounded curl/http GET; require HTTP 2xx and a JSON body
- Violation: STOP, report gateway down; follow the recovery branch below (MUST NOT start `bin/polypus` ad-hoc in a random shell)

**CONSTRAINT:** On health failure, recovery MUST depend on whether `BASE` points at loopback.

- IF the host of `BASE` is `127.0.0.1` or `localhost` → report down; MAY offer `make serve` in a Polypus checkout on this machine
- ELSE → report that the configured remote gateway is unreachable; MUST NOT offer local `make serve`, stack restart, or deploy on this consumer; tell the human to check the remote host or its deploy

Enforcement: Parse `BASE` host before suggesting recovery; remote failure stops the consult without local restart advice

CORRECT (loopback down):
```text
Gateway at http://127.0.0.1:1320 is down. Start Polypus with make serve in a Polypus checkout if you want consults locally.
```

CORRECT (remote down):
```text
Gateway at https://polypus.example.ts.net/ is unreachable. Check the remote host or deploy; I cannot restart that stack from here.
```

PROHIBITED:
```text
Remote POLYPUS_BASE_URL failed → offer make serve on the laptop
```

CORRECT (health probe):
```bash
curl -sf --max-time 5 "${POLYPUS_BASE_URL:-http://127.0.0.1:1320}/health"
```

PROHIBITED:
```text
POST /v1/chat/completions without a health check
```

**CONSTRAINT:** Consult chat MUST use the OpenAI-compatible surface on the resolved `BASE` only. MUST send `model` as a prefixed id (default Gemma 4 below). MUST NOT call Cloudflare, Workers AI, or LM Studio URLs directly from the consumer chat.

- Enforcement: Request URL is `${BASE}/v1/chat/completions`; model id starts with `cf_local/`, `lm_studio/`, or `router/`
- Violation: STOP, rewrite to `${BASE}` with a prefixed model

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

- Enforcement: If the user is debugging the gateway host itself, load polypus-operator instead
- Violation: STOP, switch skills

## Steps

1. **Resolve BASE** — `${POLYPUS_BASE_URL:-http://127.0.0.1:1320}`.
2. **Health** — `GET ${BASE}/health` (fail → report using loopback vs remote recovery branch).
3. **Model** — Gemma default, or the id the human named.
4. **Prompt** — system role as a concise reviewer/editor; user role = artifact + ask.
5. **Call** — `POST ${BASE}/v1/chat/completions` with a bounded timeout (at least 120s for chat).
6. **Synthesize** — report the useful answer; keep raw model text only when needed.
7. **Next** — recommend one next step in this host chat; ask before implementing.

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

Python `urllib` is fine when the shell JSON is awkward. Use the gateway already running at `BASE`; do not embed CF credentials in the consumer repo.

## Pre-completion checklist

- [ ] **Health checked:** Gateway returned 2xx before chat
      Method: Inspect the health probe result
      Pass: JSON status ok (or equivalent 2xx)
      Fail: STOP, do not POST chat
- [ ] **Gateway base + prefix:** URL is resolved `BASE`; model is prefixed
      Method: Read the request URL and `model` field
      Pass: `${BASE}/v1/chat/completions` + `cf_local/` / `lm_studio/` / `router/`
      Fail: STOP, fix routing
- [ ] **Artifact included:** Prompt carries the text under review
      Method: Read the user message
      Pass: Concrete payload present
      Fail: STOP, add artifact
- [ ] **Human synthesis:** Chat reply is prose for the human, not raw transport dump only
      Method: Skim the assistant reply
      Pass: Verdict and next step clear
      Fail: STOP, rewrite
