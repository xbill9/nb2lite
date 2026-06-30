# Configuration - Update these or override via environment variables
GEMINI_MODEL_NAME ?= gemini-3.1-flash-lite-image


install:
	pip install -r requirements.txt

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

.PHONY: install run test clean 
