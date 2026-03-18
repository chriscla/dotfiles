---
name: python-uv-typer-project
description: Scaffold new Python CLI projects using uv, Typer, .env-based configuration, and Ruff type checking. Use when starting a new Python project from scratch that should be type-safe, use uv for dependency management, Typer for argument parsing, and include a VS Code launch.json.
---

# Python Project with uv, Typer, .env, and Ruff

## When to Use

Use this skill whenever creating a **new Python cli project from scratch** that should:

- **Use `uv`** for dependency and environment management.
- **Expose a CLI** using `typer` with type hints.
- **Load configuration from CLI args, environment variables, and `.env` files**.
- **Enforce type safety** using Ruff’s type-checking support.
- **Include VS Code debugging config** via `.vscode/launch.json`.
- **Create a git repository** for the project.

The goal is a modern, type-safe Python CLI template.

---

## Quick Checklist

- [ ] Create project structure
- [ ] Initialize git repository (if none exists)
- [ ] Initialize `uv` and dependencies
- [ ] Configure `pyproject.toml` (Python version, dependencies, Ruff)
- [ ] Add `Typer`-based entrypoint with typed arguments
- [ ] Support environment variables and `.env` configuration
- [ ] Add Ruff config (lint + type checking)
- [ ] Add `.vscode/launch.json` to run the script
- [ ] Add basic docs (`README.md`) and example `.env`

---

## 1. Project Structure

Assume a new project directory named `my-app`:

```text
my-app/
  .env.example
  .gitignore
  .vscode/
    launch.json
  pyproject.toml
  README.md
  src/
    my_app/
      __init__.py
      cli.py
```

**Conventions**

- Package name: `my_app` (snake_case; adjust to project).
- CLI module: `my_app.cli` containing the Typer app.
- Entry command (via `uv run` or console script): `my-app`.

---

## 2. Initialize git repository (if needed)

From the project root:

```bash
git rev-parse --is-inside-work-tree 2>/dev/null || git init
git add .
git commit -m "chore: initial Python uv+Typer scaffold"
```

Notes:

- The `git rev-parse` check avoids re-initializing if already inside a repo.
- Make sure `.gitignore` is created **before** the first commit so `.env`, `.uv/`, and other artifacts are excluded from history.

---

## 3. Initialize Project with uv

From the project root:

```bash
uv init --package .
```

Then add dependencies:

```bash
uv add typer[all] python-dotenv ruff
```

Notes:

- `typer[all]` installs Typer with rich/shell completion extras.
- `python-dotenv` provides `.env` loading.
- `ruff` handles linting, formatting, and type checking.

---

## 4. Configure `pyproject.toml`

### 3.1 Python and project metadata

In `pyproject.toml`, ensure:

- **Python version** uses a modern, type-friendly version (e.g. `>=3.11`).
- The **project name** is kebab-case; package name is snake_case under `src/`.

Example core sections (adapt names as needed):

```toml
[project]
name = "my-app"
version = "0.1.0"
description = "CLI app built with Typer, uv, and Ruff type checking."
readme = "README.md"
requires-python = ">=3.11"
dependencies = [
  "typer[all]",
  "python-dotenv",
]

[project.scripts]
my-app = "my_app.cli:app"
```

### 3.2 Ruff configuration (lint + format + type check)

Add Ruff configuration to the same `pyproject.toml`:

```toml
[tool.ruff]
target-version = "py311"
line-length = 100
src = ["src"]

[tool.ruff.lint]
select = ["E", "F", "I", "UP", "B", "ANN", "T20"]
ignore = []

[tool.ruff.format]
quote-style = "double"
indent-style = "space"
line-ending = "lf"

[tool.ruff.lint.per-file-ignores]
"src/my_app/__init__.py" = ["F401"]
```

If Ruff’s dedicated **type checker** is available in the environment, prefer:

```toml
[tool.ruff.typing]
strict = true
```

This signals intent for strict, type-safe Python. If `ruff typecheck` is not available, fall back to `ruff check` with strong lint rules (including `ANN` for annotations).

---

## 5. Typer-based CLI with .env + environment support

### 4.1 Core pattern

Use:

- `typer.Typer()` for the app.
- Type-hinted function parameters for CLI arguments/options.
- `typer.Option` with `envvar` for environment variable overrides.
- `python-dotenv`’s `load_dotenv()` to pull variables from `.env`.

Example `src/my_app/cli.py`:

```python
from __future__ import annotations

import os
from pathlib import Path
from typing import Annotated

import typer
from dotenv import load_dotenv

app = typer.Typer(help="My typed Typer CLI.")


def _load_env() -> None:
    project_root = Path(__file__).resolve().parents[2]
    env_path = project_root / ".env"
    if env_path.exists():
        load_dotenv(dotenv_path=env_path)


ConfigPath = Annotated[Path, typer.Option(help="Path to config file.", envvar="MY_APP_CONFIG")]
VerboseFlag = Annotated[bool, typer.Option("--verbose", "-v", help="Enable verbose output.")]
NameArg = Annotated[str, typer.Argument(help="Name to greet.")]


@app.command()
def greet(
    name: NameArg,
    config: ConfigPath | None = None,
    verbose: VerboseFlag = False,
) -> None:
    """
    Simple greeting command using typed arguments and options.
    """
    _load_env()

    effective_config = config or os.getenv("MY_APP_CONFIG")

    if verbose:
        typer.echo(f"Using config: {effective_config!r}")

    typer.echo(f"Hello, {name}!")


def main() -> None:
    app()


if __name__ == "__main__":
    main()
```

Key practices:

- Use `from __future__ import annotations` for postponed evaluation of type hints.
- Use `Annotated` + `typer.Argument` / `typer.Option` for clear, typed CLIs.
- Support both explicit CLI options and envvars via `envvar="MY_APP_CONFIG"`.
- Load `.env` once per process via `_load_env()`.

For more Typer patterns (subcommands, enums, paths, etc.), refer to the Typer docs:  
`https://typer.tiangolo.com/`.

---

## 6. Environment Variables and `.env`

Create `.env.example` at the project root:

```env
MY_APP_CONFIG=/path/to/config.toml
MY_APP_API_KEY=changeme
```

Guidelines:

- Encourage users to copy `.env.example` → `.env` and customize values.
- Do **not** commit `.env`; add it to `.gitignore`.

Example `.gitignore` entries:

```gitignore
.env
.venv
.python-version
.ruff_cache/
.uv/
__pycache__/
```

---

## 7. VS Code Debug Configuration

Create `.vscode/launch.json` to run the Typer app using `uv`:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Python: my-app (uv, Typer)",
      "type": "python",
      "request": "launch",
      "module": "my_app.cli",
      "justMyCode": true,
      "console": "integratedTerminal",
      "envFile": "${workspaceFolder}/.env",
      "args": [
        "greet",
        "World",
        "--verbose"
      ],
      "python": "uv"
    }
  ]
}
```

If the VS Code Python extension does not support `"python": "uv"` directly, use a wrapper shell configuration:

- Set `"module": "my_app.cli"` and ensure VS Code uses the `uv`-managed interpreter (e.g. via the Python extension’s interpreter selection).
- Alternatively, define a `debug` script in `pyproject.toml` and call it from a shell configuration.

Keep `envFile` pointing to `.env` so debug runs also honor environment-based configuration.

---

## 8. Commands for Development Workflow

Document the common commands in `README.md`:

```bash
# Create and sync environment
uv sync

# Run the CLI
uv run my-app greet "World"

# Or via Python module
uv run python -m my_app.cli greet "World"

# Lint
uv run ruff check .

# Format
uv run ruff format .

# Type check (if available)
uv run ruff typecheck .
```

Emphasize:

- Always run tools (lint, type check, format, tests) via `uv run` for reproducibility.
- Treat `ruff typecheck` (or strict `ruff check` rules) as required in CI.

---

## 9. Type-Safe Python Practices

When generating or editing code in this project:

- **Annotate all public functions and methods** with precise types.
- Avoid `Any` unless absolutely necessary; if used, justify or narrow it.
- Prefer explicit `Path` and `Literal` types where appropriate.
- Use `Annotated` for Typer parameters to keep help text close to types.
- Enable strict Ruff typing configuration (`[tool.ruff.typing] strict = true`) when available.

---

## 10. Minimal README Template

Provide a concise `README.md` skeleton:

```markdown
# My App

CLI application built with [Typer](https://typer.tiangolo.com/), managed with [uv](https://github.com/astral-sh/uv), and checked with [Ruff](https://github.com/astral-sh/ruff).

## Setup

```bash
uv sync
cp .env.example .env
```

## Usage

```bash
uv run my-app greet "World"
```

## Development

```bash
uv run ruff check .
uv run ruff format .
uv run ruff typecheck .
```
```

Keep the README concise, pointing to Typer docs for advanced CLI patterns.

