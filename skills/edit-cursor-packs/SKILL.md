---
name: edit-cursor-packs
description: >-
  Edit shared Cursor skills and rules that live in the xynova/cursor-packs
  submodule and are soft-linked into consumer .cursor/ trees. Use when changing
  files under .cursor/skills or .cursor/rules that symlink to packs/shared,
  when updating golang-quality or other pack content, or when an agent would
  otherwise commit pack edits into the wrong repo.
---

# Edit linked cursor-packs

Shared pack content is owned by **https://github.com/xynova/cursor-packs**, mounted at `.cursor/packs/shared`, and exposed via relative symlinks (for example `.cursor/skills/golang-quality` → `../packs/shared/skills/golang-quality`).

## Detect ownership (do this first)

Before editing any path under `.cursor/skills/` or `.cursor/rules/`:

1. `readlink` / `ls -la` the path.
2. If it is a **symlink** into `packs/shared/`, it is **pack-owned**.
3. If it is a **real directory or file**, it is a **consumer overlay** (edit in the consumer repo).

## Pack-owned edits (MUST)

1. MUST work inside the pack git checkout: `.cursor/packs/shared` (or the resolved real path).
2. MUST NOT commit pack file bytes as ordinary files of the consumer repo.
3. MUST leave detached HEAD: `git fetch origin && git checkout -B <branch> origin/main` inside the pack checkout.
4. MUST commit and push on **cursor-packs**, then open/update a PR there when the user wants review.
5. MUST bump the consumer submodule pointer to the new pack SHA after the pack change lands (or to the PR tip for pilot).
6. MUST re-run `.cursor/packs/shared/scripts/link-into-project.sh --project .` when new skill/rule **names** are added to the pack allow-lists.
7. MUST load this skill whenever the soft-linked rule `cursor-packs.mdc` fires.

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
# edit skills/... or rules/...
git add -A && git commit && git push -u origin HEAD

# 2) Consumer pin (after pack commit exists)
cd /path/to/consumer
git add .cursor/packs/shared
# if new names were added to scripts/link-into-project.sh:
.cursor/packs/shared/scripts/link-into-project.sh --project .
git add .cursor/skills .cursor/rules   # new symlinks only
git commit
```

## Link script

Allow-lists live in `scripts/link-into-project.sh` (`SKILLS=(...)`, `RULES=(...)`). New shared skills/rules MUST be appended there or consumers will not get symlinks.
