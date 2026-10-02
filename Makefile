# Configuration - Update these or override via environment variables
GEMINI_MODEL_NAME ?= gemini-3.1-flash-lite-image

PLUGIN     := nb2lite
SKILLS     := nb2lite verify-live

.PHONY: help deps install skill-install run test lint clean

help:
	@echo "Available commands:"
	@echo "  make deps          - pip install requirements into the global python3"
	@echo "  make install       - deps, then reinstall the $(PLUGIN)@$(PLUGIN) plugin from the"
	@echo "                       working tree (no version bump needed)"
	@echo "  make skill-install - copy skills/{$(SKILLS)} to ~/.claude/skills/"
	@echo "  make run           - run the MCP server on stdio"
	@echo "  make test          - unit tests"
	@echo "  make lint          - ruff check, ruff format --check, mypy"
	@echo "  make clean         - remove caches"

deps:
	pip install -r requirements.txt

# The plugin is installed from this directory as a marketplace. `claude plugin
# update` compares version numbers only, so an edit without a version bump never
# reaches the installed copy; uninstall + install snapshots the working tree every
# time. --keep-data keeps the stored Gemini API key. skill-install is the
# plain-copy route for hosts without the plugin; using both loads the skill twice.
install: deps
	@command -v claude >/dev/null || { echo "claude not found; skipped plugin install"; exit 0; } \
		&& claude plugin validate . \
		&& claude plugin marketplace update $(PLUGIN) \
		&& { claude plugin uninstall --keep-data --scope user $(PLUGIN)@$(PLUGIN) || true; } \
		&& claude plugin install --scope user $(PLUGIN)@$(PLUGIN)

skill-install:
	mkdir -p $(HOME)/.claude/skills
	for s in $(SKILLS); do \
		rm -rf $(HOME)/.claude/skills/$$s \
		&& cp -r skills/$$s $(HOME)/.claude/skills/$$s \
		&& find $(HOME)/.claude/skills/$$s -name __pycache__ -type d -prune -exec rm -rf {} + \
		&& echo "Installed to $(HOME)/.claude/skills/$$s" || exit 1; \
	done

run:
	python server.py

test:
	python test_agent.py

lint:
	ruff check .
	ruff format --check .
	mypy .

clean:
	rm -rf __pycache__
	rm -rf .ruff_cache
	rm -rf .mypy_cache
	find . -type d -name "__pycache__" -exec rm -rf {} +
