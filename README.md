# cursor-go-dspy

Shared Cursor **skills** and short **rules** for Go and dspy-go, reusable across projects via git submodule + relative symlinks.

Repo: https://github.com/xynova/cursor-go-dspy

## What is in the pack

| Path | Purpose |
|------|---------|
| `skills/golang-quality/` | Generation/completion constraints + quality gates |
| `skills/code-review-staged/` | Staged Go review (menu, detect vs consultant) |
| `skills/dspy-go-debugging/` | Validation / retry / refinement failures |
| `skills/dspy-module-patterns/` | Module + interceptor wiring |
| `skills/dspy-prompt-engineering/` | Signature / instruction / field-description contract |
| `skills/review-member-visibility/` | Export-only-what-is-essential audit |
| `rules/golang.mdc` | `globs: **/*.go` — load golang-quality / staged review |
| `rules/dspy.mdc` | Agent-decided — load thin dspy skills |

References (`reference.md`, `methodology.md`, …) live **inside** each skill folder; no separate symlink set.

## What stays in the consuming project

Keep as real files under `.cursor/skills/` / `.cursor/rules/`:

- Pipeline / product skills (e.g. `pipeline-client-module-pattern`, `human-review-flow`)
- Repo-tuned XML parser skill (`dspy-xml-structured-output`)
- Fat invariant rules (architecture, golang encyclopedia, prompts, secrets, chat style)
- Project commands under `.cursor/commands/`

## Add to a project

From the consumer repo root:

```bash
git submodule add https://github.com/xynova/cursor-go-dspy.git .cursor/packs/go-dspy
git submodule update --init --recursive

# If you previously had real copies of shared skills, remove those directories first
# so the linker can create symlinks (it will not overwrite non-symlink dirs).

.cursor/packs/go-dspy/scripts/link-into-project.sh --project .
```

Commit `.gitmodules`, the submodule pointer, and the new symlinks.

### After clone

```bash
git submodule update --init --recursive
.cursor/packs/go-dspy/scripts/link-into-project.sh --project .
```

(Re-run the link script if you upgrade the pack and new skill names appear.)

## Link script behavior

- Creates relative links: `.cursor/skills/golang-quality` → `../packs/go-dspy/skills/golang-quality`
- Updates existing symlinks
- **Skips** paths that already exist as real files/directories (protects local overlays)

## Sparse checkout

Not used in v1. The pack is Cursor-only. Revisit if this repo later gains large non-Cursor trees.
