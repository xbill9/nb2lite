# 🍌 nb2lite — Nano Banana 2 Lite for coding agents

[![Model: gemini-3.1-flash-lite-image](https://img.shields.io/badge/Model-gemini--3.1--flash--lite--image-orange.svg)](docs/interactions-api.md)
[![API: Interactions API](https://img.shields.io/badge/API-Interactions%20API-blue.svg)](docs/interactions-api.md)
[![Protocol: MCP](https://img.shields.io/badge/Protocol-MCP%202.x-green.svg)](#-agent-setup)

nb2lite puts **Nano Banana 2 Lite** — Google's `gemini-3.1-flash-lite-image` — in the hands of **Claude Code**, **Codex** and **Antigravity (`agy`)**. It is an MCP server that generates, edits and restyles images through Gemini's stateful **Interactions API**, plus a `verify-live` skill that proves the real API path works end to end.

Because the Interactions API is stateful, an agent can generate an image and then keep refining it by interaction ID, instead of re-prompting from scratch and losing continuity.

---

## ✨ Features

- 🔄 **Stateful multi-turn edits**: refine a generated image by its interaction ID while keeping subject, composition and style.
- 🎨 **Local image edits**: send an image from disk and describe the change.
- 🖌️ **Style transfer**: repaint one local image in the style of another.
- 🧠 **Thinking levels**: trade latency for quality with `minimal`, `low`, `medium` or `high`.
- 📂 **Safe file output**: every image is saved under `IMAGE_OUTPUT_DIR` with a timestamp + UUID name, so parallel calls never collide.
- ✅ **`verify-live` skill**: unit tests plus a five-step live chain, inspected image by image — the mocked unit tests alone cannot catch API or SDK drift.

---

## 🚀 Install

Python 3.10+, installed into the `python3` your agent will launch:

```bash
make install
# or
pip install -r requirements.txt   # google-genai>=2,<3, mcp>=2,<3
```

> [!IMPORTANT]
> `google-genai` **2.x** is required. The Interactions API removed its legacy (`outputs`) response schema on 2026-06-08, and 1.x SDKs now fail every call with HTTP 400. The server targets `mcp` **2.x** (`MCPServer`, formerly `FastMCP`).

Put your Gemini API key ([get one](https://aistudio.google.com/apikey)) in `~/gemini.key`. `source set_env.sh` does this interactively if the file is missing, and also exports `GEMINI_API_KEY` / `GOOGLE_API_KEY` for the current shell.

---

## 🤖 Agent setup

Every agent runs the same stdio command. The examples read the key from `~/gemini.key` at launch, so the key never lands in the agent's config file. Register nb2lite **once per agent** — two registrations in the same agent would expose the tools twice.

### Claude Code

**Plugin** (bundles the server and `/nb2lite:verify-live`; this repo is its own marketplace):

```bash
claude plugin marketplace add xbill9/nb2lite
claude plugin install nb2lite@nb2lite
```

Set the API key in the plugin's configuration (`/plugin` → nb2lite). Left blank, the server falls back to `GEMINI_API_KEY` / `GOOGLE_API_KEY` from the environment Claude Code was started in.

**Manual** (user scope):

```bash
claude mcp add --scope user nb2lite -- bash -c 'GEMINI_API_KEY=$(cat ~/gemini.key) exec python3 /path/to/nb2lite/server.py'
```

After changing `server.py` or upgrading dependencies, reconnect with `/mcp`.

### Codex

```bash
codex mcp add nb2lite -- bash -c 'GEMINI_API_KEY=$(cat ~/gemini.key) exec python3 /path/to/nb2lite/server.py'
```

That writes `[mcp_servers.nb2lite]` to `~/.codex/config.toml`. For non-interactive `codex exec`, also allow the tools to run without a prompt — otherwise every call fails with *"MCP tool call requires approval, but approval policy is never"*:

```toml
[mcp_servers.nb2lite]
command = "bash"
args = ["-c", "GEMINI_API_KEY=$(cat ~/gemini.key) exec python3 /path/to/nb2lite/server.py"]
default_tools_approval_mode = "approve"
```

Inside this repo Codex picks up the skill from `.agents/skills/verify-live`. To use it elsewhere, link it into your user skills: `ln -s /path/to/nb2lite/skills/verify-live ~/.codex/skills/verify-live`.

### Antigravity (`agy`)

```bash
agy mcp add nb2lite -- bash -c 'GEMINI_API_KEY=$(cat ~/gemini.key) exec python3 /path/to/nb2lite/server.py'
agy mcp list
```

That writes `~/.gemini/config/mcp_config.json`; any flags (`--env`, `--type`) must come before the name. Tool calls work in print mode (`agy -p=...`) without extra approval settings.

The agy CLI does not discover the repo's `.agents/skills`, so link the skill into your global skills (a symlink is fine):

```bash
mkdir -p ~/.gemini/config/skills
ln -s /path/to/nb2lite/skills/verify-live ~/.gemini/config/skills/verify-live
```

### Other MCP clients

`source set_env.sh` writes `.agents/mcp_config.json` (gitignored) with the absolute server path and the key inline — a ready-made `mcpServers` block for clients that take JSON config:

```json
{
  "mcpServers": {
    "nb2lite-agent": {
      "command": "python3",
      "args": ["/path/to/nb2lite/server.py"],
      "env": {
        "GEMINI_API_KEY": "...",
        "GOOGLE_API_KEY": "..."
      }
    }
  }
}
```

---

## ⚙️ Environment

| Variable | Description | Default |
| :--- | :--- | :--- |
| `NB2LITE_GEMINI_API_KEY` | API key from the Claude Code plugin's config; checked first. | — |
| `GEMINI_API_KEY` | Gemini API key. | — |
| `GOOGLE_API_KEY` | Fallback if neither of the above is set. | — |
| `GEMINI_MODEL_NAME` | Model used for every interaction. | `gemini-3.1-flash-lite-image` |
| `IMAGE_OUTPUT_DIR` | Where images are saved (created if missing). | `.` — the server's working directory |

The key is only needed when a tool is called, so the server starts without one.

---

## 🛠️ Tools

Every tool saves its image under `IMAGE_OUTPUT_DIR` as `<prefix>_<timestamp>_<uuid8>.<ext>` and returns a `🟢` message with the saved path and interaction ID, or a `🔴` message describing the failure. Tools never raise.

Supported aspect ratios: `1:1`, `16:9`, `9:16`, `4:3`, `3:4`. Thinking levels: `minimal`, `low`, `medium`, `high`.

#### 1. `generate_image`
Generates an image from a text prompt.

- `prompt` (`str`): description of the image.
- `aspect_ratio` (`str`, default `"1:1"`).
- `thinking_level` (`str`, default `"medium"`).

```python
generate_image(
    prompt="A futuristic cyberpunk kitchen cooking noodles",
    aspect_ratio="16:9",
    thinking_level="high",
)
```

#### 2. `edit_image`
Refines a previously generated or edited image by its interaction ID, keeping context from that turn. The aspect ratio carries over.

- `previous_interaction_id` (`str`): the ID returned by an earlier call.
- `edit_prompt` (`str`): what to change.
- `thinking_level` (`str`, default `"medium"`).

```python
edit_image(
    previous_interaction_id="int_abc123xyz",
    edit_prompt="add a neon green glowing sign saying 'RAMEN' on the wall",
)
```

#### 3. `edit_local_image`
Sends a local image in-line (Base64) and applies the described edit.

- `image_path` (`str`): absolute or relative path to the image.
- `edit_prompt` (`str`): how to edit it.
- `aspect_ratio` (`str`, default `"1:1"`).
- `thinking_level` (`str`, default `"medium"`).

```python
edit_local_image(
    image_path="./my_sketch.png",
    edit_prompt="Render this hand-drawn sketch as a high-fidelity 3D model",
    aspect_ratio="4:3",
)
```

#### 4. `edit_local_image_with_style`
Edits a local image using a second local image as a style reference. The model is told to apply the reference's visual style, technique, color palette and lighting to the target while keeping the target's subject and composition, followed by your `edit_prompt`.

- `image_path` (`str`): the image to edit.
- `style_image_path` (`str`): the style reference.
- `edit_prompt` (`str`): additional modifications.
- `aspect_ratio` (`str`, default `"1:1"`).
- `thinking_level` (`str`, default `"medium"`).

```python
edit_local_image_with_style(
    image_path="./portrait.jpg",
    style_image_path="./starry_night.jpg",
    edit_prompt="keep the background simple",
)
```

#### 5. `get_help`
Returns the configuration (key status, model, output directory) and a summary of all tools.

---

## ✅ Verifying a setup

Run the `verify-live` skill from your agent — `/nb2lite:verify-live` with the Claude Code plugin, `/verify-live` inside this repo, or ask Codex / agy to "run the verify-live skill". It runs the unit tests, then chains `generate_image → edit_image → edit_local_image → edit_local_image_with_style` against the real API at `thinking_level="minimal"` and inspects each image. See [skills/verify-live/SKILL.md](skills/verify-live/SKILL.md).

---

## 🧑‍💻 Development

| Command | Description |
| :--- | :--- |
| `make install` | Installs Python requirements. |
| `make run` | Starts the MCP server over stdio. |
| `make test` | Runs the unit tests (`unittest`; the Gemini client is mocked). |
| `make lint` | Runs `ruff check`, `ruff format --check` (including code blocks in `.md` files) and `mypy`. |
| `make clean` | Removes Python and tool caches. |

Agent guidance for working on this repo is in [AGENTS.md](AGENTS.md) (Codex, agy) and [CLAUDE.md](CLAUDE.md) (Claude Code, which imports AGENTS.md).

## 📚 Documentation

- [docs/interactions-api.md](docs/interactions-api.md) — the Interactions API as used here: stateful editing, parameters, Python SDK examples.
