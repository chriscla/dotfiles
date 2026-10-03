# Dotfiles (chezmoi)

This repository is managed with [chezmoi](https://www.chezmoi.io/). Use it to bootstrap a new machine and keep configs in sync.

**Source layout:** chezmoi source files live under [`home/`](home/) (see [`.chezmoiroot`](.chezmoiroot)).

---

## New machine: macOS or Linux

### 1. Prerequisites (install manually, in this order)

On a fresh machine these must exist **before** `chezmoi init` — chezmoi cannot bootstrap them for you on a trusted (work/personal) machine.

1. **Git** — on macOS, install the [Command Line Tools](https://developer.apple.com/library/archive/technotes/tn2339/_index.html):

   ```sh
   xcode-select --install
   ```

2. **Homebrew** — from [brew.sh](https://brew.sh/):

   ```sh
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

   Then follow the "Next steps" it prints to add `brew` to your `PATH` (e.g. `eval "$(/opt/homebrew/bin/brew shellenv)"`).

3. **Bitwarden Desktop** and the **Bitwarden CLI** (`bw`):

   ```sh
   brew install --cask bitwarden
   brew install bitwarden-cli
   ```

   - **Desktop** serves the SSH agent (`~/.bitwarden-ssh-agent.sock`) that holds the GitHub keys. Sign in and enable the SSH agent in its settings — this is what lets you clone the repo over SSH.
   - **CLI** is used by chezmoi's `bitwarden` template function (e.g. [`create_private_id_holiest.tmpl`](home/private_dot_ssh/create_private_id_holiest.tmpl)). Log in and unlock it in the shell you'll run chezmoi from:

     ```sh
     bw login
     export BW_SESSION="$(bw unlock --raw)"
     ```

### 2. Install chezmoi

```sh
brew install chezmoi
```

### 3. Initialize this repo and apply

Replace the URL with yours if you fork or use HTTPS:

```sh
chezmoi init --apply git@github.com:chriscla/dotfiles.git
```

(Equivalent SSH form: `ssh://git@github.com/chriscla/dotfiles.git`.)

**First run will:**

1. Prompt for **headless** and **ephemeral** when running interactively (non-TTY installs default to ephemeral with no secrets).
2. If **not** ephemeral, prompt for **machine type**: `work` or `personal`. Both enable **trusted** mode (age encryption, SSH private keys, and other encrypted material). See [`home/.chezmoi.toml.tmpl`](home/.chezmoi.toml.tmpl) for `work`, `personal`, and `trusted`.
3. When **trusted**, prompt for the **age passphrase** to decrypt [`key.txt.age`](home/key.txt.age) into `~/.config/chezmoi/key.txt` (see [`run_onchange_before_decrypt-private-key.sh.tmpl`](home/run_onchange_before_decrypt-private-key.sh.tmpl)).
4. **Bundle** Homebrew packages from [`Brewfile.tmpl`](home/dot_config/brew/Brewfile.tmpl).
5. Fetch **external** dependencies ([`.chezmoiexternal.toml`](home/.chezmoiexternal.toml): Oh My Zsh, tmux theme, Neovim plugins archives, etc.).

Optional **encrypted machine names** for template data: JSON in [`encrypted_private_dot_config_chezmoi_machine-names.json.age`](home/encrypted_private_dot_config_chezmoi_machine-names.json.age) (edit with `chezmoi edit`); merged into `hostnames` via [`home/.chezmoidata.toml.tmpl`](home/.chezmoidata.toml.tmpl) once `~/.config/chezmoi/key.txt` exists (often after the first successful trusted apply).

After that, use `chezmoi apply` whenever you pull changes, and `chezmoi edit` / `chezmoi add` as usual.

### Git identity (work vs personal)

This is driven by **chezmoi init** prompts (`work` vs `personal` → `.work` / `.personal` in [`home/.chezmoi.toml.tmpl`](home/.chezmoi.toml.tmpl)), not by hostnames.

- **Default `user.name` / `user.email`** for repos that are not under a more specific `includeIf` rule are set in [`home/dot_gitconfig.tmpl`](home/dot_gitconfig.tmpl): **work machines** use your work email, **personal machines** use your personal email.
- **Directory-specific overrides** (via [`home/encrypted_dot_gitconfig-work.tmpl.age`](home/encrypted_dot_gitconfig-work.tmpl.age) and [`home/encrypted_dot_gitconfig-personal.tmpl.age`](home/encrypted_dot_gitconfig-personal.tmpl.age)):
  - Repos under `~/work/` → work identity.
  - Repos under `/personal/` (and `~/code/` if you still use it) → personal identity.
  - The chezmoi source tree `~/.local/share/chezmoi/` → **personal** identity so commits **to this dotfiles repo** use your personal email.

**Secrets in git:** Your addresses are **not** stored in plaintext in this repository. They live only inside **age-encrypted** files (ciphertext in git). At apply time, values are merged into `~/.gitconfig` only; the encrypted file [`encrypted_private_dot_config_chezmoi_git-identity.json.age`](home/encrypted_private_dot_config_chezmoi_git-identity.json.age) is **not** installed as a separate plaintext JSON file (see [`.chezmoiignore`](home/.chezmoiignore)). Edit the secret with:

```sh
chezmoi edit encrypted_private_dot_config_chezmoi_git-identity.json.age
```

Expected JSON keys: `name`, `work_email`, `personal_email`. After changing, run `chezmoi apply`.

**Commits to the dotfiles repo:** Keep using your **personal** email for commits here. The `includeIf` for `~/.local/share/chezmoi/` makes Git use `~/.gitconfig-personal` for that tree; optionally also run `git config user.email …` once in this clone (your local `.git/config` is not part of the chezmoi source).

---

## New machine: Windows

1. Install [Scoop](https://scoop.sh/) if needed (the apply script can install it—see [`run_onchange_install-packages-windows.ps1.tmpl`](home/run_onchange_install-packages-windows.ps1.tmpl)).
2. Install chezmoi (e.g. via Scoop or the official installer).
3. `chezmoi init --apply` with this repository URL.

Package installs are driven by [`scoop.json`](home/scoop.json).

---

## Quick reference

| Task | Command |
|------|--------|
| Apply latest from the repo | `chezmoi apply` |
| See what would change | `chezmoi diff` |
| Pull upstream and apply | `chezmoi update` |

---

## Private notes

- Encrypted files use **age**; the identity path is set in [`.chezmoi.toml.tmpl`](home/.chezmoi.toml.tmpl) when `trusted` is true (after you choose **work** or **personal** on a non-ephemeral machine).
- **Work vs personal** and **GUI casks** are controlled by template data (`work`, `ephemeral`, etc.) in the same file—use prompts when you add a new machine instead of hard-coded hostnames.
