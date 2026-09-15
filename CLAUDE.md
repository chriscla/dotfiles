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

Detected via `{{ and (hasKey .chezmoi.kernel "osrelease") (contains "microsoft" (lower .chezmoi.kernel.osrelease)) }}`.
The `hasKey` guard is required — `.chezmoi.kernel` is an empty map on macOS, so
the unguarded form fails template execution with `map has no entry for key "osrelease"`.
On WSL2:
- VS Code/Cursor extension scripts exit early (editors live on Windows host)
- Binaries under `/mnt/c/` are Windows-side — don't install into them from WSL2

### SSH Agent (Bitwarden)

SSH keys are held by Bitwarden Desktop's agent, not as files on disk. `~/.ssh/config`
names one socket path, `~/.bitwarden-ssh-agent.sock`, on every platform:

- **macOS / native Linux** — Bitwarden Desktop creates that socket itself.
- **WSL2** — Bitwarden is a Windows app serving the named pipe
  `\\.\pipe\openssh-ssh-agent`. `dot_dotfile_extras/executable_bw-ssh-agent-relay.sh`
  relays it onto the same socket path with `socat` + `npiperelay.exe` (deps in
  `Brewfile.tmpl` and `scoop.json`), started from `.zshrc`.
- **Forwarded-agent hosts (murf)** — no Bitwarden, no socket. The `Match ... exec`
  guards in `config.tmpl` fail there, leaving `IdentityAgent` unset so ssh uses
  `$SSH_AUTH_SOCK`, i.e. the agent forwarded from the client.

Two non-obvious constraints:
- `IdentitiesOnly=yes` **requires** an explicit `IdentityFile`. With none, ssh falls
  back to the default `id_*` filenames and filters the agent down to keys matching
  those, silently discarding Bitwarden's key. Pointing `IdentityFile` at the `.pub`
  is enough — ssh uses it to select the key from the agent.
- The `.pub` files must deploy on untrusted machines too (they carry no secrets, and
  `.chezmoiignore` only excludes the private halves), otherwise agent forwarding to
  those machines cannot select a key.

#### Two GitHub identities

Bitwarden holds `ChrisCla Github Work` and `ChrisCla Github Personal`. Each machine
type gets **only its own public key**: `.chezmoiignore` drops
`id_github_personal.pub` on work machines and `id_github_work.pub` everywhere else.
`config.tmpl` then binds that key to `github.com` and emits a single matching alias
(`github-work` on work machines, `github-personal` otherwise), so a remote can name
the identity deliberately:

```sh
git remote set-url origin git@github-work:org/repo.git
```

The wrong identity therefore cannot be selected by mistake — its `.pub` is not on the
machine at all, and `IdentitiesOnly=yes` means ssh offers nothing else.

A third account, `voltron4lyfe`, uses the `github-v4lyfe` alias
(`id_github_v4lyfe.pub`) and is deployed on **personal machines only**. Its gate is
`{{ if not .personal }}` rather than `{{ if .work }}`/`{{ else }}`, so ephemeral and
cloud machines do not get it either. Both the `.pub` and the `Host` block are gated —
a `Host` block naming an undeployed key would fail confusingly rather than cleanly.

Net effect per machine type:

| machine | `.pub` files deployed | aliases |
|---|---|---|
| `work` | `id_github_work.pub` | `github.com`, `github-work` |
| `personal` | `id_github_personal.pub`, `id_github_v4lyfe.pub` | `github.com`, `github-personal`, `github-v4lyfe` |
| ephemeral (neither flag) | `id_github_personal.pub` | `github.com`, `github-personal` |

When adding a machine, `work` vs `personal` at `chezmoi init` is what picks the
GitHub identity. Getting it wrong deploys the wrong key reference.

#### Agent forwarding caveat

**Agent forwarding is all-or-nothing.** A forwarded socket exposes every key the
agent holds, and `ssh_config` cannot filter it — `IdentityFile`/`IdentitiesOnly`
govern only what is *offered for authentication*, not what the remote can reach
through the forwarded agent. Both GitHub keys are served by one Bitwarden agent, so
forwarding to murf does expose the work key to murf; this is a deliberate, accepted
tradeoff, mitigated by the per-machine key deployment above and Bitwarden's per-use
approval prompt. Do not attempt to fix it by adding `IdentitiesOnly` to a forwarded
host — that is not what the option does.

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
