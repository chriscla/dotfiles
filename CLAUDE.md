# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A **chezmoi**-managed dotfiles repository. The `.chezmoiroot` file points to `home/` as the source root, so all chezmoi source files live under `home/`.

## Common Commands

```sh
chezmoi apply          # Apply dotfiles to the home directory
chezmoi diff           # Preview what would change
chezmoi update         # Pull upstream changes and apply
chezmoi edit <file>    # Edit a managed file (especially useful for encrypted files)
chezmoi add <file>     # Add a new file to chezmoi management
chezmoi data           # Show template data values (ephemeral, work, personal, trusted, etc.)
```

## Architecture

### Template Data Model

Configuration is driven by boolean flags set during `chezmoi init` (see `home/.chezmoi.toml.tmpl`):

- **`ephemeral`** -- cloud/VM/container instances; no secrets, no prompts
- **`headless`** -- no display (servers, CI)
- **`work`** / **`personal`** -- determines git identity, Brewfile packages, and which configs are installed
- **`trusted`** -- enables age encryption and SSH private key deployment (set automatically for work/personal)

These flags gate content throughout the repo via chezmoi's Go template syntax.

### Encryption

Encrypted files use **age** (filenames contain `encrypted_` prefix). The age identity key is bootstrapped by `run_onchange_before_decrypt-private-key.sh.tmpl`, which decrypts `home/key.txt.age` into `~/.config/chezmoi/key.txt`. Only trusted machines get encrypted content (controlled by `.chezmoiignore`).

### File Naming Conventions (chezmoi)

- `dot_` prefix maps to `.` in the target (e.g., `dot_zshrc` -> `.zshrc`)
- `private_` sets restrictive permissions
- `encrypted_` indicates age-encrypted content
- `executable_` makes the file executable
- `symlink_` creates a symlink
- `.tmpl` suffix means the file is a Go template processed with chezmoi's data
- `run_once_` / `run_onchange_` scripts execute during apply (once ever, or when content changes)
- `run_onchange_before_` / `run_onchange_after_` control ordering

### Platform Handling

- **macOS/Linux**: Homebrew packages via `home/dot_config/brew/Brewfile.tmpl`; zsh + Oh My Zsh + plugins via `.chezmoiexternal.toml`
- **Windows**: Scoop packages via `home/scoop.json` and `run_onchange_install-packages-windows.ps1.tmpl`
- **Linux-only packages**: `home/packages.txt` + `run_onchange_install-packages.sh.tmpl`
- Platform-specific files are excluded via conditionals in `home/.chezmoiignore`

### Git Identity

Git identity (name, work email, personal email) is stored **only** in the encrypted file `home/dot_config/chezmoi/encrypted_git-identity.json`. Templates in `encrypted_dot_gitconfig.tmpl.age`, `encrypted_dot_gitconfig-work.tmpl.age`, and `encrypted_dot_gitconfig-personal.tmpl.age` consume this data. The plaintext JSON is never installed to disk (excluded in `.chezmoiignore`).

### External Dependencies

`home/.chezmoiexternal.toml` pulls archives/files from GitHub: Oh My Zsh, zsh plugins (autosuggestions, syntax-highlighting, fzf-tab), oh-my-tmux, vim plugins, and iTerm2 color schemes (macOS only).

### Prompt

**Starship** (Rust-based, installed via Homebrew). Config in `home/dot_config/starship.toml.tmpl`. Init is cached at `$XDG_CACHE_HOME/starship/init.zsh` for speed.

### WSL2

Detected via `{{ contains "microsoft" (lower .chezmoi.kernel.osrelease) }}`. On WSL2:
- VS Code/Cursor extension scripts exit early (editors live on Windows host)
- Binaries under `/mnt/c/` are Windows-side — don't install into them from WSL2

### Zsh Performance

Warm startup target: **~80ms**. Key watchouts:
- **OMZ has no `.git` dir** (installed via archive, not git clone) — `git rev-parse HEAD` returns empty. This is normal; the empty `#omz revision:` fingerprint must stay consistent.
- **Never stub `compaudit`** — it causes zcompdump cache invalidation and ~250ms rebuild penalty every launch
- **zcompdump fpath fingerprint** — if fpath changes between launches, OMZ deletes and rebuilds the dump. Test with: `chezmoi apply && rm -f ~/.zcompdump* && zsh -i -c exit && time ZSH_DEBUGRC=1 zsh -i -c exit`
- **`dot_zshenv`** owns env vars (`XDG_*`, `EDITOR`, `VISUAL`, `ZSH`, `PATH`); `dot_zshrc.tmpl` owns interactive config only
- Fzf and Starship inits are cached under `$XDG_CACHE_HOME` with `-ot =binary` freshness checks

## Useful Debug Commands

```sh
time ZSH_DEBUGRC=1 zsh -i -c exit   # Profile zsh startup (zprof)
chezmoi execute-template < file.tmpl  # Render a template without applying
chezmoi data --format json            # Inspect all template data as JSON

## Development Guidelines
- Never check in secrets unless they are age encrypted_dot_gitconfig
- Don't hardcode hostnames
```
