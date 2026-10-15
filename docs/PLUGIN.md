# Cursor plugin — cursor-packs

Fleet skills, rules, and agents ship as a **Cursor Plugin** (`name`: `cursor-packs`). Manifests: `.cursor-plugin/plugin.json`, `.cursor-plugin/marketplace.json`.

## Local development (maintain on this machine)

Cursor indexes a **real directory** under `~/.cursor/plugins/local/`. It does **not** load a symlink whose target is outside that folder.

```bash
git clone git@github.com:xynova/cursor-packs.git ~/.cursor/plugins/local/cursor-packs
# optional convenience:
# ln -s ~/.cursor/plugins/local/cursor-packs ~/path/you/use/today
```

Workflow:

1. Edit in that clone, PR to `github.com/xynova/cursor-packs`
2. `git pull` after merge
3. **Developer: Reload Window**
4. Start a **new Agent conversation** (active sessions keep old instructions)

**Name collision:** if the same plugin is installed from a team marketplace, that install **wins** over `~/.cursor/plugins/local/cursor-packs`. Disable the marketplace copy while iterating locally.

**Enterprise:** admins may disable **Allow Local Plugin Imports**; local folder discovery will not run until enabled.

## Team marketplace

1. Dashboard → Plugins & MCPs → import `https://github.com/xynova/cursor-packs`
2. Enable **Auto Refresh** on `main` (GitHub App; re-index at most every 10 minutes)
3. Install plugin `cursor-packs` (user scope for all workspaces, or team **Default On** / **Required**)
4. Manual refresh: Customize → Refresh, or `agent plugin marketplace update <marketplace-name>`

Optional: pin marketplace `--git-ref` to a `v*` tag for a single fleet gate (one pin, not N consumer repos).

## Consumer cutover (host repo)

Host **ai-copilots** and Go-module BOOTSTRAP links under `.cursor/skills/` are **unchanged**. Only remove pack-owned symlinks into `packs/shared`.

1. Install plugin `cursor-packs` in Customize
2. Reload Window; confirm skills/rules in Customize
3. From consumer root:

```bash
.cursor/packs/shared/scripts/unlink-pack-cursor-components.sh --project .
```

4. Do **not** dual-run pack symlinks and the plugin (duplicate always-on rules and skills)

**Submodule:** keep `.cursor/packs/shared` only if you need Lefthook `extends` or CI scripts (`auto-patch-decide.sh`). After unlink, Lefthook pre-push **skips** latest-tag pin checks for pack skills (see `lefthook/README.md`). Bump the gitlink when hook/script bytes change, not when `golang-quality` changes.

Legacy symlink setup (no plugin):

```bash
.cursor/packs/shared/scripts/link-into-project.sh --project .
```

Plugin + leftover submodule for hooks only:

```bash
.cursor/packs/shared/scripts/link-into-project.sh --project . --skip-cursor-components
```

## Cloud Agents

User-local plugins do not copy to Cloud Agents. Use a **team marketplace** install (Default On / Required) so cloud sessions see pack skills. Project `.cursor/skills` in git still travel with the clone (host copilots, overlays).

## Claude / Copilot / Codex

Cursor plugins are not visible to other IDEs. Those hosts still need files or their own `ai-copilots` BOOTSTRAP links.

## Import fallback

If Git import rejects `"source": "."` in `marketplace.json`, report it; do not duplicate the `skills/` tree. Canonical content stays at repo root per [README.md](../README.md).
