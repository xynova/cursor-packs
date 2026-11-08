---
name: upscale-image
description: >-
  Upscales a raster picture so it stays sharp on Retina and other high-density
  screens, with Real-ESRGAN (realesrgan-ncnn-vulkan) and ffmpeg: measures the
  width the page shows it at, skips pictures that are already big enough or
  that hold text, asks before installing a missing tool, upscales 4x with the
  realesrgan-x4plus and realesrgan-x4plus-anime models, compares crops of each
  against a plain stretch, scales the chosen one to twice the shown width, then
  hands it to image-to-webp. Use when a hero, banner or illustration looks soft
  or blurry on a Retina screen, when a page shows an image wider than its pixel
  width, or when the user asks to upscale, enlarge, sharpen or raise the
  resolution of an image, or mentions Real-ESRGAN, Upscayl or super-resolution.
---

# Upscale image

**Moral:** A browser that stretches a picture past its pixels makes it soft. Measure how big the page shows it, then give it twice those pixels from a model, not from a resize.

## When to load

- A picture looks soft or blurry on a Retina screen, or the user says so.
- A page shows an image wider, in CSS pixels times two, than the image's pixel width.
- The user asks to upscale, enlarge or sharpen an image, or names Real-ESRGAN, Upscayl or super-resolution.

The result ships through the `image-to-webp` skill, so load it for the encode.

## Tools

| Need | Tool | Typical install |
| --- | --- | --- |
| Upscale | `realesrgan-ncnn-vulkan`, with its `models/` folder beside it | The `realesrgan-ncnn-vulkan-<date>-macos.zip`, `-ubuntu.zip` or `-windows.zip` asset from github.com/xinntao/Real-ESRGAN/releases, unzipped and linked onto `PATH` |
| Resize and crop | `ffmpeg` | `brew install ffmpeg` (macOS), `apt install ffmpeg` (Debian, Ubuntu) |
| Encode WebP | `cwebp` | See skill `image-to-webp` |

The release ships these models in `models/`: `realesrgan-x4plus` (painted, shaded and photographic pictures), `realesrgan-x4plus-anime` (flat line art and cartoons), and `realesr-animevideov3` at x2, x3 and x4. On macOS, the first run of a downloaded binary needs `xattr -d com.apple.quarantine <binary>` after the user agrees.

## Core constraints

**CONSTRAINT:** MUST measure the width the page shows each picture at before upscaling, and MUST skip a picture whose source is already wide enough.

Complete this gate in working memory for each picture before running any upscale:

```text
Picture: [path]
Source width: [pixels, from sips -g pixelWidth or ffprobe]
Widest shown width: [CSS pixels, from the layout at the widest screen the site supports, or a screenshot measurement]
Needed width: [widest shown width x 2]
Decision: UPSCALE to [needed width, rounded to 2x the source when close] | SKIP (source >= needed)
```

- MUST take the widest shown width from the real layout: a CSS rule such as `width: 88%` at the widest screen, or a measurement from a screenshot.
- MUST NOT upscale a picture whose source is at least the needed width; say it is already sharp enough.
- Enforcement: the gate's numbers appear in the reply for each picture.
- Violation: STOP, measure, complete the gate, then continue.

CORRECT:

```text
Picture: media/hero.webp
Source width: 1632
Widest shown width: 1465 (88% of a 1665px window)
Needed width: 2930
Decision: UPSCALE to 3264
```

PROHIBITED:

```text
The image looks blurry, upscaling it 4x.
```

**CONSTRAINT:** MUST NOT upscale a picture that holds text, a user interface or a logo. Real-ESRGAN invents letter shapes and edges that were never there.

Complete this gate for each picture:

```text
Picture: [path]
Holds text, a UI screenshot or a logo: YES: [what] / NO
Decision: UPSCALE (NO) | RE-CAPTURE at 2x device scale (screenshot) | USE THE VECTOR (logo or diagram with an SVG source)
```

- MUST, for a screenshot, re-capture it at twice the device scale instead, such as Chrome's `--force-device-scale-factor=2`.
- MUST, for a logo or diagram with an SVG source, ship the SVG.
- Enforcement: each picture has a gate with a decision.
- Violation: STOP, discard the upscale, re-capture or use the vector.

**CONSTRAINT:** If `realesrgan-ncnn-vulkan`, its `models/` folder, `ffmpeg` or `cwebp` is missing, MUST ask before installing it. MUST NOT fall back to a plain resize in its place.

- MUST check with `command -v realesrgan-ncnn-vulkan ffmpeg cwebp`, and list the models folder beside the binary.
- MUST name the missing tool and the one install step for the detected OS, and wait for a yes.
- MUST NOT resize with `ffmpeg`, `sips` or `magick` alone and call it an upscale; a resize adds no detail.
- Enforcement: the chat shows the check, then the question and the yes before any install.
- Violation: STOP, ask; undo an unasked install if the user wants it gone.

CORRECT:

```markdown
`realesrgan-ncnn-vulkan` isn't installed. I can download the macOS release from github.com/xinntao/Real-ESRGAN/releases into `~/.local/share/realesrgan-ncnn-vulkan` and link it into `~/.local/bin`. Shall I?
```

PROHIBITED:

```bash
ffmpeg -i hero.png -vf scale=3264:-2 hero@2x.png   # a resize, sold as an upscale
```

**CONSTRAINT:** MUST pick the model by looking at crops, not by habit.

- MUST upscale 4x with both `realesrgan-x4plus` and `realesrgan-x4plus-anime`, then scale each to the needed width with `ffmpeg` and `flags=lanczos`.
- MUST crop the same detail region (a face, an eye, an edge) from a plain bicubic stretch and from both models, stack them side by side, and open that image to look at it.
- MUST state which model kept the original's shading, blur and texture, and choose it. `realesrgan-x4plus` usually wins on shaded or painted art; `realesrgan-x4plus-anime` on flat colour and clean lines.
- Enforcement: the comparison image was opened and looked at in this session, and the reply names the chosen model and why.
- Violation: STOP, build the comparison, look at it, choose again.

**CONSTRAINT:** MUST encode the chosen result through the `image-to-webp` skill, keep the source picture, and record the steps where the picture is configured.

- MUST write the commands (model, scale, resize width, encode quality) in a comment beside the config, template or CSS that names the picture, so the next person can redo it from the source.
- MUST keep the original source picture, or say where it lives, because the upscale is redone from it.
- Enforcement: the comment exists in the diff, and the source path is named in the reply.
- Violation: STOP, add the comment, name the source.

**CONSTRAINT:** MUST look at the result on the page at twice the device scale before finishing.

- MUST screenshot the page with Chrome at `--force-device-scale-factor=2`, crop the picture's detail region, and open it to look at it.
- Enforcement: the 2x screenshot crop was opened and looked at in this session.
- Violation: STOP, take it, look at it.

## Commands

From the repository root, with `$src` the source picture and `$w` the needed width:

```bash
bin="$(command -v realesrgan-ncnn-vulkan)"
models="$(dirname "$(readlink -f "$bin")")/models"
tmp="$(mktemp -d)"
for m in realesrgan-x4plus realesrgan-x4plus-anime; do
  "$bin" -i "$src" -o "$tmp/$m-x4.png" -n "$m" -s 4 -m "$models" -f png
  ffmpeg -loglevel error -y -i "$tmp/$m-x4.png" -vf "scale=$w:-2:flags=lanczos" "$tmp/$m.png"
done
ffmpeg -loglevel error -y -i "$src" -vf "scale=$w:-2:flags=bicubic" "$tmp/plain.png"
# Crop one detail region (W:H:X:Y in the upscaled pixels) from each, then stack them.
for f in plain realesrgan-x4plus realesrgan-x4plus-anime; do
  ffmpeg -loglevel error -y -i "$tmp/$f.png" -vf "crop=560:280:2620:560" "$tmp/crop-$f.png"
done
ffmpeg -loglevel error -y -i "$tmp/crop-plain.png" -i "$tmp/crop-realesrgan-x4plus.png" \
  -i "$tmp/crop-realesrgan-x4plus-anime.png" -filter_complex hstack=3 "$tmp/compare.png"
```

Open `$tmp/compare.png`, choose the model, then encode `$tmp/<model>.png` with the `image-to-webp` skill. A 3000px-wide illustration usually encodes to well under 100 KB, so one file can serve every screen.

## Steps

1. **Gate the pictures:** run the text gate, then the width gate, for each picture.
2. **Check tools:** `realesrgan-ncnn-vulkan`, its `models/`, `ffmpeg`, `cwebp`; ask to install what is missing.
3. **Upscale and compare:** run both models, build the crop comparison, look at it, choose.
4. **Encode:** hand the chosen PNG to the `image-to-webp` skill.
5. **Record:** write the commands in a comment beside where the picture is configured.
6. **Look:** screenshot the page at 2x device scale, crop, look at it.

## Pre-completion checklist

- [ ] **Gates complete:** every picture has a text gate and a width gate
      Method: read the reply
      Pass: each picture shows both, with a decision
      Fail: STOP, complete them
- [ ] **Model chosen by eye:** the crop comparison was looked at
      Method: find where the comparison image was opened in this session
      Pass: present, and the reply names the model and why
      Fail: STOP, build and look at it
- [ ] **No resize posing as an upscale:** the shipped picture came from a Real-ESRGAN model
      Method: read the commands that ran
      Pass: `realesrgan-ncnn-vulkan` ran on the source before the resize
      Fail: STOP, upscale with a model
- [ ] **Encoded and recorded:** a WebP from the `image-to-webp` skill, with the commands in a comment
      Method: the diff
      Pass: the WebP and the comment are both present
      Fail: STOP, add what is missing
- [ ] **Seen at 2x:** the page was screenshotted at twice the device scale
      Method: find where the 2x crop was opened
      Pass: present, and the detail is sharp
      Fail: STOP, take and look at it
