---
name: install-repo-hooks
description: >-
  Verify and install fleet Lefthook git hooks, ai-copilots BOOTSTRAP wire, and
  worktree setup (submodules, hooks-install). Use before the first git commit
  in a clone or worktree, when hooks-install is missing, or when setting up a
  new parallel-agent worktree.
---

# Install repo hooks

One-time (per clone or worktree) setup: Lefthook + ai-copilots wire. Commit-time enforcement lives in cursor-packs `lefthook/`. Pin freshness runs on pre-push.

Operate-time **wire-if-missing** (before reading skills in a workspace without IDE discovery links) is owned by `AGENTS.md` and [author-ai-copilots](../author-ai-copilots/SKILL.md); it is not a substitute for this skill before the first commit.

**Related:** `sync-submodules-after-merge`, `ai-readiness`, `manage-go-releases`, `lefthook/README.md` in the packs submodule.

---

## When to load

- Before the first `git commit` in a clone or new worktree
- User asks to install hooks, `hooks-install`, or wire ai-copilots
- After `git worktree add` (submodules + hooks + wire in the new tree)
- always-rules points here when setup is not verified

---

## Core constraints

**CONSTRAINT:** MUST run from the host repository root (`git rev-parse --show-toplevel`).

- Enforcement: `pwd` matches toplevel before install steps
- Violation: STOP, `cd` to toplevel, restart checklist

**CONSTRAINT:** MUST ship or verify root `lefthook.yml` for one of two consumer modes:

**Packs consumer** (umbrella host, Consilium, any repo with `.cursor/packs/shared`):

```yaml
extends:
  - .cursor/packs/shared/lefthook/lefthook.yml
```

**Standalone Go module** (portable provider; no packs submodule):

```yaml
extends:
  - lefthook/lefthook-go-standalone.yml
```

Scripts live under `scripts/git-hooks/`. Scaffold with `./scripts/ensure-go-standalone-lefthook.sh --project .` from a cursor-packs checkout, or copy `prepare-go-forge` templates.

- Enforcement: file exists and lists a valid extends path; standalone repos have `scripts/git-hooks/*.sh`
- Violation: STOP, create files from `lefthook/README.md` or `ensure-go-standalone-lefthook.sh`

**CONSTRAINT:** When using the packs consumer mode, MUST initialize packs before extends resolve: `git submodule update --init --recursive` when `.cursor/packs/shared` is a gitlink.

- Enforcement: `test -f .cursor/packs/shared/lefthook/lefthook.yml`
- Violation: STOP, submodule update, retry

Standalone mode MUST NOT require a packs submodule; skip this step when `lefthook/lefthook-go-standalone.yml` is the extends target.

**CONSTRAINT:** MUST install Lefthook and register hooks once per clone or worktree.

- MUST: `command -v lefthook` OR install (macOS: `brew install lefthook`; else: `go install github.com/evilmartians/lefthook@latest` with `$(go env GOPATH)/bin` on PATH)
- MUST: `make hooks-install` or `lefthook install` from repo root
- Enforcement: pre-commit hook present under `.git/hooks` or Lefthook-managed equivalent
- Violation: STOP, install binary, run install, verify

**CONSTRAINT:** MUST wire ai-copilots per host `ai-copilots/BOOTSTRAP.md` (wire-only). MUST verify documented `.cursor/skills/<name>/SKILL.md` paths exist.

- MUST NOT re-author the harness in this skill
- Full baseline audit: load `ai-readiness`
- Violation: STOP, run BOOTSTRAP wire commands, re-verify paths

**CONSTRAINT:** After wire, MUST NOT confuse **pack pins** with **local skill links**. Pack content is pinned only via `.cursor/packs/shared` gitlink. Go-module wired skills under `.cursor/skills/` (from `go list -m` + `ln -snf`) MUST be gitignored when BOOTSTRAP says they are not committed; `??` on those paths is expected until gitignore is present.

- Enforcement: `author-ai-copilots` reference "Host workspace: three Cursor skill sources"
- Violation: STOP; run `make wire-cursor-skills` (or BOOTSTRAP), add gitignore names from BOOTSTRAP, do not commit module-cache symlinks

**CONSTRAINT:** Before `git worktree add`, MUST load `sync-submodules-after-merge` in the **parent** clone so gitlinks match HEAD.

- Violation: STOP, sync parent, then add worktree

**CONSTRAINT:** After `git worktree add`, MUST in the **new** tree: submodule update recursive, this checklist (hooks + wire).

---

## Worktree convention (summary)

- Sibling path: `../<repo>--<slug>` (not `.worktrees/` inside the repo by default)
- Parent: sync submodules first
- New tree: submodules, `make hooks-install`, BOOTSTRAP wire

---

## Pre-completion verification

- [ ] Root `lefthook.yml` extends packs shared config or standalone `lefthook-go-standalone.yml`
- [ ] `lefthook install` succeeded in this tree
- [ ] BOOTSTRAP skill symlinks resolve
- [ ] Go-module wired skill names gitignored when BOOTSTRAP marks them wire-only (status clean after wire)
- [ ] Packs submodule on a `v*` tag when pre-push pin check applies
