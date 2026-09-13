---
title: "Nano Banana 2 Lite, Revisited: MCP 2.0, the New Interactions API, and Three Agent CLIs"
published: false
series: MCP
description: "The Nano Banana 2 Lite MCP server from July, updated: FastMCP is now MCPServer, google-genai 1.x gets a 400 from the Interactions API, and one server now runs in Claude Code, Codex and Antigravity CLI."
tags: mcp, python, gemini, claudecode
cover_image: https://raw.githubusercontent.com/xbill9/nb2lite/main/docs/devto-cover.9e801a45.jpg
---

This article provides a step by step update guide for a Python MCP server that drives Google Nano Banana 2 Lite (`gemini-3.1-flash-lite-image`) through the Gemini Interactions API. Two dependency lines moved underneath it since it was first published: the MCP Python SDK went to 2.x, and the Interactions API dropped the schema that google-genai 1.x speaks. The same server is then registered with Claude Code, Codex and Antigravity CLI, and validated end to end against the live API.

https://github.com/xbill9/nb2lite

---

#### Haven't You Done This One Before?

What is old is new — again.

The original article set up this server with Claude Code in July:

[Nano Banana 2 Lite with Claude Code](https://dev.to/gde/nano-banana-2-lite-with-claude-code-4n6l)

The code in that article no longer runs on a fresh install. Nothing in the repository was broken; `requirements.txt` listed `mcp` and `google-genai` with no version bounds, and both resolved to a new major version.

| | July (original article) | September (this article) |
|---|---|---|
| MCP SDK | `from mcp.server.fastmcp import FastMCP` | `from mcp.server.mcpserver import MCPServer` |
| google-genai | unpinned, 1.x | `google-genai>=2,<3` |
| Interactions response | legacy schema | `steps`, read via `output_image` |
| Tools | 4 | 5 — adds `edit_local_image_with_style` |
| Clients | Claude Code, via `.mcp.json` | Claude Code plugin, Codex, Antigravity CLI |
| Live check | manual | a `verify-live` skill |

---

#### What is Nano Banana 2 Lite?

**Nano Banana 2 Lite** is the nickname for **Gemini 3.1 Flash-Lite Image**, Google's low-latency image generation and editing model. The launch details are in the original article and here:

[Gemini 3.1 Flash-Lite Image (Nano Banana 2 Lite) | Google Cloud Documentation](https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/gemini/3-1-flash-lite-image)

---

#### So What is the Secret Sauce?

The **Interactions API** is still the secret sauce. Every call is stored server-side with `store=True` and returns an interaction ID. Pass that ID back as `previous_interaction_id` and the model edits the image it already made, instead of redrawing a scene from a fresh prompt.

That is what makes a small MCP surface useful. `generate_image` starts a session, `edit_image` continues one, and the agent only has to carry an ID.

---

#### What Broke in the Interactions API?

The server's code did not change. The SDK underneath it did not change either — the API moved away from it.

Here is the exact call `server.py` makes, run with google-genai 1.x from a scratch `pip install --target` directory, so the global Python keeps 2.x:

```python
c = genai.Client(api_key=...)
c.interactions.create(
    model="gemini-3.1-flash-lite-image",
    input="a small red cube on a white table",
    response_format={"type": "image"},
    generation_config={"thinking_level": "minimal"},
    store=True,
)
```

```plaintext
google-genai 1.75.0
BadRequestError: Error code: 400 - {'error': {'message': 'The legacy Interactions API schema is no longer supported. Please upgrade your google-genai Python SDK to version >= 2.0.0 (e.g., run pip install -U google-genai) to use the Interactions API. For details and migration examples, see: https://ai.google.dev/gemini-api/docs/interactions-breaking-changes-may-2026', 'code': 'invalid_request'}}
```

Like the MCP 2.x import error, this message deserves credit: it names the fix and links the migration notes. Inside an MCP server it is less visible. Each tool catches the exception and returns it as a `🔴` string, so the agent reports "Image generation failed" and the version number is buried in the text.

---

#### What Changed in the Response?

google-genai 2.x reads the new response schema, where the model's output arrives as a list of **`steps`**. The SDK exposes the generated image as a convenience property, `interaction.output_image`, with `data` and `mime_type`.

`server.py` already read `output_image`, so upgrading the SDK was the whole fix. No tool function changed:

```python
image_output = getattr(interaction, "output_image", None)
...
data = getattr(image_output, "data", None)
if isinstance(data, str):
    image_bytes = base64.b64decode(data)
else:
    image_bytes = data
```

If your own code walks the legacy output fields by hand, that is the part the migration notes linked from the error cover.

---

#### 🔎 Tip: Mocked Tests Cannot See This Break

The unit tests passed the whole time the server was broken. They mock `_get_client`, so the SDK never builds a real response and the API is never called.

The fix was one test that builds a real steps-schema `Interaction` with the SDK's own model and runs it through the response handler:

```python
interaction = Interaction.model_validate(
    {
        "id": "int_steps",
        "status": "completed",
        "steps": [
            {
                "type": "model_output",
                "content": [
                    {"type": "image", "data": "aGVsbG8=", "mime_type": "image/png"}
                ],
            }
        ],
    }
)
result = _handle_response(interaction, "steps")
```

On google-genai 1.x that import does not exist, so the test fails loudly instead of the API failing quietly. The rest of the gap is covered by a live check, later in this article.

---

#### What Changed for MCP 2.0?

The MCP port was the smaller of the two. The whole code change:

```diff
-from mcp.server.fastmcp import FastMCP
+from mcp.server.mcpserver import MCPServer

-# Initialize FastMCP Server
-mcp = FastMCP("NB2Lite Agent")
+# Initialize MCP Server (mcp>=2 renamed FastMCP to MCPServer)
+mcp = MCPServer("NB2Lite Agent")
```

`@mcp.tool()` and `mcp.run()` stay as they are, and so does every tool body. The full walk-through of the 2.x changes, with the exposure greps, is in the companion article:

[FastMCP Is Now MCPServer: Migrating a Python MCP Server to the MCP SDK 2.x](https://dev.to/gde/fastmcp-is-now-mcpserver-migrating-a-python-mcp-server-to-the-mcp-sdk-2x-2nhj)

Two 2.x details showed up in this repository.

**`list_tools()` is async on `MCPServer`.** The old test reached into a private attribute. The new one uses the public API:

```diff
-        tools = [t.name for t in mcp._tool_manager.list_tools()]
+        tools = [t.name for t in asyncio.run(mcp.list_tools())]
```

**The server version went blank.** An unversioned 2.x server reports an empty string in the handshake, which shows up in the protocol test below.

---

#### Pin Both Major Versions

Both breaks came from unbounded requirements, so both lines now carry a floor and a ceiling:

```diff
-google-genai
-mcp
+google-genai>=2,<3
+mcp>=2,<3
```

The floor documents what the code needs. The ceiling means the next major version arrives on purpose rather than through `pip install`.

---

#### At This Point You Should Have…

- Python 3.10 or newer, and no virtualenv — these projects install into one system Python
- A Gemini API key from [Google AI Studio](https://aistudio.google.com/apikey)
- At least one of Claude Code, Codex or Antigravity CLI installed

---

#### Setup the Basic Environment

Clone the repository and install into the Python the agent will launch:

```shell
cd ~
git clone https://github.com/xbill9/nb2lite
cd nb2lite
make install
```

Then run `set_env.sh`. It reads the key from `~/gemini.key`, or prompts for it and saves it there, and exports `GEMINI_API_KEY`:

```shell
source set_env.sh
```

Check what is installed:

```shell
python3 -m pip show mcp google-genai | grep -E "^(Name|Version)"
```

```plaintext
Name: mcp
Version: 2.2.0
Name: google-genai
Version: 2.22.0
```

---

#### Lint and Test

```shell
make lint
```

```plaintext
ruff check .
All checks passed!
ruff format --check .
8 files already formatted
mypy .
Success: no issues found in 2 source files
```

```shell
make test
```

```plaintext
----------------------------------------------------------------------
Ran 12 tests in 0.305s

OK
```

---

#### Test the Protocol by Hand

Unit tests call Python. A client speaks JSON-RPC over stdio, so test that too. Hold stdin open with `sleep`, or the server sees end-of-input before it answers:

```shell
{ printf '%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"probe","version":"0"}}}' \
  '{"jsonrpc":"2.0","method":"notifications/initialized"}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}'; sleep 4; } \
  | python3 server.py 2>/dev/null
```

The responses are JSON; summarised:

```plaintext
initialize OK: name='NB2Lite Agent' version='' proto 2025-06-18
tools/list OK: 5 tools -> generate_image, edit_image, edit_local_image, edit_local_image_with_style, get_help
```

🟢 Five tools, and `version=''` — the blank version from MCP 2.x.

---

#### Validation with Claude Code

The July article registered the server with a project `.mcp.json`. The repository is now also a Claude Code plugin marketplace, which bundles the server and the `verify-live` skill:

```shell
claude plugin marketplace add xbill9/nb2lite
claude plugin install nb2lite@nb2lite
```

The API key goes in the plugin's configuration under `/plugin`. Left blank, the server falls back to `GEMINI_API_KEY` from the environment Claude Code started in.

**🔎 Tip: a plugin `env` value wins even when it is empty.** Mapping the plugin's key setting straight to `GEMINI_API_KEY` would blank a key the user had already exported. The plugin sets its own variable, `NB2LITE_GEMINI_API_KEY`, and the server checks that first, then `GEMINI_API_KEY`, then `GOOGLE_API_KEY`.

Manual registration still works, and reads the key at launch so it never lands in a config file:

```shell
claude mcp add --scope user nb2lite -- bash -c 'GEMINI_API_KEY=$(cat ~/gemini.key) exec python3 /path/to/nb2lite/server.py'
```

After changing `server.py` or upgrading a dependency, reconnect the server from `/mcp`.

---

#### Validation with Codex

Same command, Codex syntax:

```shell
codex mcp add nb2lite -- bash -c 'GEMINI_API_KEY=$(cat ~/gemini.key) exec python3 /path/to/nb2lite/server.py'
```

Interactive Codex asks before each MCP tool call. Non-interactive `codex exec` has nobody to ask, so the call fails:

```plaintext
mcp: nb2lite/get_help started
mcp: nb2lite/get_help (failed)
MCP tool call requires approval, but approval policy is never
```

The fix is a per-server setting in `~/.codex/config.toml`:

```toml
[mcp_servers.nb2lite]
command = "bash"
args = ["-c", "GEMINI_API_KEY=$(cat ~/gemini.key) exec python3 /path/to/nb2lite/server.py"]
default_tools_approval_mode = "approve"
```

```plaintext
mcp: nb2lite/get_help (completed)
### 🌌 NB2Lite Agent (gemini-3.1-flash-lite-image) Help & Configuration
```

Inside the repository, Codex also picked up `AGENTS.md` and the `verify-live` skill from `.agents/skills/`. ✅

---

#### Validation with Antigravity CLI

```shell
agy mcp add nb2lite -- bash -c 'GEMINI_API_KEY=$(cat ~/gemini.key) exec python3 /path/to/nb2lite/server.py'
agy mcp list
```

```plaintext
Added MCP server "nb2lite" (stdio)
NAME     TYPE   STATUS   COMMAND/URL
nb2lite  stdio  enabled  bash -c GEMINI_API_KEY=$(cat ~/gemini.key) exec python3 /home/xbill/nb2lite/server.py
```

Print mode called the tools with no extra approval setting. Attach the prompt to the flag and put other flags first — a bare `-p` followed by another flag takes that flag as the prompt:

```shell
agy --print-timeout 3m -p="Call the nb2lite MCP server's get_help tool. Reply with only the first line of its output verbatim, then the names of the nb2lite tools available to you."
```

```plaintext
### 🌌 NB2Lite Agent (gemini-3.1-flash-lite-image) Help & Configuration

- `generate_image`
- `edit_image`
- `edit_local_image`
- `edit_local_image_with_style`
- `get_help`
```

**🔎 Tip: agy did not find the repository's skills.** Codex read `.agents/skills/`; agy's CLI did not, even for a real directory rather than a symlink. It does read the global skills folder, and a symlink there works:

```shell
mkdir -p ~/.gemini/config/skills
ln -s /path/to/nb2lite/skills/verify-live ~/.gemini/config/skills/verify-live
```

---

#### There is A Skill for That!

Mocked tests pass while the API is broken, so the repository ships a skill that checks the path users actually hit. `verify-live` runs the unit tests, then chains all four image tools through the running MCP server at `thinking_level="minimal"`, and opens every image it saved.

The skill is written once and exposed to each client: through the plugin for Claude Code, `.agents/skills/` for Codex, and the global link for agy.

The run from Claude Code:

| Step | Tool | Result |
|---|---|---|
| 1 | `generate_image` — a red cube on a white table | 🟢 red cube, white table |
| 2 | `edit_image` — make the cube blue | 🟢 same composition, only the cube recoloured |
| 3 | `edit_local_image` — add a green sphere | 🟢 sphere added beside the cube |
| 4 | `generate_image` — watercolor sunflowers | 🟢 the style reference |
| 5 | `edit_local_image_with_style` — cube in the reference's style | 🟢 the cube scene as a watercolor, no sunflowers |

Step 2 is the Interactions API test, since it proves the stored session came back. Step 5 is the new tool. The style reference must look nothing like the cube photo, or a transfer cannot be told apart from a copy.

---

#### Enough, Already! Show me the Money!

Claude Code was started for a hands-on session with the migrated server:

```plaintext
generate_image(prompt="pixel-art ghost banana character with big friendly eyes, floating, dark indigo background, crisp 16-bit style", aspect_ratio="16:9", thinking_level="minimal")

🟢 Image successfully saved!
• Saved to: /home/xbill/nb2lite/gen_1789322371_4fc516ed.jpg
• Interaction ID: v1_ChdndVNtYXN6ZkRQcmRqTWNQbXV5QjJBZxIXZ3VTbWFzemZEUHJkak1jUG11eUIyQWc
```

![A pixel-art ghost banana with big eyes floating on a starry indigo background](https://raw.githubusercontent.com/xbill9/nb2lite/main/docs/img/nb2lite-ghost-banana.jpg)

Not a fan of plain bananas? Continue the stored session with the interaction ID:

```plaintext
edit_image(previous_interaction_id="v1_ChdndVNtYXN6ZkRQcmRqTWNQbXV5QjJBZxIXZ3VTbWFzemZEUHJkak1jUG11eUIyQWc", edit_prompt="make the ghost banana steampunk: brass gears, rivets and goggle eyes", thinking_level="minimal")

🟢 Image successfully saved!
• Saved to: /home/xbill/nb2lite/edit_1789322402_e466080a.jpg
• Interaction ID: v1_ChdndVNtYXN6ZkRQcmRqTWNQbXV5QjJBZxIXb2VTbWFxaVhEcUt3MU1rUGt1Zmh3UXM
```

![The same ghost banana, now with brass gears, rivets and goggles, in the same pose and background](https://raw.githubusercontent.com/xbill9/nb2lite/main/docs/img/nb2lite-steampunk-banana.jpg)

The pose, the glow, the stars and the constellation lines all carried over. Only the banana changed.

Not a fan of steampunk? The new tool takes a style from a second image. First, a reference:

```plaintext
generate_image(prompt="a traditional Japanese ukiyo-e woodblock print of a great wave, flat colors, bold outlines, visible paper grain", aspect_ratio="16:9", thinking_level="minimal")

🟢 Image successfully saved!
• Saved to: /home/xbill/nb2lite/gen_1789322407_8dc09a3f.jpg
```

![A ukiyo-e style woodblock print of a great wave with boats and a distant mountain](https://raw.githubusercontent.com/xbill9/nb2lite/main/docs/img/nb2lite-wave-reference.jpg)

Then the original banana, in that style:

```plaintext
edit_local_image_with_style(image_path="gen_1789322371_4fc516ed.jpg", style_image_path="gen_1789322407_8dc09a3f.jpg", edit_prompt="keep the banana character and its big eyes", aspect_ratio="16:9", thinking_level="minimal")

🟢 Image successfully saved!
• Saved to: /home/xbill/nb2lite/style_edit_1789322423_7efbadf5.jpg
```

![The ghost banana character rendered as a woodblock print](https://raw.githubusercontent.com/xbill9/nb2lite/main/docs/img/nb2lite-woodblock-banana.jpg)

---

#### Cheat Sheet

```shell
# pins
#   google-genai>=2,<3   (1.x: 400 "legacy Interactions API schema is no longer supported")
#   mcp>=2,<3            (FastMCP -> MCPServer)
make install && make lint && make test

# stdio smoke test: hold stdin open
{ printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"p","version":"0"}}}' \
                '{"jsonrpc":"2.0","method":"notifications/initialized"}' \
                '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}'; sleep 4; } | python3 server.py 2>/dev/null

# register
claude plugin marketplace add xbill9/nb2lite && claude plugin install nb2lite@nb2lite
codex mcp add nb2lite -- bash -c 'GEMINI_API_KEY=$(cat ~/gemini.key) exec python3 /path/to/nb2lite/server.py'
agy mcp add nb2lite -- bash -c 'GEMINI_API_KEY=$(cat ~/gemini.key) exec python3 /path/to/nb2lite/server.py'

# codex exec: [mcp_servers.nb2lite] default_tools_approval_mode = "approve"
# agy skills: ln -s /path/to/nb2lite/skills/verify-live ~/.gemini/config/skills/verify-live
```

---

#### Summary

The goal of this article was to bring the Nano Banana 2 Lite MCP server from July back to a working state on current dependencies, and to run it from more than one agent CLI. The key to the solution was reading the two error messages, which named both fixes, and then proving the live API path instead of trusting mocked tests. The update results were:

- ❌ google-genai 1.x now gets HTTP 400 from the Interactions API; the fix was `google-genai>=2,<3`, with no change to `server.py`
- 🟢 The MCP 2.0 port was the import and the constructor; all five tools register unchanged
- ⚠️ Mocked unit tests passed throughout the break; a steps-schema test and the `verify-live` skill now cover it
- 🟢 One server, one launch command: Claude Code, Codex and Antigravity CLI all called the tools
- ⚠️ `codex exec` needs `default_tools_approval_mode = "approve"`, and agy needs the skill linked globally

Scope: one Debian 13 workstation, Python 3.14.7, mcp 2.2.0 and google-genai 2.22.0, with google-genai 1.75.0 from a scratch install as the failing reference. Claude Code 2.1.270 and Codex 0.153.4; agy was 1.1.27 for the tool tests and had updated itself to 1.2.2 by the time versions were recorded. Every image call ran once at `thinking_level="minimal"` against `gemini-3.1-flash-lite-image`; nothing here measures latency or cost.

The strategy for using MCP with Nano Banana 2 Lite across Claude Code, Codex and Antigravity CLI was validated with an incremental step by step approach.

#### References

- [nb2lite | GitHub](https://github.com/xbill9/nb2lite)
- [Nano Banana 2 Lite with Claude Code](https://dev.to/gde/nano-banana-2-lite-with-claude-code-4n6l)
- [Interactions API breaking changes | Gemini API](https://ai.google.dev/gemini-api/docs/interactions-breaking-changes-may-2026)
- [Interactions API | Gemini API](https://ai.google.dev/gemini-api/docs/interactions-overview)
- [Migration Guide: v1 to v2 | MCP Python SDK](https://py.sdk.modelcontextprotocol.io/v2/migration/)
- [FastMCP Is Now MCPServer: Migrating a Python MCP Server to the MCP SDK 2.x](https://dev.to/gde/fastmcp-is-now-mcpserver-migrating-a-python-mcp-server-to-the-mcp-sdk-2x-2nhj)

---

*mcp 2.2.0 (mcp-types 2.2.0), google-genai 2.22.0, Python 3.14.7, ruff 0.16.7, mypy 2.3.1, Claude Code 2.1.270, Codex 0.153.4, Antigravity CLI 1.1.27 / 1.2.2, `gemini-3.1-flash-lite-image`.*
