# BOOTSTRAP — cursor-packs ai-copilots

**Audience:** Agents working in the cursor-packs git checkout (repo root, not a consumer submodule path).

## Cursor plugin (this checkout)

This repository is a **Cursor Plugin** (`.cursor-plugin/plugin.json`). When developing locally, clone to `~/.cursor/plugins/local/cursor-packs` (real directory; external symlinks are rejected). After edits: **Developer: Reload Window** and start a new Agent conversation.

Do **not** run `link-into-project.sh --project .` in this checkout for discovery; the plugin loader reads repo-root `skills/`, `rules/`, and `agents/` directly.

See [docs/PLUGIN.md](../docs/PLUGIN.md).

## Lefthook in this checkout

```bash
./scripts/ensure-lefthook-consumer.sh --project .
make hooks-install
```

The ensure script writes root `lefthook.yml` extending `lefthook/lefthook-packs-root.yml`. Consumers extend `.cursor/packs/shared/lefthook/lefthook.yml` instead.

## After new skill or rule names

1. Add names to `scripts/pack-cursor-allowlists.sh`
2. Legacy submodule consumers: re-run `link-into-project.sh --project .` (plugin consumers: refresh plugin only)
