# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Shared guidance for all agents — commands, gotchas, per-agent registration, workflow — is in AGENTS.md:

@AGENTS.md

## Claude Code only

- Claude Code's `nb2lite` MCP server is registered at user scope in `~/.claude.json` and runs `bash -c 'GEMINI_API_KEY=$(cat ~/gemini.key) exec python3 /home/xbill/nb2lite/server.py'` (re-add with `claude mcp add --scope user nb2lite -- bash -c '…'`). After changing `server.py` or dependencies, the running server is stale until `/mcp` → reconnect. Tools from a server added mid-session only appear after that reconnect.
- This repo is also a Claude Code plugin marketplace (`.claude-plugin/`, `skills/`). The plugin's MCP server lives in `plugin.json`, not a root `.mcp.json` — a root `.mcp.json` would also load as a broken project server here. Plugin `env` values override the parent environment even when empty, which is why the key uses its own `NB2LITE_GEMINI_API_KEY` variable.
- `.claude/skills/verify-live` is a symlink to `skills/verify-live`, so `/verify-live` works in this repo without installing the plugin.
- A PostToolUse hook in `.claude/settings.json` runs `ruff format` (+ `ruff check --fix` for `.py`) after every Write/Edit; files changing after an edit is expected.
