---
name: plan-scaffold
description: Use when the user asks to create a new implementation plan, plan a feature, or write a plan for X. Follows the Plan Scaffold meta-framework so plans include glue/wiring analysis and don't miss critical steps.
---

# Plan Scaffold Skill

When the user asks to **create an implementation plan** (e.g. "plan the X feature", "create a plan for Y", "write an implementation plan"), use the **Plan Scaffold** so the plan is thorough and catches wiring/glue issues.

## What to do

1. **Read the full scaffold** (once) from `.cursor/skills/plan-scaffold/PLAN-SCAFFOLD.md` so you have the standard sections, checklists, and glue analysis template.

2. **Create the plan** in `.cursor/plans/<feature-name>-plan.md` (or a name the user prefers) with:
   - **Overview & context**: What we're building, why, reference implementation (pattern source + file:lines).
   - **Architectural analysis (the glue)**: Answer explicitly — registry? DI? factories? config? migrations? CLI wiring? Use the scaffold's checklists so nothing is skipped.
   - **Data flow diagram**: CLI → service → client → registry/repo → DB with real method names.
   - **Glue analysis**: Registration sequence, what depends on registration, "can I run the command?" trace.
   - **Implementation phases**: Use the scaffold's Phase A–G order (Schema & config → Data access → Modules → Registration & clients → Services → CLI → E2E). Add feature-specific tasks; include checkpoints.

3. **Before calling the plan "done"**: Run the scaffold's **Plan Review Checklist** (completeness, glue, error handling, testing). Ensure every `Get[Thing](key)` is traceable back to a `Register[Thing](key, value)` if the feature uses a registry.

## Key rule

**Most implementation failures are glue failures.** The scaffold exists to force explicit registration/wiring analysis before coding. Do not skip the glue section or the "registration before client creation" ordering.

## Reference

- Full template, phases, and examples: **`.cursor/skills/plan-scaffold/PLAN-SCAFFOLD.md`** (same directory as this skill).
- Existing plans in `.cursor/plans/` and `archive/` for style and depth.
