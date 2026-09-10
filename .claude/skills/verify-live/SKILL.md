---
name: verify-live
description: Verify nb2lite end to end — unit tests, lint, then real Gemini generate/edit/edit_local calls whose output images are inspected. Use after changing server.py or dependencies, or when the google-genai or mcp SDKs update.
---

The unit tests mock the Gemini client, so they pass even when the real API or SDK has broken. This skill checks the real path.

1. Run `python3 -m unittest test_agent` and `make lint`. Report failures but continue to the live check.
2. Run the live chain against a scratch output directory:

   ```bash
   OUT=$(mktemp -d)
   GEMINI_API_KEY=$(cat ~/gemini.key) IMAGE_OUTPUT_DIR=$OUT python3 -W ignore -c '
   import re
   import sys

   import server

   r = server.generate_image("a small red cube on a white table", thinking_level="minimal")
   print(r)
   if "🟢 Image successfully saved" not in r:
       sys.exit(1)
   iid = re.search(r"Interaction ID: (\S+)", r).group(1)
   path = re.search(r"Saved to: (\S+)", r).group(1)
   print(server.edit_image(iid, "make the cube blue", thinking_level="minimal"))
   print(server.edit_local_image(path, "add a small green sphere next to the cube", thinking_level="minimal"))
   '
   ls "$OUT"
   ```

3. Read each saved image and confirm: a red cube, then the same scene with a blue cube (stateful `edit_image`), then the red cube with a green sphere added (`edit_local_image`). A `🟢` result with no image file, or an image that ignores the edit, is a failure.
4. Report pass/fail per step, quoting the full `🔴` message for any failure. If a 400 mentions an SDK version, check `python3 -m pip show google-genai mcp` against `requirements.txt`.
5. If `server.py` or dependencies changed, remind the user to reconnect the server with `/mcp`.
