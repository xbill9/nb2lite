---
name: nb2lite
description: Generate, edit and restyle images with Nano Banana 2 Lite (gemini-3.1-flash-lite-image) through the nb2lite MCP server — text-to-image, multi-turn edits by interaction ID, edits of a local image file, and style transfer from a reference image. Use whenever the user asks to make, draw, render, generate, edit, change, restyle or "nano banana" an image, a cover image, an illustration, an icon or a picture, or to apply one image's style to another.
---

nb2lite exposes Nano Banana 2 Lite as MCP tools. They appear as `mcp__nb2lite__<tool>` in Claude Code (often deferred — search for `nb2lite` to load them before concluding they are missing) and as `nb2lite/<tool>` in Codex. If none are available, the server is not connected: tell the user to register or restart it (Claude Code: `/mcp`; Codex: `codex mcp list`, then a new session; agy: `agy mcp list`, then a new session) and stop.

## Pick the tool

| The user wants… | Tool |
| :--- | :--- |
| A new image from a description | `generate_image(prompt, aspect_ratio, thinking_level)` |
| A change to an image nb2lite made earlier in this conversation | `edit_image(previous_interaction_id, edit_prompt, thinking_level)` |
| A change to an image file on disk (a photo, a screenshot, an image from another tool) | `edit_local_image(image_path, edit_prompt, aspect_ratio, thinking_level)` |
| An image file redrawn in the style of another image file | `edit_local_image_with_style(image_path, style_image_path, edit_prompt, aspect_ratio, thinking_level)` |
| The configuration (key status, model, output directory) | `get_help()` |

- **Prefer `edit_image` for follow-ups.** It continues the stored interaction, so the model keeps the subject, composition and style far more faithfully than re-uploading the file. Chain it: each result has a new `Interaction ID:`; pass the latest one to keep iterating, or an earlier one to branch from that version.
- `edit_image` has no `aspect_ratio`. To change the framing of an existing image, use `edit_local_image` on its saved path with the new ratio.
- In `edit_local_image_with_style`, `image_path` is the subject to keep and `style_image_path` is the look to borrow — not the other way round. The server already instructs the model to transfer style and keep the subject, so `edit_prompt` only needs extra direction (`"keep the background plain"`); it may be short.

## Arguments

- `aspect_ratio`: one of `1:1` (default), `16:9`, `9:16`, `4:3`, `3:4`. Match the destination: `16:9` for covers, banners and slides, `9:16` for phone/story, `1:1` for avatars and icons. Anything else returns 🔴 without calling the API.
- `thinking_level`: `minimal`, `low`, `medium` (default), `high`. Use `minimal` for quick drafts, tests and simple subjects; keep `medium` or raise to `high` for dense compositions, legible text in the image, or precise layouts.
- Paths: pass absolute paths, or paths relative to the **server's** working directory (not necessarily yours). The image type is guessed from the extension, and anything unrecognised is sent as PNG, so only pass real image files.

## Prompts

Describe the image, not the request: subject, setting, composition, medium or photographic style, lighting, palette. Put any text that must appear in the image in quotes and keep it short — lite-tier models misspell long text. For edits, say what changes and, when it matters, what must stay (`"make the jacket red; keep the face and pose unchanged"`).

## Results

Every tool returns a string and never raises:

- `🟢 Image successfully saved!` with `Saved to: <absolute path>` and `Interaction ID: <id>`. Files land in `IMAGE_OUTPUT_DIR` (default: the server's working directory) as `<prefix>_<timestamp>_<hex>.<jpg|png|webp>`. Move or rename the file if the user wants it somewhere specific.
- `🟢 Interaction completed successfully.` with only an ID means the model answered without an image — usually it refused or misread the prompt. Rephrase and retry once; then report it.
- `🔴 …` is a failure; quote it to the user. Invalid argument messages list the allowed values. API-key, HTTP 400 or SDK errors mean the setup is broken — suggest the `verify-live` skill to diagnose.

**Open the saved image and look at it** before reporting success. Check it actually shows what was asked (the edit applied, the subject preserved, text spelled right); if not, make a corrective `edit_image` call rather than presenting a wrong image. Tell the user the path and the interaction ID, so they can ask for further edits.

Generation calls the paid Gemini API. Make one image per request unless the user asks for variations, and do not loop retries.
