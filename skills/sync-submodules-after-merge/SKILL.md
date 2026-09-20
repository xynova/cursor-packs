---
name: sync-submodules-after-merge
description: >-
  After a PR merge, checkout of main, or submodule pin bump, recursively
  initialize and update git submodules so nested checkouts match recorded
  gitlinks and clear false "modified (new commits)" dirt. Use when submodules
  look dirty after merge, recursive submodule update, nested packs inside
  majordomo, or gitlink mismatch after pin.
---

# Sync submodules after merge

Load this skill when the parent repo's recorded submodule SHAs changed (or the agent switched onto a tip that already changed them), and the working tree still has nested checkouts on other commits. Done means every listed submodule (and nested submodule) matches its gitlink, and `git status` no longer reports `modified: <path> (new commits)` for those paths.

This skill does **not** own merge-conflict resolution (`resolve-pr-merge-conflicts`) or release tagging (`manage-go-releases`). It only aligns checkouts to already-recorded gitlinks.

---

## When to load

- A PR that touched submodule gitlinks just merged (or the agent is told it merged)
- Agent checks out or fast-forwards `main` / the merge tip after such a PR
- Consumer pin bump of `.cursor/packs/shared`, `.majordomo`, `providers/*`, or similar
- `git status` shows `modified: <submodule> (new commits)` right after merge or branch switch
- Nested case: parent is clean for the outer gitlink, but inside `.majordomo` (or another nest) packs still sit on a different SHA

---

## Core constraints

**CONSTRAINT:** After merge, checkout of the merge tip, or a committed pin bump, MUST run a recursive submodule sync so every nest matches the gitlink recorded by its parent.

- MUST: from the repo root that owns the gitlinks, `git submodule update --init --recursive`
- MUST: if a nest has its own `.gitmodules` and still shows `(new commits)` after the root recursive update, `git -C <nest> submodule update --init --recursive`
- MUST NOT: leave packs / nested modules on a newer tip while claiming the parent branch is clean

Enforcement: for each submodule path in `git submodule status`, the checked-out SHA equals the gitlink in `HEAD`
Violation: STOP, re-run update on the failing nest, re-verify

CORRECT:
```bash
git fetch origin
git checkout main && git pull --ff-only origin main
git submodule update --init --recursive
git submodule status   # no leading + / - on expected pins
```

PROHIBITED:
```bash
# Merge landed; keep working on whatever packs tip was checked out mid-feature
git checkout main
git status   # still "modified: .majordomo (new commits)" — ignore it
```

**CONSTRAINT:** MUST NOT commit submodule gitlink changes as part of this sync. Sync only moves checkouts to what `HEAD` already records.

- MUST: after sync, `git status` has no staged/unstaged gitlink bumps unless the user asked to pin a new SHA
- MUST NOT: `git add .majordomo` / `git add .cursor/packs/shared` merely to silence dirt from a drifted checkout
- MUST NOT: treat `(new commits)` after a **pin bump** as “commit all”; that dirt is usually a **stale checkout behind the new gitlink**. Staging it reverts the pin. See **`edit-cursor-packs`** → **Consumer pin: sync checkout after gitlink bump**.

Enforcement: `git diff --submodule` / `git status` show no intentional pin commit from this skill; before any `git add <submodule>`, compare `git ls-files -s <path>` to `git -C <path> rev-parse HEAD`
Violation: STOP, unstage; reset checkouts with `git submodule update` instead

CORRECT:
```bash
git submodule update --init --recursive
# working tree clean (or only unrelated user files)
```

PROHIBITED:
```bash
git add .majordomo .cursor/packs/shared
git commit -m "sync submodules"
```

**CONSTRAINT:** If `git submodule update` fails with `Operation not permitted` / cannot lock `.git/modules/.../config` (common in sandboxed agents), MUST stop and ask the human to run the sync in their terminal. MUST NOT rewrite the submodule `gitdir` pointer or stage the drifted checkout as a workaround.

- Enforcement: agent surfaces the one-liner and waits when module-config locks fail
- Violation: STOP; do not ship a reverse pin

Human one-liner (path as needed):
```bash
git submodule update --init --recursive
# or: git submodule update --init --recursive -- .cursor/packs/shared
```

**CONSTRAINT:** Untracked content inside a nest (for example old `logs/`) is a separate problem. MUST report it; MUST NOT delete it unless the user explicitly asks.

- MUST: if status still shows `untracked content` / `modified content` inside a submodule after SHA alignment, name the paths
- MUST NOT: `git clean -fdx` inside nests as part of this skill

Enforcement: post-sync status scan lists leftover nest dirt without removing it
Violation: STOP if destructive clean was used; restore from backup only if the user requests

**CONSTRAINT:** Mid-feature nested work is allowed to look dirty. MUST NOT force sync while the user is intentionally on a feature tip inside a submodule that the parent has not pinned yet.

- MUST: run this skill after merge / switch to the aligned parent tip, or when the user asks to clear false dirt
- MUST NOT: reset a submodule feature branch checkout without asking when that nest is the active work

Enforcement: confirm HEAD of parent is the merge tip or user asked to sync; do not reset an in-progress nest branch blindly
Violation: STOP, ask before moving an active nest branch

---

## Steps

1. **Identify parent tip** — Confirm which commit owns the gitlinks (`main` after merge, or the pin-bump commit). Fetch and check out that tip if the user asked to land on it.

2. **Recursive update** — From that parent root:
   ```bash
   git submodule update --init --recursive
   ```

3. **Verify outer status** — `git submodule status` and `git status`. Pass when no `(new commits)` on submodule paths. Fail: re-run update for the failing path: `git submodule update --init --recursive -- <path>`.

4. **Verify nested packs / nests** — For each nest that contains `.gitmodules` (commonly `.majordomo`):
   ```bash
   git -C <nest> submodule update --init --recursive
   git -C <nest> status -sb
   ```
   Pass when the nest's recorded packs (or other) gitlinks match checkouts.

5. **Report leftovers** — If a nest still has `modified content` or `??` untracked paths, list them. Do not delete. Point at ignore / dump-path skills only if relevant; do not expand scope.

6. **Optional branch hygiene** — If the merged feature branch was deleted on the remote, say so. Switching to `main` is a separate checkout step, not part of submodule sync.

---

## Safety (NEVER)

- NEVER force-push or rewrite history to “fix” submodule dirt
- NEVER commit accidental gitlink bumps from a drifted checkout
- NEVER `git clean -fdx` nests without an explicit user ask
- NEVER reset an in-progress submodule feature branch without asking

---

## Pre-completion checklist

- [ ] **Parent tip known:** merge tip / main / pin commit identified
      Method: `git rev-parse HEAD` and recent merge context
      Pass: agent is on the tip that owns the desired gitlinks
      Fail: STOP, checkout the tip first
- [ ] **Recursive update ran:** `--init --recursive` from parent
      Method: command present in the session
      Pass: ran successfully
      Fail: STOP, fix errors (missing URL, auth) then retry
- [ ] **No `(new commits)` dirt:** outer submodule SHAs match gitlinks
      Method: `git status` / `git submodule status`
      Pass: clean for submodule paths (or only unrelated files)
      Fail: STOP, update the failing path again
- [ ] **Nests synced:** nested `.gitmodules` checkouts match
      Method: `git -C <nest> submodule status`
      Pass: no leading `+` on expected pins
      Fail: STOP, nested `submodule update`
- [ ] **No accidental pin commit:** sync did not stage gitlinks
      Method: `git diff --cached --submodule`
      Pass: empty
      Fail: STOP, unstage
- [ ] **Leftovers reported:** untracked/modified content inside nests named or confirmed absent
      Method: nest `git status -sb`
      Pass: reported or clean
      Fail: STOP, inspect before claiming done
