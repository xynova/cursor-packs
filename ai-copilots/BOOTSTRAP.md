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

This repo ships `lefthook/` for consumers. To run fleet hooks when committing **in cursor-packs**:

```bash
./scripts/ensure-lefthook-consumer.sh --project .
make hooks-install
```

The ensure script writes root `lefthook.yml` extending `lefthook/lefthook-packs-root.yml` (packs-as-root script paths). Consumers extend `.cursor/packs/shared/lefthook/lefthook.yml` instead.

## After new skill or rule names

1. Add names to `scripts/link-into-project.sh` allow-lists
2. Re-run `link-into-project.sh` in this repo and in consumers after bump
