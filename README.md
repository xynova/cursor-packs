# cursor-packs

Shared Cursor **skills**, short **rules**, and gated **personas**, reusable across projects via git submodule + relative symlinks.

Repo: https://github.com/xynova/cursor-packs

Mount path in consumers: `.cursor/packs/shared`

## What is in the pack

| Path | Purpose |
|------|---------|
| `skills/edit-cursor-packs/` | Branch/commit shared pack edits (not the consumer repo) |
| `skills/agent-smith/` | Author/review Cursor skills and rules (Agent Smith standards) |
| `skills/golang-quality/` | Generation/completion constraints + quality gates; `reference.md` encyclopedia |
| `skills/review-code-staged/` | Staged Go review (menu, detect vs consultant) |
| `skills/setup-goreleaser/` | Scaffold GoReleaser v2 + GitHub Release workflow |
| `skills/manage-go-releases/` | Auto-patch / skip docs-chore / pin consumers to `v*` (agent release practice) |
| `skills/dspy-xml-structured-output/` | Generic XML parser + mandatory-field validation (strop paths) |
| `skills/dspy-go-debugging/` | Validation / retry / refinement failures |
| `skills/dspy-module-patterns/` | Module + interceptor wiring; `reference.md` dspy-go encyclopedia |
| `skills/dspy-prompt-engineering/` | Compact prompt contract; `reference.md` bias/CoT/templates |
| `skills/strop-orchestration/` | Refinement loops, composition walks, regenerate policy |
| `skills/strop-pipeline-pattern/` | JobRunner, clients, modules, evaluators, one table per job |
| `skills/strop-human-review/` | Gate, reviewflow engine, ports, reject-and-regen |
| `skills/plan-scaffold/` | Implementation plan meta-framework |
| `skills/review-member-visibility/` | Export-only-what-is-essential audit |
| `skills/review-code-smells/` | Code smell / maintainability review protocol |
| `skills/perplexity-browser-research/` | Perplexity Pro via Browser MCP; default persona + packs. Project overlay: `.cursor/perplexity/` (not inside the skill symlink) |
| `rules/golang.mdc` | `globs: **/*.go` — load golang-quality / staged review |
| `rules/dspy.mdc` | Agent-decided — load thin dspy skills |
| `rules/strop.mdc` | Agent-decided — load strop orchestration / pipeline / review skills |
| `rules/go-releases.mdc` | Agent-decided — load manage-go-releases for tags and consumer pins |
| `rules/cursor-packs.mdc` | Soft-link ownership — load edit-cursor-packs |
| `rules/agent-smith.mdc` | Authoring skills/rules — load agent-smith |
| `rules/always-rules-0-ai.mdc` | Always-on model behavior: English identifiers, US spelling, no em dash, tmp clones |
| `rules/always-rules-01-human-interaction.mdc` | Always-on fluent consultant + light tutor voice, implement gate, Intent-First / Consultant loaders |
| `rules/png-to-webp.mdc` | `globs: **/*.png` — convert shipping PNGs with cwebp, update refs, drop duplicates |
| `personas/intent-first.persona.md` | Gated: confirm exploratory intent, then wait |
| `personas/consultant.persona.md` | Gated: present real forks, wait for a pick |

References (`reference.md`, `methodology.md`, …) live **inside** each skill folder.

## What stays in the consuming project

Keep as real files under `.cursor/skills/` / `.cursor/rules/`:

- **Product overlays** prefixed for the consumer (e.g. `pipelines-x-*` in content-pipelines): YouTube notes, PostGenerator hooks, classroom paths
- Thin always-rules for architecture / secrets / product skill names (not encyclopedias — those live in pack `reference.md`)
- Model-behavior and chat kernels (`always-rules-0`, `always-rules-01` + personas) are pack-owned. Keep a thin overlay for restyle exceptions, `content/` spelling, and named workflows.
- Perplexity project persona and prompt packs: **`.cursor/perplexity/`** (real files). MUST NOT put overlays under `.cursor/skills/perplexity-browser-research/`.

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

## Versioning

Every merge to `main` creates the next patch tag (`v0.1.0`, then `v0.1.1`, …) and a GitHub Release with auto-generated notes.

Pin or upgrade a consumer submodule to a release:

```bash
cd .cursor/packs/shared
git fetch --tags origin
git checkout v0.1.0   # or latest: git checkout "$(git tag -l 'v*' --sort=-v:refname | head -n1)"
cd ../../..
git add .cursor/packs/shared
.cursor/packs/shared/scripts/link-into-project.sh --project .
git commit -m "Bump cursor-packs to v0.1.0"
```

Git still records a commit SHA under the hood; tags are the human-facing pin.

## strop consumers

This pack assumes runtime lives in `github.com/behaviorengineering/strop`. App repos map config/logger at the boundary and keep product prompts, job packs, and DB adapters local.

Load order for a new pipeline job:

1. `strop-pipeline-pattern` + `strop-orchestration`
2. `dspy-prompt-engineering` + `dspy-xml-structured-output`
3. Project overlay (if any)

## Link script behavior

- Creates relative links: `.cursor/skills/golang-quality` → `../packs/shared/skills/golang-quality`, and the same pattern for rules and personas
- Updates existing symlinks
- **Skips** paths that already exist as real files/directories (protects local overlays)
- Allow-lists are `SKILLS`, `RULES`, `PERSONAS` only. **Never** links or overwrites `.cursor/perplexity/`
