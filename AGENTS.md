# AGENTS.md

Guidance for coding agents (Claude Code, Codex, Antigravity/agy) working in this repository.

nb2lite gives agents **Nano Banana 2 Lite** — Google's `gemini-3.1-flash-lite-image` — as MCP tools, through Gemini's stateful Interactions API. It ships three things:

- `server.py` — the MCP server (`generate_image`, `edit_image`, `edit_local_image`, `edit_local_image_with_style`, `get_help`).
- `skills/verify-live/` — an end-to-end check against the real API. Exposed to Claude Code through the plugin (and `.claude/skills/verify-live`), and to Codex through `.agents/skills/verify-live`; both entries are symlinks to `skills/verify-live`. The agy CLI ignores workspace `.agents/skills` — it needs `~/.gemini/config/skills/verify-live` linked to `skills/verify-live`.
- `.claude-plugin/` — the Claude Code plugin and marketplace manifests.

## Commands

- `make test` runs unittest (`python test_agent.py`); pytest is not installed. Single test: `python3 -m unittest test_agent.TestNB2LiteAgent.test_get_help`.
- `make lint` (`ruff check`, `ruff format --check`, `mypy`) must pass. `ruff format` also formats code blocks inside `.md` files — that is intended, so run `ruff format <file>` after editing Markdown or Python.
- Install into the global pyenv `python3` (`make deps`). No venvs. `make install` runs `deps`, then uninstalls and reinstalls the Claude Code plugin from the working tree, so skill edits reach it without a version bump; `make skill-install` copies `skills/verify-live` to `~/.claude/skills/` instead.

## Gotchas

- MCP 2.0: requirements pin `mcp>=2,<3`. `FastMCP` was renamed `MCPServer` (`from mcp.server.mcpserver import MCPServer`); `mcp.server.fastmcp` no longer exists. Register tools with `@mcp.tool()`. `MCPServer.list_tools()` is async — tests call `asyncio.run(mcp.list_tools())`; use the public API, not `_tool_manager`.
- google-genai must be ≥2. The Interactions API removed the legacy `outputs` schema on 2026-06-08 and rejects 1.x with HTTP 400; responses are `steps`, and images are read via `interaction.output_image`.
- Unit tests mock `_get_client`, so they cannot catch SDK/API drift — verify real behavior with the `verify-live` skill.
- Tools never raise: each catches everything and returns a `🟢`/`🔴` string, and tests assert on those strings.
- When adding or changing a tool, also update the `get_help` text in `server.py`, the tool list in `README.md`, and `test_agent.py`.
- Bump `"version"` in `.claude-plugin/plugin.json` whenever anything under `skills/` or the plugin manifest changes — installed Claude Code plugins only update on a version change.
- `set_env.sh` and `init.sh` are identical by design — edit both together. They must be `source`d.
- Env: API key from `NB2LITE_GEMINI_API_KEY` (set by the Claude Code plugin), then `GEMINI_API_KEY`, then `GOOGLE_API_KEY`; optional `GEMINI_MODEL_NAME`, `IMAGE_OUTPUT_DIR` (default `.`, the server's working directory).

## Registering the server

Every agent launches the same stdio command; the key is read from `~/gemini.key` at launch. After changing `server.py` or its dependencies, the running server is stale until the agent restarts it.

| Agent | Register | Notes |
| :--- | :--- | :--- |
| Claude Code | plugin (`claude plugin install nb2lite@nb2lite`) or `claude mcp add --scope user nb2lite -- bash -c 'GEMINI_API_KEY=$(cat ~/gemini.key) exec python3 /path/to/nb2lite/server.py'` | Reconnect with `/mcp`. Tools are `mcp__nb2lite__*`. |
| Codex | `codex mcp add nb2lite -- bash -c 'GEMINI_API_KEY=$(cat ~/gemini.key) exec python3 /path/to/nb2lite/server.py'` | Writes `~/.codex/config.toml`. `codex exec` refuses MCP calls ("requires approval, but approval policy is never") unless `[mcp_servers.nb2lite]` has `default_tools_approval_mode = "approve"`. |
| agy | `agy mcp add nb2lite -- bash -c 'GEMINI_API_KEY=$(cat ~/gemini.key) exec python3 /path/to/nb2lite/server.py'` | Writes `~/.gemini/config/mcp_config.json`; flags go before the name. Print mode must attach the prompt to the flag (`agy -p="..."`), with other flags before it. |

## Workflow

- Live Gemini calls are fine for verification — use `thinking_level="minimal"`. Images land in `IMAGE_OUTPUT_DIR`, which is usually the repo root (gitignored via `*.jpg`/`*.png`/`*.webp`); delete them after checking.
- Commit and push directly to `main`.
