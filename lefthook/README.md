# Fleet Lefthook config (cursor-packs)

Shared git hooks for repositories that submodule cursor-packs at `.cursor/packs/shared`.

## cursor-packs as workspace root

When this repository is the git root (not a consumer submodule path):

1. `./scripts/ensure-lefthook-consumer.sh --project .` (extends `lefthook/lefthook-packs-root.yml`)
2. `make hooks-install`

Pre-push compares `HEAD` to the newest `v*` tag on this repo (same pin rule as consumers).

## Consumer setup

1. Root `lefthook.yml`:

```yaml
extends:
  - .cursor/packs/shared/lefthook/lefthook.yml
```

2. Install Lefthook once per clone or worktree: `make hooks-install` (or `lefthook install`).

3. Keep the packs submodule gitlink on a `v*` release tag. Pre-push fails if the checkout is not the newest `v*` on origin.

## Jobs

| Hook | Job | Behavior |
| --- | --- | --- |
| pre-commit | default-branch-refuse | Blocks commits on `main`, `master`, `develop`, `trunk` |
| pre-commit | go-format | Formats staged `*.go` with gofumpt or gofmt |
| pre-push | pins-are-latest-release | Packs submodule must be exact latest `v*` tag |

## Worktrees (parallel agents)

1. In the parent clone, sync submodules (`sync-submodules-after-merge` skill) before `git worktree add`.
2. Prefer sibling directories: `git worktree add ../<repo>--<slug> -b feat/<slug> <start>`.
3. In the new worktree: `git submodule update --init --recursive`, then `make hooks-install`, then ai-copilots BOOTSTRAP wire.

## Escape hatch (humans only)

`LEFTHOOK=0 git commit` or `git commit --no-verify` when a broken hook blocks an emergency change. Agents MUST NOT use this unless the user explicitly asks.

## Local overrides

Optional `lefthook-local.yml` at the repo root (gitignore it if needed). It overrides shared settings per Lefthook merge order.
