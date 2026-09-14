---
name: dspy-pipeline-isolation
description: >-
  Isolate dspy-go generators and evaluators before joining a JobRunner chain:
  capture module-trace fixtures, env-gated live opt-in replay, structured
  signature fields, and durable dumps. Use when adding or changing a generator,
  evaluator, or pipeline step, or when debugging CoT/Predict without a full
  end-to-end reseed.
---

# DSPy pipeline isolation

**Principle:** Tune each generator and evaluator in isolation from a captured fixture, then plug it back into the chain. A full pipeline reseed is the integration check, not the inner loop.

**Related:** `.cursor/skills/dspy-xml-structured-output/SKILL.md` (structured fields), `.cursor/skills/dspy-go-debugging/SKILL.md` (failures), `.cursor/skills/dspy-module-patterns/SKILL.md` (wiring), `.cursor/skills/strop-pipeline-pattern/SKILL.md` (TraceDir / module-traces / runreport), golang-quality **C15–C17**.

---

## When to load

- Adding or changing a dspy-go generator or evaluator in a pipeline
- Prompt or signature edits where a full reseed is too slow
- Reviewing whether a PR left an opt-in live replay path

---

## 1. Capture, then replay

**CONSTRAINT:** Before iterating on a generator or evaluator, MUST capture Process inputs (and recorded outputs when useful) from a durable module-trace or RLM TraceDir dump. MUST NOT use a full pipeline reseed as the only way to exercise that module.

- Enforcement: Fixture under `testdata/` (or documented path) loads into `Generate` / `Evaluate`; live test is opt-in via env.
- Violation: STOP, extract a span fixture from `module-traces/` (or TraceDir), add offline and/or live replay, re-check.

For RLM steps, prefer TraceDir/`rlm_inputs.jsonl` (strop `RLMComplete` sidecar with full context + query). Do not rely on dspy-go session metadata `context` alone; that field is truncated to ~500 characters for display.

CORRECT:
```text
1. Run pipeline once with AttachModuleTrace / work-story dumps.
2. Save Predict:<task> inputs to testdata/<task>_span.json.
3. Offline: zip/parse recorded outputs through Go gates (no LLM).
4. Live: MAJORDOMO_LIVE_<TASK>_REPLAY=1 go test -run Live… (Polypus up).
5. Rejoin JobRunner chain only after the isolated step looks right.
```

PROHIBITED:
```text
Change typology_cluster instruction → only way to verify is a 10-minute context digest reseed.
```

Host example (Majordomo): `internal/contextdigest/cluster_replay_live_test.go` + `testdata/cluster_replay/`.

---

## 2. Live opt-in (all generators and evaluators)

**CONSTRAINT:** Each pipeline generator and chained evaluator that calls an LLM MUST have (or gain, when touched) an env-gated live replay test that runs that module alone against a real provider (for example Polypus). Default `go test` MUST skip live calls so CI stays offline.

- Enforcement: Search for `LIVE_` / `Skip` + `Generate(` / `Evaluate(` for the task; CI suite does not require the env.
- Violation: STOP, add opt-in live test (or extend a shared replay helper), document the env in a nearby README, re-check.

CORRECT:
```bash
# CI / default
go test ./internal/contextdigest/ -count=1

# Operator inner loop
MAJORDOMO_LIVE_CLUSTER_REPLAY=1 go test ./internal/contextdigest/ \
  -run LiveTypologyClusterReplay -count=1 -v -timeout 5m
```

PROHIBITED:
```go
// Live LLM in every go test with no env gate
func TestClusterAlwaysHitsPolypus(t *testing.T) { … }
```

Prefer one helper pattern per host (load fixture → `AttachModuleTrace` → `NewRuntime` with that task only → `Generate`/`Evaluate` → log fields + zip gates).

---

## 3. Structured outputs stay mandatory

**CONSTRAINT:** Discrete machine contracts (ids, lists, verdicts, merge rows, scores) MUST be signature output fields parsed by strop structured XML. MUST NOT gate Go on scraped `*_md` counsel. Full detail: `dspy-xml-structured-output` §0 and §0.1.

- Enforcement: Gate reads `stringField` / typed map from the signature; no heading/regex scrape of counsel markdown for the contract.
- Violation: STOP, add or restore the structured field, move the gate, re-check.

---

## 4. Dumps and spans stay on

**CONSTRAINT:** Isolation work MUST keep golang-quality **C15** (OTEL / OpenInference spans) and **C16** (durable TraceDir, module-traces, runreport) enabled. Live replay MUST write a fresh module-trace (or TraceDir) under a durable or test-temp path the operator can open after the test.

- Enforcement: Live test attaches TraceSession / TraceDir; path logged on success.
- Violation: STOP, wire `AttachModuleTrace` (or RLM TraceDir), log the path, re-check.

---

## 5. Review bar (Stage 5)

When staged review **Stage 5** (Generation Gates) runs on AI module changes, apply golang-quality **C17** and appendix pattern 16: structured fields, durable dumps, and opt-in live replay (or an explicit offline-only rationale in the PR).

---

## Pre-completion checklist

- [ ] **Fixture:** Process inputs captured under testdata (or documented dump path)
      Pass: JSON/YAML loads in the replay test. Fail: extract from module-traces first.
- [ ] **Offline gate:** Recorded or stub outputs exercise Go zip/parse without LLM
      Pass: default `go test` covers the gate. Fail: add offline case.
- [ ] **Live opt-in:** Env-gated `Generate`/`Evaluate` for this task
      Fail: missing env gate or live call always on.
- [ ] **Structured fields:** Discrete contracts are signature outs, not `*_md` scrapes
- [ ] **Dumps:** Live run logs a module-trace or TraceDir path (C15/C16)
