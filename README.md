# 🌌 NB2Lite Agent

[![Model: gemini-3.1-flash-lite-image](https://img.shields.io/badge/Model-gemini--3.1--flash--lite--image-orange.svg)](#)
[![API: Interactions API](https://img.shields.io/badge/API-Interactions%20API-blue.svg)](GEMINI.md)
[![Protocol: FastMCP](https://img.shields.io/badge/Protocol-FastMCP-green.svg)](#)

This repository contains a high-performance Model Context Protocol (MCP) server for interacting with **gemini-3.1-flash-lite-image**, Google's high-efficiency Gemini Image model designed for exceptional speed, low latency, and high-fidelity image generation and editing.

Unlike traditional stateless image models, `gemini-3.1-flash-lite-image` supports the stateful **Interactions API**, allowing AI agents and developers to iteratively edit, refine, and transform images using natural language within a single context session.

---

## ✨ Features

- ⚡ **Low Latency & High Scale**: Under 2-second generation times, offering exceptional quality with blazing-fast speeds.
- 🔄 **Stateful Multi-Turn Edits**: Maintain pixel and contextual continuity across multiple edits using interaction IDs.
- 🎨 **Inline Local Image Modding**: Upload existing images in-line via Base64 and describe your edits directly.
- 🧠 **Thinking Budgets**: Adjust latency vs. quality with configurable reasoning steps (`minimal`, `low`, `medium`, `high`).
- ✍️ **Enhanced Text & i18n**: Advanced text rendering in English and 25+ other languages.
- 📂 **Concurrent File Management**: Thread-safe image saving with UUID-appended unique file naming and custom output folders.

---

## ⚙️ Environment Configuration

The MCP server checks the following environment variables on startup and execution:

| Variable | Type | Description | Default |
| :--- | :--- | :--- | :--- |
| `GEMINI_API_KEY` | `str` | Primary API Key used to authenticate with the Gemini API. | *Required (or fallback)* |
| `GOOGLE_API_KEY` | `str` | Fallback API Key used if `GEMINI_API_KEY` is not defined. | *Optional* |
| `GEMINI_MODEL_NAME` | `str` | Overrides the default model used for interactions. | `"gemini-3.1-flash-lite-image"` |
| `IMAGE_OUTPUT_DIR` | `str` | Sets the local directory where generated/edited images are stored. | `"."` (current directory) |

---

## 🚀 Getting Started

### 1. Prerequisites

Ensure you have Python 3.10+ installed. Install the required dependencies using the [Makefile](Makefile) or pip:

```bash
make install
# or
pip install -r requirements.txt
```

### 2. Configure Environment

You can configure your credentials interactively or reuse an existing key file using the helper script:

```bash
# Set up environment and export credentials
source set_env.sh
```

> [!NOTE]
> The `set_env.sh` script automatically reads your key from `~/gemini.key` if it exists. If not, it prompts you for the key, stores it securely in `~/gemini.key` for persistence across sessions, and exports both `GEMINI_API_KEY` and `GOOGLE_API_KEY` (fallback).

---

## 🤖 MCP Server Integration

The FastMCP server defined in [server.py](server.py) exposes the full capabilities of `gemini-3.1-flash-lite-image` directly to your AI agents or assistants as tools.

### Run the Server

You can run the server locally or in development mode using:

```bash
make run
# or run with MCP dev tools
mcp dev server.py
```

### 🛠️ Exposed Tools

#### 1. `generate_image`
Generates a 1k resolution image from a text prompt and saves it locally.

* **Arguments**:
  - `prompt` (`str`): The natural language description of the image.
  - `aspect_ratio` (`str`): Supported: `1:1`, `16:9`, `9:16`, `4:3`, `3:4` (Default: `"1:1"`).
  - `thinking_level` (`str`): Configurable thinking budget: `minimal`, `low`, `medium`, `high` (Default: `"medium"`).
* **Usage Example**:
  ```python
  # Tool Call
  generate_image(prompt="A futuristic cyberpunk kitchen cooking noodles", aspect_ratio="16:9", thinking_level="high")
  ```

#### 2. `edit_image`
Iteratively refines or modifies an existing image while preserving pixel and contextual continuity.

* **Arguments**:
  - `previous_interaction_id` (`str`): The unique ID returned from the previous generation or edit.
  - `edit_prompt` (`str`): Natural language description of what to change or add in the image.
  - `thinking_level` (`str`): Configurable thinking budget: `minimal`, `low`, `medium`, `high` (Default: `"medium"`).
* **Usage Example**:
  ```python
  # Tool Call
  edit_image(previous_interaction_id="int_abc123xyz", edit_prompt="add a neon green glowing sign saying 'RAMEN' on the wall", thinking_level="high")
  ```

#### 3. `edit_local_image`
Uploads a local image file in-line via Base64 and applies edits described in natural language.

* **Arguments**:
  - `image_path` (`str`): Absolute or relative path to the local image file.
  - `edit_prompt` (`str`): Natural language description of how to edit or modify the image.
  - `aspect_ratio` (`str`): Supported: `1:1`, `16:9`, `9:16`, `4:3`, `3:4` (Default: `"1:1"`).
  - `thinking_level` (`str`): Configurable thinking budget: `minimal`, `low`, `medium`, `high` (Default: `"medium"`).
* **Usage Example**:
  ```python
  # Tool Call
  edit_local_image(image_path="./my_sketch.png", edit_prompt="Render this hand-drawn sketch as a high-fidelity 3D model", aspect_ratio="4:3")
  ```

---

## 🛠️ Development & Commands

Use the [Makefile](Makefile) to streamline common workflows:

| Command | Description |
| :--- | :--- |
| `make install` | Installs Python requirements. |
| `make run` | Starts the FastMCP server. |
| `make test` | Runs the full suite of agent integration tests. |
| `make lint` | Performs style, formatting, and static type checking (`ruff`, `mypy`). |
| `make clean` | Cleans up local Python cache files. |

---


---

## 📚 Documentation

- [GEMINI.md](GEMINI.md) - Complete Interactions API developer guide, Python SDK walkthrough, and raw API specifications.
