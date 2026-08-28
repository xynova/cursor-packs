# cursor-packs

Shared Cursor **skills** and short **rules**, reusable across projects via git submodule + relative symlinks.

Repo: https://github.com/xynova/cursor-packs

Mount path in consumers: `.cursor/packs/shared`

## What is in the pack

| Path | Purpose |
|------|---------|
| `skills/edit-cursor-packs/` | Branch/commit shared pack edits (not the consumer repo) |
| `skills/agent-smith/` | Author/review Cursor skills and rules (Agent Smith standards) |
| `skills/golang-quality/` | Generation/completion constraints + quality gates |
| `skills/review-code-staged/` | Staged Go review (menu, detect vs consultant) |
| `skills/setup-goreleaser/` | Scaffold GoReleaser v2 + GitHub Release workflow (gitboard pattern) |
| `skills/dspy-go-debugging/` | Validation / retry / refinement failures |
| `skills/dspy-module-patterns/` | Module + interceptor wiring |
| `skills/dspy-prompt-engineering/` | Signature / instruction / field-description contract |
| `skills/review-member-visibility/` | Export-only-what-is-essential audit |
| `rules/golang.mdc` | `globs: **/*.go` — load golang-quality / staged review |
| `rules/dspy.mdc` | Agent-decided — load thin dspy skills |
| `rules/cursor-packs.mdc` | Soft-link ownership — load edit-cursor-packs |
| `rules/agent-smith.mdc` | Authoring skills/rules — load agent-smith |

References (`reference.md`, `methodology.md`, …) live **inside** each skill folder; no separate symlink set.

More skills/rules (any stack) can be added here over time; consumers re-run the link script after updating the submodule.

## What stays in the consuming project

Keep as real files under `.cursor/skills/` / `.cursor/rules/`:

- Pipeline / product skills (e.g. `pipeline-client-module-pattern`, `human-review-flow`)
- Repo-tuned XML parser skill (`dspy-xml-structured-output`)
- Fat invariant rules (architecture, golang encyclopedia, prompts, secrets, chat style)
- Project commands under `.cursor/commands/`

## Add to a project

From the consumer repo root:

```bash
git submodule add https://github.com/xynova/cursor-packs.git .cursor/packs/shared
git submodule update --init --recursive

# If you previously had real copies of shared skills, remove those directories first
# so the linker can create symlinks (it will not overwrite non-symlink dirs).

.cursor/packs/shared/scripts/link-into-project.sh --project .
```

Commit `.gitmodules`, the submodule pointer, and the new symlinks.

### After clone

```bash
git submodule update --init --recursive
.cursor/packs/shared/scripts/link-into-project.sh --project .
```

(Re-run the link script if you upgrade the pack and new skill names appear.)

## Link script behavior

- Creates relative links: `.cursor/skills/golang-quality` → `../packs/shared/skills/golang-quality`
- Updates existing symlinks
- **Skips** paths that already exist as real files/directories (protects local overlays)

## Sparse checkout

Not used in v1. Revisit if this repo later gains large non-Cursor trees.
