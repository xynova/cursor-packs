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

**CONSTRAINT:** MUST ship or verify root `lefthook.yml` that extends the packs submodule:

```yaml
extends:
  - .cursor/packs/shared/lefthook/lefthook.yml
```

- Enforcement: file exists and lists the extends path
- Violation: STOP, create thin file from `lefthook/README.md`

**CONSTRAINT:** MUST initialize packs before extends resolve: `git submodule update --init --recursive` when `.cursor/packs/shared` is a gitlink.

- Enforcement: `test -f .cursor/packs/shared/lefthook/lefthook.yml`
- Violation: STOP, submodule update, retry

**CONSTRAINT:** MUST install Lefthook and register hooks once per clone or worktree.

- MUST: `command -v lefthook` OR install (macOS: `brew install lefthook`; else: `go install github.com/evilmartians/lefthook@latest` with `$(go env GOPATH)/bin` on PATH)
- MUST: `make hooks-install` or `lefthook install` from repo root
- Enforcement: pre-commit hook present under `.git/hooks` or Lefthook-managed equivalent
- Violation: STOP, install binary, run install, verify

**CONSTRAINT:** MUST wire ai-copilots per host `ai-copilots/BOOTSTRAP.md` (wire-only). MUST verify documented `.cursor/skills/<name>/SKILL.md` paths exist.

- MUST NOT re-author the harness in this skill
- Full baseline audit: load `ai-readiness`
- Violation: STOP, run BOOTSTRAP wire commands, re-verify paths

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

- [ ] Root `lefthook.yml` extends packs shared config
- [ ] `lefthook install` succeeded in this tree
- [ ] BOOTSTRAP skill symlinks resolve
- [ ] Packs submodule on a `v*` tag when pre-push pin check applies
