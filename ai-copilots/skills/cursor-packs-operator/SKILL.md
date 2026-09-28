---
name: cursor-packs-operator
description: >-
  Operate the cursor-packs repository: link skills into .cursor, edit pack
  content on a feature branch, Lefthook consumer setup, and release tags.
  Use when the workspace is the cursor-packs git root or when editing
  .cursor/packs/shared in a consumer.
---

# cursor-packs operator

**Moral:** Pack bytes live in the cursor-packs git repository. Consumers submodule and symlink; agents MUST NOT commit pack file content as ordinary host files.

## Start every task

1. Confirm workspace toplevel: `git rev-parse --show-toplevel` (cursor-packs repo when editing the pack).
2. If editing pack files: load `edit-cursor-packs` and work on a non-default feature branch from `origin/main`.
3. If setting up a **consumer** host: submodule init, `link-into-project.sh`, `ensure-lefthook-consumer.sh`, `install-repo-hooks`.

## Consumer setup (host repo)

| Step | Action |
|------|--------|
| Submodule | `git submodule update --init --recursive` for `.cursor/packs/shared` |
| Symlinks | `.cursor/packs/shared/scripts/link-into-project.sh --project .` |
| Lefthook thin file | `.cursor/packs/shared/scripts/ensure-lefthook-consumer.sh --project .` |
| Install hooks | `make hooks-install` or `lefthook install`; verify via `install-repo-hooks` |
| Host harness | Host `AGENTS.md` + `ai-copilots/BOOTSTRAP.md` (not duplicated in the pack) |

Details: [lefthook/README.md](../../lefthook/README.md), [README.md](../../README.md).

## Release and pins

- Merge to `main` triggers patch tags per `manage-go-releases`
- Consumers pin submodule to `v*`; pre-push hook requires newest tag when Lefthook is installed

## Pre-completion verification

- [ ] Pack edits committed in cursor-packs, not the host
- [ ] New skill names added to `link-into-project.sh` when applicable
- [ ] Consumer bump is submodule pointer only after pack tag exists
