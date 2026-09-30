---
name: after-merge
description: >-
  After a merge request lands, verify the merge is clean, then prune local
  branches and worktrees and sync submodules. Use when the user asks to merge,
  confirm a merge, or clean up stale branches after merge.
---

# After merge

Load only when the user asks to merge, confirms a merge landed, or wants post-merge cleanup. Not an always-on rule.

**Related:** `sync-submodules-after-merge`, `resolve-pr-merge-conflicts`, `manage-go-releases`.

This skill does **not** resolve open PR conflicts; it verifies a completed merge and cleans local state.

**Note:** Aligning a consumer submodule gitlink to upstream `main` after an upstream squash merge belongs in the **consumer pin bump** (`manage-go-releases`, same PR before open), not a second hygiene MR triggered from after-merge.

---

## When to load

- User asks to merge, confirm merge, or clean up after merge
- User says an MR/PR merged and wants branches or worktrees removed

---

## Core constraints

**CONSTRAINT:** MUST verify the merge went in clean **before** deleting branches or worktrees.

- MUST: MR/PR state is merged (or merge commit is on the base branch on the forge)
- MUST: CI/checks green or user explicitly accepted failures
- MUST: `git fetch`; base branch fast-forwards locally without conflict; no unmerged paths or `CONFLICT` markers
- Enforcement: `git status`, `git merge-base`, forge CLI (`gh pr view`, `glab mr view`) as available
- Violation: STOP, report what failed; do not delete branches

**CONSTRAINT:** After verify-clean, MUST run local hygiene in order:

1. Checkout or fast-forward the base branch (usually `main`)
2. `git fetch --prune`
3. Delete the merged **local** feature branch if it still exists
4. `git worktree list`; remove sibling worktree for that branch (`git worktree remove <path>`) when present
5. Load `sync-submodules-after-merge` and run recursive `git submodule update --init`

- MUST NOT delete remote branches here if forge already deletes source branch on merge
- Violation: STOP before destructive steps if verify-clean failed

CORRECT:
```text
Verify MR merged and main ff-clean
→ git checkout main && git pull --ff-only
→ git branch -d feat/foo
→ git worktree remove ../polypus-local--feat-foo
→ sync-submodules-after-merge
```

PROHIBITED:
```text
MR still open or checks failing
→ git branch -D feat/foo anyway
```

---

## Pre-completion verification

- [ ] Merge verified on forge and locally
- [ ] Merged local branch removed (or explained if retained)
- [ ] Matching worktree removed when used
- [ ] Submodule checkouts match gitlinks (`git status` clean for submodule paths)
