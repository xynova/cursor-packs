# cursor-packs

Shared Cursor **skills** and short **rules**, reusable across strop/DSPy/Go projects via git submodule + relative symlinks.

Repo: https://github.com/xynova/cursor-packs

Mount path in consumers: `.cursor/packs/shared`

## What is in the pack

| Path | Purpose |
|------|---------|
| `skills/edit-cursor-packs/` | Branch/commit shared pack edits (not the consumer repo) |
| `skills/agent-smith/` | Author/review Cursor skills and rules (Agent Smith standards) |
| `skills/golang-quality/` | Generation/completion constraints + quality gates |
| `skills/review-code-staged/` | Staged Go review (menu, detect vs consultant) |
| `skills/setup-goreleaser/` | Scaffold GoReleaser v2 + GitHub Release workflow |
| `skills/dspy-xml-structured-output/` | Generic XML parser + mandatory-field validation (strop paths) |
| `skills/dspy-go-debugging/` | Validation / retry / refinement failures |
| `skills/dspy-module-patterns/` | Module + interceptor wiring |
| `skills/dspy-prompt-engineering/` | Signature / instruction / field-description contract |
| `skills/strop-orchestration/` | Refinement loops, composition walks, regenerate policy |
| `skills/strop-pipeline-pattern/` | JobRunner, clients, modules, evaluators, one table per job |
| `skills/strop-human-review/` | Gate, reviewflow engine, ports, reject-and-regen |
| `skills/plan-scaffold/` | Implementation plan meta-framework |
| `skills/review-member-visibility/` | Export-only-what-is-essential audit |
| `rules/golang.mdc` | `globs: **/*.go` — load golang-quality / staged review |
| `rules/dspy.mdc` | Agent-decided — load thin dspy skills |
| `rules/strop.mdc` | Agent-decided — load strop orchestration / pipeline / review skills |
| `rules/cursor-packs.mdc` | Soft-link ownership — load edit-cursor-packs |
| `rules/agent-smith.mdc` | Authoring skills/rules — load agent-smith |

References (`reference.md`, `methodology.md`, …) live **inside** each skill folder.

## What stays in the consuming project

Keep as real files under `.cursor/skills/` / `.cursor/rules/`:

- **Product overlays** that extend pack skills (e.g. YouTube-specific pipeline notes, phased PostGenerator hooks, sayings review classroom paths)
- Fat invariant rules (architecture, golang encyclopedia, prompts, secrets, chat style)
- Project commands under `.cursor/commands/`

The link script **skips** existing real directories — overlays are safe next to pack symlinks.

## Add to a project

From the consumer repo root:

```bash
git submodule add https://github.com/xynova/cursor-packs.git .cursor/packs/shared
git submodule update --init --recursive
.cursor/packs/shared/scripts/link-into-project.sh --project .
```

Commit `.gitmodules`, the submodule pointer, and the new symlinks.

### After clone

```bash
git submodule update --init --recursive
.cursor/packs/shared/scripts/link-into-project.sh --project .
```

(Re-run the link script when upgrading the pack and new skill names appear.)

## strop consumers

This pack assumes runtime lives in `github.com/behaviorengineering/strop`. App repos map config/logger at the boundary and keep product prompts, job packs, and DB adapters local.

Load order for a new pipeline job:

1. `strop-pipeline-pattern` + `strop-orchestration`
2. `dspy-prompt-engineering` + `dspy-xml-structured-output`
3. Project overlay (if any)

## Link script behavior

- Creates relative links: `.cursor/skills/golang-quality` → `../packs/shared/skills/golang-quality`
- Updates existing symlinks
- **Skips** paths that already exist as real files/directories (protects local overlays)
