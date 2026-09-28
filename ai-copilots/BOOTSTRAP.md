# BOOTSTRAP — cursor-packs ai-copilots

**Audience:** Agents working in the cursor-packs git checkout (repo root, not a consumer submodule path).

## Wire this repo (Cursor)

When this repository is the workspace root, link pack skills into `.cursor/`:

```bash
REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"
./scripts/link-into-project.sh --project .
```

## Lefthook in this checkout

This repo ships `lefthook/` for consumers. To run the same hooks when committing **in cursor-packs**:

```bash
./scripts/ensure-lefthook-consumer.sh --project .
# Add Makefile hooks-install or: command -v lefthook && lefthook install
```

Run `./scripts/ensure-lefthook-consumer.sh --project .` then install hooks. The script picks `./lefthook/lefthook.yml` when this repo is the root, or the consumer submodule path otherwise.

## After new skill or rule names

1. Add names to `scripts/link-into-project.sh` allow-lists
2. Re-run `link-into-project.sh` in this repo and in consumers after bump
