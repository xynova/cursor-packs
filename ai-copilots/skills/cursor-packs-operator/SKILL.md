---
name: cursor-packs-operator
description: >-
  Operate the cursor-packs repository: Cursor plugin manifests, edit pack
  content on a feature branch, Lefthook consumer setup, and release tags.
  Use when the workspace is the cursor-packs git root or when editing
  .cursor/packs/shared in a consumer.
---

# cursor-packs operator

**Moral:** Pack bytes live in the cursor-packs git repository. Cursor users install the **cursor-packs** plugin; legacy consumers may submodule and symlink. Agents MUST NOT commit pack file content as ordinary host files.

## Start every task

1. Confirm workspace toplevel: `git rev-parse --show-toplevel` (cursor-packs repo when editing the pack).
2. If editing pack files: load `edit-cursor-packs` and work on a non-default feature branch from `origin/main`.
3. If setting up a **consumer** host: see [docs/PLUGIN.md](../../docs/PLUGIN.md) (plugin) or submodule + link script (Lefthook/CI legacy).

## Consumer setup (host repo)

| Mode | Cursor discovery | Git / hooks |
|------|------------------|-------------|
| **Plugin (recommended)** | Install `cursor-packs` from marketplace or `~/.cursor/plugins/local/cursor-packs`; run `unlink-pack-cursor-components.sh` after install | Optional submodule for Lefthook/CI scripts only |
| **Legacy symlink** | `link-into-project.sh --project .` | Submodule at `.cursor/packs/shared`, `ensure-lefthook-consumer.sh`, wired-gitignore manifest + `sync-wired-cursor-gitignore.sh`, `task` / `go tool task` / `make hooks-install` per host; verify via `install-repo-hooks` |
| **Both** | Plugin for pack skills; submodule with `--skip-cursor-components` for hooks/scripts | Host `AGENTS.md` + `ai-copilots/BOOTSTRAP.md` (not duplicated in the pack) |

Details: [lefthook/README.md](../../lefthook/README.md), [README.md](../../README.md), [docs/PLUGIN.md](../../docs/PLUGIN.md).

## Release and pins

- Merge to `main` triggers patch tags per `manage-go-releases`
- **Plugin consumers:** refresh Cursor (pull / marketplace Auto Refresh); no fleet gitlink bump for skills
- **Legacy submodule consumers:** pin to `v*` when Lefthook pre-push still applies; plugin-era hosts use `unlink-pack-cursor-components.sh` to skip latest-tag pin for skills-only releases

## Pre-completion verification

- [ ] Pack edits committed in cursor-packs, not the host
- [ ] New skill names added to `scripts/pack-cursor-allowlists.sh` when applicable
- [ ] Consumer bump is submodule pointer only when Lefthook/CI scripts changed (not for plugin-only skill updates)
