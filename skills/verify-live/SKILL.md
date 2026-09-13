---
name: verify-live
description: Verify the nb2lite (Nano Banana 2 Lite) image tools end to end against the real Gemini API — run the unit tests, then chain generate_image → edit_image → edit_local_image → edit_local_image_with_style (against a watercolor style reference) through the nb2lite MCP server and inspect each image. Use after installing or updating nb2lite, after google-genai or mcp upgrades, or when an nb2lite tool returns 🔴.
---

The unit tests mock the Gemini client, so they pass even when the real API or SDK has broken. This skill checks the path users actually hit: the running nb2lite MCP server. It works the same from Claude Code, Codex and agy; only the tool naming and the way to restart the server differ.

1. **Unit tests** (no API key needed). Run them from the nb2lite repo root — the directory containing `server.py`, two levels above this skill's real directory (`skills/verify-live`). In Claude Code that is `${CLAUDE_SKILL_DIR}/../..`:

   ```bash
   cd /path/to/nb2lite && python3 -m unittest test_agent
   ```

   When working inside the nb2lite repo itself, also run `make lint`. Report failures but continue.

2. **Live chain** through the nb2lite MCP server's tools, always with `thinking_level="minimal"`. Steps 1 and 4 are independent — call them together; once both return, call 2, 3 and 5 together:
   1. `generate_image(prompt="a small red cube on a white table", thinking_level="minimal")` — note the `Saved to:` path and the `Interaction ID:`.
   2. `edit_image(previous_interaction_id=<ID from 1>, edit_prompt="make the cube blue", thinking_level="minimal")`
   3. `edit_local_image(image_path=<path from 1>, edit_prompt="add a small green sphere next to the cube", thinking_level="minimal")`
   4. `generate_image(prompt="a loose watercolor painting of sunflowers, visible brushstrokes and paper texture", thinking_level="minimal")` — the style reference. It must look nothing like the cube photo, or step 5 cannot show a transfer.
   5. `edit_local_image_with_style(image_path=<path from 1>, style_image_path=<path from 4>, edit_prompt="keep the cube and table", thinking_level="minimal")`

   The tools appear as `mcp__nb2lite__<tool>` in Claude Code and as `nb2lite/<tool>` in Codex. If none are available (in Claude Code they may be deferred — search for `nb2lite` before concluding), the server is not connected: tell the user to register or restart it (Claude Code: `/mcp`; Codex: `codex mcp list`, then a new session; agy: `agy mcp list`, then a new session) and stop.

   Images are written to `IMAGE_OUTPUT_DIR`, which defaults to the server's working directory — in the nb2lite repo root, `.gitignore` already excludes `*.jpg`/`*.png`/`*.webp`.

3. **Inspect** each saved image by opening it and confirm: a red cube; then the same scene with the cube blue (stateful edit); then the red cube with a green sphere added (local edit); then a watercolor painting; then the red cube on the table rendered as a watercolor (style transfer — the cube scene must survive and the medium must change; a photo, or sunflowers, is a failure; incidental details borrowed from the reference, such as the table turning to wood, are fine). A `🟢` result with no image file, or an image that ignores the edit, is a failure.

4. **Report** pass/fail per step, quoting the full `🔴` message for any failure. Common causes:
   - HTTP 400 naming an SDK version: the `python3` running the server has google-genai 1.x. Check `python3 -m pip show google-genai mcp`; it needs google-genai ≥2 and mcp ≥2.
   - Missing or invalid API key: set it in the nb2lite plugin's configuration (Claude Code `/plugin`), or make sure the launch command's `~/gemini.key` / `GEMINI_API_KEY` is valid.
   - Codex `MCP tool call requires approval, but approval policy is never`: add `default_tools_approval_mode = "approve"` under `[mcp_servers.nb2lite]` in `~/.codex/config.toml`.
   - Server missing from the agent's MCP list: run `python3 /path/to/nb2lite/server.py < /dev/null` to surface the import error.

5. If `server.py` or its dependencies changed during this session, the running server is stale: restart it before step 2.
