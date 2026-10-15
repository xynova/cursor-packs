---
name: edit-cursor-packs
description: >-
  Edit shared Cursor skills, rules, personas, and subagents in the
  xynova/cursor-packs repository (Cursor plugin and/or submodule). Use when
  changing pack skills/rules/agents, consumer symlinks into packs/shared, or
  when an agent would otherwise commit pack edits into the wrong repo.
---

# Edit cursor-packs

Shared pack content is owned by **https://github.com/xynova/cursor-packs**.

**Cursor (primary):** install the `cursor-packs` plugin (local or team marketplace). Skills, rules, and agents refresh via `git pull` / marketplace Auto Refresh and **Developer: Reload Window**; start a new Agent conversation. No consumer gitlink bump for pack skills.

**Legacy / Lefthook / CI:** consumers may still submodule at `.cursor/packs/shared` for `lefthook/`, `scripts/auto-patch-decide.sh`, and symlink-based discovery. Plugin consumers MUST NOT dual-run pack-named `.cursor/` symlinks and the plugin.

## Detect ownership (do this first)

Before editing any path under `.cursor/skills/`, `.cursor/rules/`, `.cursor/personas/`, or `.cursor/agents/`:

1. `readlink` / `ls -la` the path.
2. If it is a **symlink** into `packs/shared/`, it is **pack-owned**.
3. If it is a **real directory or file**, it is a **consumer overlay** (edit in the consumer repo).

When the workspace is the **cursor-packs** git root (or `~/.cursor/plugins/local/cursor-packs`), edit repo-root `skills/`, `rules/`, `personas/`, `agents/` directly.

## Pack membership gate (ask before creating)

**CONSTRAINT:** Before creating or expanding any skill, rule, persona, or subagent in **cursor-packs**, MUST pass the membership gate in rule `cursor-packs` (same questions live there).

Ask yourself:

1. Would **every** cursor-packs consumer need this even if they never depend on one named library or host product?
2. Is this operator knowledge for **one** Go module or CLI?
3. Is this one host's brand, private layout, or product-only workflow?

- Pass → only when (1) is yes and (2)/(3) are no.
- If (2) is yes → library `ai-copilots/` + host link (see `author-ai-copilots`). MUST NOT add it to the pack.
- If (3) is yes → consumer overlay under that host's `.cursor/`.
- Enforcement: Answer the three questions in chat or the PR body before the first new pack path.
- Violation: STOP, move the content to `ai-copilots` or the host; do not merge pack spill.

## Pack-owned edits (MUST)

1. MUST work inside the **cursor-packs** git checkout (repo root, `.cursor/packs/shared` submodule path, or local plugin clone).
2. MUST NOT commit pack file bytes as ordinary files of the consumer repo.
3. MUST use a feature branch from `origin/main` when editing the pack.
4. MUST commit and push on **cursor-packs**, then open/update a PR there when the user wants review.
5. MUST NOT bump consumer submodule gitlinks for **Cursor skill/rule changes** when consumers use the plugin. Bump submodule only when Lefthook or CI script bytes in this repo change and the consumer still submodules.
6. MUST append new skill, rule, persona, or agent **names** to `scripts/pack-cursor-allowlists.sh` (legacy symlink consumers). Plugin discovery uses folder layout under `skills/`, `rules/`, `agents/`.
7. When consumers add BOOTSTRAP fire-and-forget wires, MUST point them at `.cursor/wired-gitignore.manifest` + `sync-wired-cursor-gitignore.sh` (rule `cursor-wired-discovery`), not ad hoc `.gitignore` lines.
8. MUST load this skill whenever rule `cursor-packs` fires.
9. MUST run the **Pack membership gate** before any new pack skill, rule, or persona name.

## Consumer overlays (MUST NOT confuse)

- Product/pipeline skills and fat invariant rules stay as **real** files under the consumer `.cursor/`.
- The link script **skips** existing non-symlink paths (protects overlays).
- MUST NOT replace an overlay with a pack symlink unless the user explicitly asks.
- Host **ai-copilots** operator symlinks and **Go-module** wired skills are not pack pins. See `author-ai-copilots` reference "Host workspace: three Cursor skill sources" before interpreting `?? .cursor/skills/*` as submodule drift.

## Typical sequence (pack PR)

```bash
cd /path/to/cursor-packs   # or ~/.cursor/plugins/local/cursor-packs
git fetch origin
git checkout -B feat/my-change origin/main
# edit skills/... rules/... agents/...
git add -A && git commit && git push -u origin HEAD
# merge → marketplace refresh or git pull + Reload Window in Cursor
```

## Legacy consumer submodule bump (Lefthook / CI only)

When the consumer still needs new `lefthook/` or `scripts/` bytes:

```bash
cd .cursor/packs/shared
git fetch --tags origin && git checkout vX.Y.Z
cd ../../..
git add .cursor/packs/shared
git commit -m "Bump cursor-packs submodule for Lefthook/CI scripts"
```

Load **`sync-submodules-after-merge`** after recording a new gitlink.

## Plugin cutover on a consumer

```bash
# After installing cursor-packs plugin in Customize:
.cursor/packs/shared/scripts/unlink-pack-cursor-components.sh --project .
```

Host `ai-copilots` and Go-module skill links stay. See [docs/PLUGIN.md](../../docs/PLUGIN.md).

## Pre-completion checklist

- [ ] **Ownership:** Edits are inside the cursor-packs checkout, not committed as consumer file bytes
- [ ] **Membership gate:** New or expanded pack artifacts passed the three questions
- [ ] **Allow-list:** New names appear in `scripts/pack-cursor-allowlists.sh` when legacy symlink consumers still exist
- [ ] **No dual-run:** Plugin consumers do not keep pack-named `.cursor/` symlinks alongside the plugin
