---
name: hypermedia-update-contract
description: >-
  Server-driven HTML update contract for Datastar, datastar-go, htmx, and
  templ SSE morphs: two patch contracts (command workspace vs live progress),
  GET and patch share one view renderer, fat-morph a workspace root. Use when
  adding data-on:click, patch-elements, morph, out-of-band swaps, or when a
  command succeeds but a panel stays stale until a full refresh.
---

# Hypermedia update contract

Procedure for server-rendered HTML that the browser morphs (Datastar `patch-elements`, htmx out-of-band, templ SSE). The library patches matching ids. It does not know which regions a command invalidates.

---

## When to load

- Adding or changing a server HTML patch, SSE morph, `data-on:click` action, or htmx swap
- A command succeeds and a panel (proposal, approved draft, run controls) stays stale until refresh
- Splitting live progress updates from a full workspace refresh

---

## Core constraints

**CONSTRAINT 1:** Command/board refresh and live progress/activity MUST be two named patch contracts. A progress patch MUST NOT reuse the command fragment when that fragment includes proposal or editor chrome.

- MUST: name the contract (`command` or `progress`) before choosing a renderer
- MUST NOT: send proposal, editor, or approval panels on a progress tick
- Enforcement: the progress call site names `renderPlan` (or equivalent) and does not call the workspace view function
- Violation: STOP, split the renderers, re-verify both call sites

CORRECT:
```text
command  -> renderWorkspace(view)   # proposal, approved, run, plan
progress -> renderPlanActivity(view) # plan and activity only
```

PROHIBITED:
```text
progress tick calls renderWorkspace and morphs the open proposal editor
```

**CONSTRAINT 2:** Command remorph HTML MUST come from the same view function as the initial page body for that view. After the command commits, a full reload MUST show the same workflow state as the patch.

- MUST: one view function serves GET and the command patch
- MUST NOT: keep a second, smaller fragment that omits regions the full view renders
- Enforcement: grep the command handler and the GET handler; both call the same view function
- Violation: STOP, delete the partial fragment from the command path

CORRECT:
```text
GET  /workspace -> WorkspaceView(data)
POST /actions   -> WorkspaceView(data) -> patch #workspace
```

PROHIBITED:
```text
GET renders proposal + approved + run
POST patches only the plan panel
```

**CONSTRAINT 3:** Before writing or calling a patch helper, fill the invalidate-before-patch gate for every candidate region. MUST NOT emit the patch until every candidate has a decision.

Candidates (fixed list): `proposal`, `approved`, `run`, `plan`, `chrome`.

```text
Candidate: proposal | approved | run | plan | chrome
Command changes visibility or body: YES: [quote the read-model field or UI rule] / NO
Decision: include | omit | progress-only
If include: renderer: [view function]
            contract: command
If progress-only: renderer: [plan/activity function]
                  contract: progress
```

- MUST: quote evidence for YES; NO is absence of a quoted change
- MUST: limit Decision to include, omit, or progress-only
- Enforcement: the implementation notes or PR body contain one completed gate line per candidate before the patch call is added
- Violation: STOP, fill the blank candidate, then write the helper

CORRECT:
```text
Candidate: proposal
Command changes visibility or body: YES: pending flag cleared, proposal hidden
Decision: include
If include: renderer: WorkspaceView
            contract: command

Candidate: plan
Command changes visibility or body: NO
Decision: omit
```

PROHIBITED:
```text
Patch whatever ids look related to the button.
```

**CONSTRAINT 4:** A command patch MUST fat-morph one coherent workspace root (one wrapper id) rendered by the view function. Selective region lists are allowed only when a measured cost or an isolated widget requires them, and then the invalidation key MUST be a semantic topic, not a growing CSS-id checklist inside each handler.

- MUST: wrap the view body in one stable id and patch that id (or the view root the morph library already matches)
- MUST NOT: append a new selector in every handler when a region is forgotten
- Enforcement: the command response contains the workspace root id; handlers do not each list `proposal`, `approved`, and `run` ids
- Violation: STOP, render the workspace root from the view function

CORRECT:
```text
Agree -> load read model -> WorkspaceView -> patch #workspace
```

PROHIBITED:
```text
Agree handler patches #plan only; operator refreshes to see approval
```

**CONSTRAINT 5:** `data-ignore-morph` and client signals MUST NOT be treated as the update path for server-owned workflow (approval, pending review, whether run controls are enabled).

- MUST: put workflow visibility in the server view and include it in the command patch
- MUST NOT: leave approval state only in browser memory
- Enforcement: after the command, the patched HTML shows the post-commit visibility (hidden proposal, visible approved, enabled or disabled run) without a client-only flag
- Violation: STOP, render that state from the read model

CORRECT:
```text
post-commit read model has approved body
WorkspaceView renders the approved panel and hides the proposal
```

PROHIBITED:
```text
client sets optimisticApproved and the server patch never sends the approved panel
```

---

## Steps

1. Name the contract: `command` or `progress`.
2. Fill the invalidate-before-patch gate for all five candidates.
3. On `command`, call the same view function as GET and patch the workspace root.
4. On `progress`, call the plan/activity renderer only.
5. Add a test that the command response contains the regions whose Decision was `include`, using the post-commit read model (not the pre-command page).

---

## Pre-completion checklist

- [ ] **Two contracts:** progress call site does not call the workspace view
      Method: grep the progress handler for the workspace view function name
      Pass: no match
      Fail: STOP, point progress at the plan/activity renderer
- [ ] **GET identity:** command patch and GET call the same view function
      Method: compare the two call sites
      Pass: same function
      Fail: STOP, delete the partial command fragment
- [ ] **Gate filled:** five candidates, each with YES quote or NO, and a Decision
      Method: read the notes or PR body
      Pass: proposal, approved, run, plan, chrome all present
      Fail: STOP, fill the missing candidate before shipping the helper
- [ ] **No signal-only workflow:** approval or pending visibility is in the patched HTML
      Method: assert the command response HTML for hidden proposal or visible approved
      Pass: assertion exists and passes
      Fail: STOP, render it from the read model
