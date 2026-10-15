# cursor-packs

Shared Cursor **skills**, short **rules**, gated **personas**, and **subagents** for fleet Go hosts.

Repo: https://github.com/xynova/cursor-packs

## Cursor plugin (recommended)

Install as a **Cursor Plugin** (`cursor-packs`). Manifests: `.cursor-plugin/plugin.json`, `.cursor-plugin/marketplace.json`.

| Channel | How updates arrive |
|---------|-------------------|
| **Local maintain** | Clone to `~/.cursor/plugins/local/cursor-packs`, `git pull`, **Developer: Reload Window**, new Agent chat |
| **Team marketplace** | Import this repo, **Auto Refresh** on `main`, install plugin (user or Required scope) |

Full runbook: [docs/PLUGIN.md](docs/PLUGIN.md).

Do **not** keep pack-named `.cursor/skills|rules|agents` symlinks **and** the plugin (duplicate skills and always-on rules). Use `scripts/unlink-pack-cursor-components.sh` after plugin install.

Host **ai-copilots** and Go-module BOOTSTRAP links under `.cursor/skills/` stay as they are.

## Legacy submodule (Lefthook / CI / non-Cursor IDEs)

Mount path in consumers: `.cursor/packs/shared`

```bash
git submodule add https://github.com/xynova/cursor-packs.git .cursor/packs/shared
git submodule update --init --recursive
.cursor/packs/shared/scripts/link-into-project.sh --project .
.cursor/packs/shared/scripts/ensure-lefthook-consumer.sh --project .
make hooks-install
```

Plugin + submodule for hooks only:

```bash
.cursor/packs/shared/scripts/link-into-project.sh --project . --skip-cursor-components
```

Allow-lists: `scripts/pack-cursor-allowlists.sh`.

## What is in the pack

| Path | Purpose |
|------|---------|
| `skills/edit-cursor-packs/` | Branch/commit shared pack edits (not the consumer repo) |
| `skills/agent-smith/` | Author/review Cursor skills and rules (Agent Smith standards) |
| `skills/author-ai-copilots/` | Library-owned `ai-copilots/` harness + multi-IDE BOOTSTRAP (incl. Go module Dir resolve) |
| `skills/ai-readiness/` | Audit/scaffold required `AGENTS.md` + `ai-copilots/` baseline for every repo |
| `skills/intent-first/`, `skills/consultant/`, `skills/ai-readiness-persona/` | Gated chat kernels (plugin); `personas/*.persona.md` stubs for legacy symlinks |
| `skills/image-to-webp/` | Portable PNG/HEIC→WebP via cwebp; ask/install tools only after user agrees |
| `skills/process-compose-docker/` | Process-compose + Docker sidecars |
| `skills/golang-quality/` | Generation/completion constraints + quality gates; `reference.md` encyclopedia |
| `skills/review-code-staged/` | Staged Go review (mechanical 1–5 / consultant A–C; Stage 5 = generation gates) |
| `skills/setup-goreleaser/` | Scaffold GoReleaser v2 + GitHub Release workflow |
| `skills/setup-go-binary-license/` | Signed `license.lic` Gate for a shipped Go CLI/daemon (`-tags release`) |
| `skills/manage-go-releases/` | Auto-patch / skip docs-chore / pin consumers to `v*` (agent release practice) |
| `skills/dspy-*` | DSPy / strop-adjacent cross-product skills |
| `skills/plan-scaffold/` | Implementation plan meta-framework and executor stage contract |
| `agents/plan-auditor.md` | Subagent that scores plan stages and may patch plan markdown only |
| `lefthook/` | Shared Lefthook config (default-branch refuse, go format, pre-push packs pin when legacy-linked) |
| `AGENTS.md` + `ai-copilots/` | Operator harness when this repo is the workspace root |
| `rules/*.mdc` | Short Cursor rules (always-on kernel + loaders) |

References (`reference.md`, `methodology.md`, …) live **inside** each skill folder.

## What stays in the consuming project

Keep as real files under `.cursor/skills/` / `.cursor/rules/`:

- **Product overlays** prefixed for the consumer
- Thin always-rules for architecture / secrets / product skill names
- Host `ai-copilots` operator symlinks and Go-module wired skills (see `author-ai-copilots`)

The link script **skips** existing real directories — overlays are safe next to pack symlinks.

Agents: load `install-repo-hooks` before the first commit (Lefthook + host `ai-copilots` BOOTSTRAP wire).

### Legacy consumer wiring (full symlink discovery)

From the consumer repo root:

```bash
git submodule add https://github.com/xynova/cursor-packs.git .cursor/packs/shared
git submodule update --init --recursive
.cursor/packs/shared/scripts/link-into-project.sh --project .
.cursor/packs/shared/scripts/ensure-lefthook-consumer.sh --project .
cp .cursor/packs/shared/templates/wired-gitignore.manifest.example .cursor/wired-gitignore.manifest
# Edit .cursor/wired-gitignore.manifest for Go-module / BOOTSTRAP wires on this host.
.cursor/packs/shared/scripts/sync-wired-cursor-gitignore.sh --project .
task hooks-install | go tool task hooks-install | make hooks-install   # per host; or lefthook install
```

Commit `.gitmodules`, the submodule pointer, symlinks, `.cursor/wired-gitignore.manifest`, synced `.gitignore` block, and `lefthook.yml` when created.

### After clone (legacy)

```bash
git submodule update --init --recursive
.cursor/packs/shared/scripts/link-into-project.sh --project .
.cursor/packs/shared/scripts/ensure-lefthook-consumer.sh --project .
.cursor/packs/shared/scripts/sync-wired-cursor-gitignore.sh --project .
task hooks-install   # workspace umbrella; else go tool task or make per install-repo-hooks
```

(Re-run the link script when upgrading the pack and new skill names appear. Re-run sync when BOOTSTRAP adds wired paths; rule `cursor-wired-discovery`.)

### Operating cursor-packs as the workspace

Read [AGENTS.md](AGENTS.md), [ai-copilots/BOOTSTRAP.md](ai-copilots/BOOTSTRAP.md), [docs/PLUGIN.md](docs/PLUGIN.md), then `make hooks-install` after `ensure-lefthook-consumer.sh`.

## Versioning

Every merge to `main` creates the next patch tag (`v0.1.0`, then `v0.1.1`, …) and a GitHub Release.

- **Plugin consumers:** marketplace refresh or local `git pull`; no N-repo gitlink bump for skills.
- **Legacy submodule consumers:** bump `.cursor/packs/shared` when Lefthook/CI script bytes change, or when still using full symlink discovery and pre-push latest-tag pin applies.

```bash
cd .cursor/packs/shared
git fetch --tags origin
git checkout v0.1.0
cd ../../..
git add .cursor/packs/shared
git commit -m "Bump cursor-packs submodule for Lefthook/CI"
```

## perplexity-browser

Research + MCP ops skills live in `github.com/behaviorengineering/perplexity-browser` (`ai-copilots/`). Host overlays stay under `.cursor/perplexity/`.

## strop consumers

Runtime and operator skills live in `github.com/behaviorengineering/strop` (`ai-copilots/skills/`). Wire host softlinks with that module's `ai-copilots/BOOTSTRAP.md`. This pack keeps `strop.mdc` as a thin loader and the cross-product `dspy-*` skills.

Load order for a new pipeline job:

1. `strop-pipeline-pattern` + `strop-orchestration` (from the strop module softlinks)
2. `dspy-prompt-engineering` + `dspy-xml-structured-output` (this pack)
3. Project overlay (if any)

## Link script behavior

- Creates relative links: `.cursor/skills/golang-quality` → `../packs/shared/skills/golang-quality`, and the same pattern for rules, personas, agents
- `--skip-cursor-components` skips symlinks when the Cursor plugin supplies discovery
- `unlink-pack-cursor-components.sh` removes only symlinks into `packs/shared`
- **Skips** paths that already exist as real files/directories (protects local overlays)
- **Never** links or overwrites `.cursor/perplexity/`
