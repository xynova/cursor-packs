# cursor-packs

Shared Cursor **skills**, short **rules**, and gated **personas**, reusable across projects via git submodule + relative symlinks.

Repo: https://github.com/xynova/cursor-packs

Mount path in consumers: `.cursor/packs/shared`

## What is in the pack

| Path | Purpose |
|------|---------|
| `skills/edit-cursor-packs/` | Branch/commit shared pack edits (not the consumer repo) |
| `skills/agent-smith/` | Author/review Cursor skills and rules (Agent Smith standards) |
| `skills/author-ai-copilots/` | Library-owned `ai-copilots/` harness + multi-IDE BOOTSTRAP (incl. Go module Dir resolve) |
| `skills/image-to-webp/` | Portable PNG/HEIC→WebP via cwebp; ask/install tools only after user agrees |
| `skills/process-compose-docker/` | Process-compose + Docker sidecars: timed preflight, confirm on daemon down, never wipe volumes on down |
| `skills/golang-quality/` | Generation/completion constraints + quality gates; `reference.md` encyclopedia |
| `skills/review-code-staged/` | Staged Go review (mechanical 1–5 / consultant A–C; Stage 5 = generation gates) |
| `skills/setup-goreleaser/` | Scaffold GoReleaser v2 + GitHub Release workflow |
| `skills/setup-go-binary-license/` | Signed `license.lic` Gate for a shipped Go CLI/daemon (`-tags release`) |
| `skills/manage-go-releases/` | Auto-patch / skip docs-chore / pin consumers to `v*` (agent release practice) |
| `skills/dspy-xml-structured-output/` | Generic XML parser + mandatory-field validation (strop paths) |
| `skills/dspy-go-debugging/` | Validation / retry / refinement failures |
| `skills/dspy-pipeline-isolation/` | Fixture + env-gated live replay per generator/evaluator (C17) |
| `skills/dspy-module-patterns/` | Module + interceptor wiring; `reference.md` dspy-go encyclopedia |
| `skills/dspy-prompt-engineering/` | Compact prompt contract; `reference.md` bias/CoT/templates |
| `skills/plan-scaffold/` | Implementation plan meta-framework |
| `skills/review-member-visibility/` | Export-only-what-is-essential audit |
| `skills/review-code-smells/` | Code smell / maintainability review protocol |
| `rules/golang.mdc` | Go + `go.mod`/`go.work` — load golang-quality / staged review; no module-skeleton rewrite |
| `rules/dspy.mdc` | Agent-decided — load thin dspy skills |
| `rules/strop.mdc` | Agent-decided — load strop skills (softlinked from the strop module `ai-copilots/`) |
| `rules/go-releases.mdc` | Agent-decided — load manage-go-releases for tags and consumer pins |
| `rules/go-binary-license.mdc` | `internal/license`, goreleaser, `cmd/**/main.go` — load setup-go-binary-license |
| `rules/cursor-packs.mdc` | Soft-link ownership — load edit-cursor-packs |
| `rules/agent-smith.mdc` | Authoring skills/rules — load agent-smith |
| `rules/ai-copilots.mdc` | Library `AGENTS.md` / `ai-copilots/**` — load author-ai-copilots |
| `rules/always-rules-0-ai.mdc` | Always-on model behavior: English identifiers, US spelling, no em dash, tmp clones |
| `rules/always-rules-01-human-interaction.mdc` | Always-on fluent consultant + light tutor voice, implement gate, Intent-First / Consultant loaders |
| `rules/image-to-webp.mdc` | `globs: **/*.{png,heic,heif}` — convert shipping rasters to WebP; load skill `image-to-webp` |
| `rules/process-compose-docker.mdc` | process-compose / pc-up / pc-down / docker-compose — load `process-compose-docker` |
| `personas/intent-first.persona.md` | Gated: confirm exploratory intent, then wait |
| `personas/consultant.persona.md` | Gated: present real forks, wait for a pick |

References (`reference.md`, `methodology.md`, …) live **inside** each skill folder.

## What stays in the consuming project

Keep as real files under `.cursor/skills/` / `.cursor/rules/`:

- **Product overlays** prefixed for the consumer (e.g. `pipelines-x-*` in content-pipelines): YouTube notes, PostGenerator hooks, classroom paths
- Thin always-rules for architecture / secrets / product skill names (not encyclopedias — those live in pack `reference.md`)
- Model-behavior and chat kernels (`always-rules-0`, `always-rules-01` + personas) are pack-owned. Keep a thin overlay for restyle exceptions, `content/` spelling, and named workflows.

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

## perplexity-browser

Research + MCP ops skills live in `github.com/behaviorengineering/perplexity-browser` (`ai-copilots/`). Host overlays stay under `.cursor/perplexity/`.

## strop consumers

Runtime and operator skills live in `github.com/behaviorengineering/strop` (`ai-copilots/skills/`). Wire host softlinks with that module's `ai-copilots/BOOTSTRAP.md` (or `go list -m -f '{{.Dir}}' github.com/behaviorengineering/strop`). This pack keeps `strop.mdc` as a thin loader and the cross-product `dspy-*` skills.

Load order for a new pipeline job:

1. `strop-pipeline-pattern` + `strop-orchestration` (from the strop module softlinks)
2. `dspy-prompt-engineering` + `dspy-xml-structured-output` (this pack)
3. Project overlay (if any)

## Link script behavior

- Creates relative links: `.cursor/skills/golang-quality` → `../packs/shared/skills/golang-quality`, and the same pattern for rules and personas
- Updates existing symlinks
- **Skips** paths that already exist as real files/directories (protects local overlays)
- Allow-lists are `SKILLS`, `RULES`, `PERSONAS` only. **Never** links or overwrites `.cursor/perplexity/`
