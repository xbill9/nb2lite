---
name: verify-live
description: Verify the nb2lite image tools end to end against the real Gemini API — run the unit tests, then chain generate_image → edit_image → edit_local_image through the nb2lite MCP server and inspect each image. Use after installing or updating nb2lite, after google-genai or mcp upgrades, or when an nb2lite tool returns 🔴.
---

The unit tests mock the Gemini client, so they pass even when the real API or SDK has broken. This skill checks the path users actually hit: the running nb2lite MCP server.

1. **Unit tests** (no API key needed). The nb2lite root is two levels above this skill:

   ```bash
   cd "${CLAUDE_SKILL_DIR}/../.." && python3 -m unittest test_agent
   ```

   When working inside the nb2lite repo itself, also run `make lint`. Report failures but continue.

2. **Live chain** through the nb2lite MCP server's tools, always with `thinking_level="minimal"`:
   1. `generate_image(prompt="a small red cube on a white table", thinking_level="minimal")` — note the `Saved to:` path and the `Interaction ID:`.
   2. `edit_image(previous_interaction_id=<ID from 1>, edit_prompt="make the cube blue", thinking_level="minimal")`
   3. `edit_local_image(image_path=<path from 1>, edit_prompt="add a small green sphere next to the cube", thinking_level="minimal")`

   If no nb2lite tools are available, the server is not connected: tell the user to check `/mcp` and stop.

3. **Inspect** each saved image with Read and confirm: a red cube; then the same scene with the cube blue (stateful edit); then the red cube with a green sphere added (local edit). A `🟢` result with no image file, or an image that ignores the edit, is a failure.

4. **Report** pass/fail per step, quoting the full `🔴` message for any failure. Common causes:
   - HTTP 400 naming an SDK version: the `python3` running the server has google-genai 1.x. Check `python3 -m pip show google-genai mcp`; it needs google-genai ≥2 and mcp ≥2.
   - Missing or invalid API key: set the Gemini API key in the nb2lite plugin's configuration (`/plugin`), or export `GEMINI_API_KEY` before starting Claude Code.
   - Server absent from `/mcp`: run `python3 "${CLAUDE_SKILL_DIR}/../../server.py" < /dev/null` to surface the import error.

5. If `server.py` or its dependencies changed during this session, the running server is stale: reconnect it with `/mcp` before step 2.
