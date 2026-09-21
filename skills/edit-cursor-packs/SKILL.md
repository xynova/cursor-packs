---
name: edit-cursor-packs
description: >-
  Edit shared Cursor skills, rules, and personas that live in the
  xynova/cursor-packs submodule and are soft-linked into consumer .cursor/
  trees. Use when changing files under .cursor/skills, .cursor/rules, or
  .cursor/personas that symlink to packs/shared, when updating golang-quality
  or other pack content, or when an agent would otherwise commit pack edits
  into the wrong repo.
---

# Edit linked cursor-packs

Shared pack content is owned by **https://github.com/xynova/cursor-packs**, mounted at `.cursor/packs/shared`, and exposed via relative symlinks (for example `.cursor/skills/golang-quality` → `../packs/shared/skills/golang-quality`).

## Detect ownership (do this first)

Before editing any path under `.cursor/skills/`, `.cursor/rules/`, or `.cursor/personas/`:

1. `readlink` / `ls -la` the path.
2. If it is a **symlink** into `packs/shared/`, it is **pack-owned**.
3. If it is a **real directory or file**, it is a **consumer overlay** (edit in the consumer repo).

## Pack membership gate (ask before creating)

**CONSTRAINT:** Before creating or expanding any skill, rule, or persona in **cursor-packs**, MUST pass the membership gate in `.cursor/rules/cursor-packs.mdc` (same questions live there).

Ask yourself:

1. Would **every** cursor-packs consumer need this even if they never depend on one named library or host product?
2. Is this operator knowledge for **one** Go module or CLI?
3. Is this one host's brand, private layout, or product-only workflow?

- Pass → only when (1) is yes and (2)/(3) are no.
- If (2) is yes → library `ai-copilots/` + host link (see `author-ai-copilots`). MUST NOT add it to the pack.
- If (3) is yes → consumer overlay under that host's `.cursor/`.
- Enforcement: Answer the three questions in chat or the PR body before the first new pack path.
- Violation: STOP, move the content to `ai-copilots` or the host; do not merge pack spill.

CORRECT:
```text
Shared Go quality / dspy-go debugging / pack link script → pack
```

PROHIBITED:
```text
Typology (or any single-library) slice vocabulary rule → cursor-packs/rules/
```

## Pack-owned edits (MUST)

1. MUST work inside the pack git checkout: `.cursor/packs/shared` (or the resolved real path).
2. MUST NOT commit pack file bytes as ordinary files of the consumer repo.
3. MUST leave detached HEAD: `git fetch origin && git checkout -B <branch> origin/main` inside the pack checkout.
4. MUST commit and push on **cursor-packs**, then open/update a PR there when the user wants review.
5. MUST bump the consumer submodule pointer to the new pack SHA after the pack change lands (or to the PR tip for pilot).
6. MUST re-run `.cursor/packs/shared/scripts/link-into-project.sh --project .` when new skill, rule, or persona **names** are added to the pack allow-lists.
7. MUST load this skill whenever the soft-linked rule `cursor-packs.mdc` fires.
8. MUST run the **Pack membership gate** before any new pack skill, rule, or persona name.

## Consumer overlays (MUST NOT confuse)

- Product/pipeline skills and fat invariant rules stay as **real** files under the consumer `.cursor/`.
- The link script **skips** existing non-symlink paths (protects overlays).
- MUST NOT replace an overlay with a pack symlink unless the user explicitly asks.

## Typical sequence

```bash
# 1) Pack branch
cd .cursor/packs/shared
git fetch origin
git checkout -B feat/my-change origin/main
# edit skills/... or rules/... or personas/...
git add -A && git commit && git push -u origin HEAD

# 2) Consumer pin (after pack commit exists)
cd /path/to/consumer
git add .cursor/packs/shared
# if new names were added to scripts/link-into-project.sh:
.cursor/packs/shared/scripts/link-into-project.sh --project .
git add .cursor/skills .cursor/rules .cursor/personas   # new symlinks only
git commit
```

## Consumer pin: sync checkout after gitlink bump (MUST)

**CONSTRAINT:** After the consumer records a new `.cursor/packs/shared` gitlink (or any submodule pin), MUST sync the nested checkout to that SHA before treating the tree as clean or staging more submodule changes. Load and follow **`sync-submodules-after-merge`** (at least `git submodule update --init --recursive -- .cursor/packs/shared`).

- Enforcement: `git ls-files -s .cursor/packs/shared` SHA equals `git -C .cursor/packs/shared rev-parse HEAD`; `git status` has no `modified: .cursor/packs/shared (new commits)` from pin drift
- Violation: STOP, sync; do not declare the bump done while status shows submodule dirt

CORRECT:
```bash
# gitlink already committed (or staged) at v0.1.29 / desired SHA
git submodule update --init --recursive -- .cursor/packs/shared
git -C .cursor/packs/shared describe --tags --exact-match HEAD   # expected tag
git status   # no packs (new commits) dirt
```

PROHIBITED:
```bash
# Index pins v0.1.29 but checkout still on v0.1.17
git status   # "modified: .cursor/packs/shared (new commits)"
git add .cursor/packs/shared && git commit -m "commit all"
# → silently reverts the pin to the old checkout SHA
```

**CONSTRAINT:** MUST NOT `git add .cursor/packs/shared` (or commit “all”) to silence `(new commits)` dirt when the working-tree submodule HEAD is **behind** the recorded gitlink. That dirt means “run submodule update,” not “stage a new pin.”

- Enforcement: before `git add` on a submodule path, compare `git ls-files -s <path>` to `git -C <path> rev-parse HEAD`
- Violation: STOP, unstage; sync checkout to the gitlink

**CONSTRAINT:** If `git submodule update` fails with `Operation not permitted` (or cannot lock `.git/modules/.../config`) in a sandboxed agent environment, MUST stop and ask the human to run the sync in their own terminal. MUST NOT invent alternate checkouts that rewrite the submodule `gitdir` pointer, and MUST NOT stage the drifted checkout as a “fix.”

- Enforcement: agent reports the one-liner and waits
- Violation: STOP; do not ship a reverse pin or a broken `gitdir`

Human one-liner:
```bash
git submodule update --init --recursive -- .cursor/packs/shared
```

## Link script

Allow-lists live in `scripts/link-into-project.sh` (`SKILLS=(...)`, `RULES=(...)`, `PERSONAS=(...)`). New shared skills, rules, or personas MUST be appended there or consumers will not get symlinks. MUST NOT append a name that failed the membership gate.

## Pre-completion checklist

- [ ] **Ownership:** Edits are inside the pack git checkout, not committed as consumer file bytes
      Method: `git -C .cursor/packs/shared rev-parse --show-toplevel`
      Pass: toplevel is cursor-packs
      Fail: STOP, move work into the pack checkout
- [ ] **Membership gate:** New or expanded pack artifacts passed the three questions
      Method: Re-read answers in PR/chat; (1) yes, (2)/(3) no
      Pass: Portable shared practice only
      Fail: STOP, relocate to library `ai-copilots/` or host overlay
- [ ] **Allow-list:** New names appear in `scripts/link-into-project.sh` only after the gate passes
      Method: Diff the script
      Pass: Names match gated artifacts
      Fail: STOP, remove allow-list entry or relocate artifact
