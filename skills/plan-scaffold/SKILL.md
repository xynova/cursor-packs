---
name: plan-scaffold
description: >-
  Use when the user asks to create an implementation plan, plan a feature, write
  a plan for X, or when working in Plan mode on a multi-step change. Follows the
  Plan Scaffold so plans include glue analysis, staged executor contracts a
  smaller model can run, repository boundaries, and quality gates. After the
  draft exists, the plan-auditor subagent scores those stages and may patch
  the plan markdown. It must not implement product code.
---

# Plan Scaffold Skill

When the user asks to **create an implementation plan** (e.g. "plan the X feature", "create a plan for Y", "write an implementation plan"), use the **Plan Scaffold** so the plan is thorough, catches wiring/glue issues, and enforces language standards.

## What to do

1. **Read the full scaffold** (once) from `.cursor/skills/plan-scaffold/PLAN-SCAFFOLD.md` so you have the standard sections, checklists, and glue analysis template.

2. **Create the plan** in `.cursor/plans/<feature-name>-plan.md` (or a name the user prefers) with:
   - **Overview & context**: What we're building, why, reference implementation (pattern source + file:lines).
   - **Architectural analysis (the glue)**: Answer explicitly: registry? DI? factories? config? migrations? CLI wiring? resumable trajectories? repository boundaries? Use the scaffold's checklists so nothing is skipped.
   - **Language & quality standards**: For Go projects, mandate `golang-quality` constraints (package layout kit vs app, typed error wrapping, constructor nil guards, config create, durable traces, and verification gates).
   - **Data flow diagram**: CLI -> service -> client -> registry/repo -> DB with real method names.
   - **Glue analysis**: Registration sequence, what depends on registration, "can I run the command?" trace.
   - **Implementation phases**: Use the scaffold's Phase order (Schema & config -> Data access -> Modules -> Registration & clients -> Services -> CLI -> Trajectory/Resumability -> Quality Verification & E2E). Split those phases into **executor stages** that each satisfy the scaffold's Executor stage contract (Goal, Paths, Out of scope, Commands, Pass, Fail closed, Resume).
   - **Multi-repository delivery**: If changes touch submodules or shared packs, split into Phase 1 (library commit/PR) and Phase 2 (host pin bump and adapter wiring).

3. **Before calling the plan "done"**: Run the scaffold's **Plan Review Checklist** (completeness, glue, executor stages, error handling, resumability, boundaries, language quality, and testing). Ensure every `Get[Thing](key)` is traceable back to a `Register[Thing](key, value)` if the feature uses a registry.

4. **Independent score (when a plan file exists):** Invoke the `plan-auditor` subagent (`/plan-auditor`) with the plan file path and full markdown. It may rewrite that plan file so FAIL stages meet the executor contract. It MUST NOT implement product code. Repair any remaining `Needs from human` before Build.

## Key rule

**Most implementation failures are glue failures, state loss on failure, or boundary leaks.** The scaffold exists to force explicit registration/wiring analysis, resumable trajectory planning, and quality gate definition before coding. Do not skip the glue section, repository boundary checks, or language quality gates.

## Reference

- Full template, phases, and examples: **`.cursor/skills/plan-scaffold/PLAN-SCAFFOLD.md`** (same directory as this skill).
- Go quality standards: **`.cursor/skills/golang-quality/SKILL.md`**.
- Repository boundaries: **`.cursor/rules/repository-boundaries.mdc`**.
- Existing plans in `.cursor/plans/` and `archive/` for style and depth.
- Plan auditor subagent: **`.cursor/agents/plan-auditor.md`**.
