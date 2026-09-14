---
name: image-to-webp
description: >-
  Convert shipping raster images (PNG, HEIC/HEIF, and similar) to WebP with
  cwebp; install missing tools only after user agrees. Use when adding or
  editing .png/.heic/.heif rasters, WebP conversion, cwebp, sips, heif-convert,
  or image-to-webp rule work.
---

# Image to WebP

**Moral:** Shipping rasters ship as WebP. Missing tools are a stop, not a silent keep-PNG path.

**Rule:** `image-to-webp.mdc` (MUST convert). This skill is the portable runbook.

**Host overlays:** Product-specific CLIs (for example Consilium `evidence raster webp`) stay in the host skill when present. This skill covers the generic tool path.

---

## When to load

- Agent adds or updates a shipping `.png`, `.heic`, or `.heif`
- Rule `image-to-webp.mdc` loads
- `cwebp` / HEIC decode tools are missing
- User asks to convert images to WebP

---

## Tools

| Need | Tool | Typical install (macOS Homebrew) |
|------|------|----------------------------------|
| Encode WebP | `cwebp` (libwebp) | `brew install webp` |
| HEIC decode (macOS) | `sips` | Built into macOS |
| HEIC decode (Linux) | `heif-convert` | `brew install libheif` or distro `libheif-examples` |

JPEG/GIF sources MAY use `cwebp` directly when the user asks to convert them.

---

## Core constraints

**CONSTRAINT:** Before converting, MUST verify required tools are on `PATH`.

- MUST: `command -v cwebp` succeeds before any encode
- MUST: for `.heic` / `.heif`, `command -v sips` or `command -v heif-convert` succeeds before decode
- MUST NOT: silently leave the source raster in place because a tool is missing

Enforcement: run `command -v` checks; record missing tools  
Violation: STOP, run the install-ask flow below, re-verify

CORRECT:
```bash
command -v cwebp || echo "MISSING cwebp"
```

PROHIBITED:
```text
cwebp failed / not found → keep path.png and finish the task
```

**CONSTRAINT:** If a required tool is missing, MUST ask the user to install it. MUST NOT install without an explicit yes.

- MUST: name the missing tool(s) and one concrete install command for the detected OS
- MUST: wait for user agreement before running install
- MUST: after agreed install, re-check `PATH`, then convert
- MUST NOT: run `brew install` / `apt install` / similar unless the user agreed in this turn

Enforcement: chat shows ask → agreement → install → re-check before convert  
Violation: STOP, ask (or re-ask); do not convert or install unilaterally

CORRECT:
```markdown
cwebp is not on PATH. I can install it with `brew install webp` if you agree.
```

PROHIBITED:
```bash
# no user ask
brew install webp && cwebp …
```

**CONSTRAINT:** Conversion MUST use `cwebp` for the WebP encode step.

- MUST: PNG (and JPEG/GIF when converting) → `cwebp` (default quality 85 unless the host skill sets another preset)
- MUST: HEIC/HEIF → decode to a temp PNG via `sips` or `heif-convert`, then `cwebp`, then remove the temp PNG
- MUST: update references to the new `.webp` path in files touched for the change
- MUST: remove the original shipping raster after success unless the user asks to keep it
- MUST NOT: invent a second encoder as the default path

Enforcement: convert command uses `cwebp`; refs and source cleanup checked  
Violation: STOP, use `cwebp`, fix refs

CORRECT:
```bash
cwebp -q 85 in.png -o in.webp
# then update refs; rm in.png unless --keep-source / user asked to keep
```

PROHIBITED:
```bash
magick in.png in.webp   # not the default pack path
```

---

## Steps

1. **Classify** — confirm the file is a shipping raster (not `tmp/`, `node_modules/`, vendored scratch).
2. **Tool check** — `cwebp`; plus HEIC decoder when needed.
3. **Install ask** — if missing, ask; on yes, install; re-check.
4. **Decode** — HEIC/HEIF to temp PNG when required.
5. **Encode** — `cwebp -q 85 <in> -o <out.webp>` (or host preset).
6. **Refs** — update markdown/HTML/CSS/config/code strings that pointed at the old path.
7. **Cleanup** — remove source raster (and temp PNG) unless user asked to keep.
8. **Verify** — run the project's nearest build/check that loads the asset.

---

## Pre-completion checklist

- [ ] **Tools present:** `cwebp` (and HEIC decoder if needed) on PATH
      Method: `command -v`
      Pass: all required commands found
      Fail: STOP, ask to install (offer to run install on agreement)
- [ ] **WebP written:** `.webp` exists next to (or replacing) the source
      Method: file exists
      Pass: output present
      Fail: STOP, fix encode
- [ ] **Refs updated:** no stale `.png`/`.heic` refs in touched files for that asset
      Method: grep old basename in change set
      Pass: only `.webp` remains for that asset
      Fail: STOP, rewrite refs
- [ ] **Source removed:** original shipping raster gone unless user asked to keep
      Method: ls source path
      Pass: absent, or keep flag documented
      Fail: STOP, remove or confirm keep
