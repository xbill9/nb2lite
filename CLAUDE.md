# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Shared guidance for all agents — commands, gotchas, per-agent registration, workflow — is in AGENTS.md:

@AGENTS.md

## Claude Code only

- Claude Code runs nb2lite as the `nb2lite@nb2lite` plugin (user scope), installed from this directory registered as a local marketplace; there is no separate `claude mcp add` server — adding one would duplicate the tools. The API key is the plugin's `gemini_api_key` option (`claude plugin configure nb2lite@nb2lite`). `make install` snapshots the working tree into the plugin; after changing `server.py`, skills or dependencies, run it, then `/mcp` → reconnect (or restart Claude Code). Tools from a server added mid-session only appear after that reconnect.
- This repo is also a Claude Code plugin marketplace (`.claude-plugin/`, `skills/`). The plugin's MCP server lives in `plugin.json`, not a root `.mcp.json` — a root `.mcp.json` would also load as a broken project server here. Plugin `env` values override the parent environment even when empty, which is why the key uses its own `NB2LITE_GEMINI_API_KEY` variable.
- `.claude/skills/verify-live` is a symlink to `skills/verify-live`, so `/verify-live` works in this repo without installing the plugin.
- A PostToolUse hook in `.claude/settings.json` runs `ruff format` (+ `ruff check --fix` for `.py`) after every Write/Edit; files changing after an edit is expected.
