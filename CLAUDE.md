# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

- `make test` runs unittest (`python test_agent.py`); pytest is not installed. Single test: `python3 -m unittest test_agent.TestNB2LiteAgent.test_get_help`.
- `make lint` (`ruff check`, `ruff format --check`, `mypy`) must pass. `ruff format` also formats code blocks inside the `.md` files — that is intended.
- Install into the global pyenv `python3` (`make install`). No venvs.

## Runtime setup

- Claude Code's `nb2lite` MCP server is registered at user scope in `~/.claude.json` and runs `GEMINI_API_KEY=$(cat ~/gemini.key) exec python3 /home/xbill/nb2lite/server.py`. After changing `server.py` or dependencies, the running server is stale until `/mcp` → reconnect.
- Env: API key from `NB2LITE_GEMINI_API_KEY` (set by the plugin's `userConfig`), then `GEMINI_API_KEY`, then `GOOGLE_API_KEY`; optional `GEMINI_MODEL_NAME`, `IMAGE_OUTPUT_DIR` (default `.`).
- This repo is also a Claude Code plugin marketplace (`.claude-plugin/`, `skills/`). The plugin's MCP server lives in `plugin.json`, not a root `.mcp.json` — a root `.mcp.json` would also load as a broken project server here. Plugin `env` values override the parent environment even when empty, which is why the key uses its own variable. `.claude/skills/verify-live` is a symlink to `skills/verify-live`.
- `set_env.sh` and `init.sh` are identical by design — edit both together. They must be `source`d.

## Gotchas

- mcp 2.x: `from mcp.server.mcpserver import MCPServer` — `mcp.server.fastmcp` no longer exists.
- google-genai must be ≥2. The Interactions API removed the legacy `outputs` schema on 2026-06-08 and rejects 1.x with HTTP 400; responses are `steps`, and images are read via `interaction.output_image`.
- Unit tests mock `_get_client`, so they cannot catch SDK/API drift — verify real behavior with `/verify-live`.
- Tools never raise: each catches everything and returns a `🟢`/`🔴` string, and tests assert on those strings.
- When adding or changing a tool, also update the `get_help` text in `server.py`, the tool list in `README.md`, and `test_agent.py`.

## Workflow

- Live Gemini calls are fine for verification — use `thinking_level="minimal"` and a scratch `IMAGE_OUTPUT_DIR`.
- Commit and push directly to `main`.
