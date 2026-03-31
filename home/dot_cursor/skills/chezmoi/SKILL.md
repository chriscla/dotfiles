---
name: chezmoi
description: Manage dotfiles with chezmoi. Use when working in a chezmoi source directory, editing dotfiles, adding new managed files, creating templates, or when the user mentions chezmoi, dotfiles, or home directory configuration.
---

# chezmoi

## Source State Naming

chezmoi encodes file attributes in source filenames. The source directory (default `~/.local/share/chezmoi`) maps to `~` via these transformations:

### Prefixes (order matters per target type)

| Prefix | Effect |
|--------|--------|
| `dot_` | Leading `.` in target (`dot_zshrc` -> `.zshrc`) |
| `private_` | Remove group/world permissions |
| `readonly_` | Remove write permissions |
| `empty_` | Keep file even if empty |
| `executable_` | Add executable permissions |
| `encrypted_` | Encrypted in source state |
| `exact_` | Remove unmanaged children (directories) |
| `external_` | Ignore attributes in children |
| `create_` | Only create if target doesn't exist |
| `modify_` | Script that modifies existing target (always overwrites without prompting) |
| `remove_` | Remove the target |
| `symlink_` | Create symlink |
| `run_` | Execute as script |
| `once_` | Run script only once ever |
| `onchange_` | Run script when contents change |
| `before_` | Run script before other updates |
| `after_` | Run script after other updates |
| `literal_` | Stop parsing prefixes |

### Suffixes

| Suffix | Effect |
|--------|--------|
| `.tmpl` | Process as Go template |
| `.literal` | Stop parsing suffixes |
| `.age` / `.asc` | Stripped from encrypted files |

### Prefix order by target type

| Target | Allowed prefix order |
|--------|---------------------|
| Directory | `remove_`, `external_`, `exact_`, `private_`, `readonly_`, `dot_` |
| Regular file | `encrypted_`, `private_`, `readonly_`, `empty_`, `executable_`, `dot_` |
| Create file | `create_`, `encrypted_`, `private_`, `readonly_`, `empty_`, `executable_`, `dot_` |
| Modify file | `modify_`, `encrypted_`, `private_`, `readonly_`, `executable_`, `dot_` |
| Script | `run_`, `once_` or `onchange_`, `before_` or `after_` |
| Symlink | `symlink_`, `dot_` |

### Examples

```
dot_zshrc                              -> ~/.zshrc
dot_zshrc.tmpl                         -> ~/.zshrc (templated)
private_dot_ssh/                       -> ~/.ssh/ (mode 0700)
encrypted_dot_gitconfig.tmpl.age       -> ~/.gitconfig (encrypted + templated)
run_once_install-brew.sh.tmpl          -> runs once, templated
run_onchange_after_configure.sh.tmpl   -> runs after apply when contents change
executable_dot_local/bin/myscript      -> ~/.local/bin/myscript (executable)
```

## Key Commands

```sh
chezmoi apply [--force]     # Apply source state to home (--force skips prompts)
chezmoi diff [target]       # Preview changes
chezmoi add <file>          # Add file to source state
chezmoi re-add [file]       # Update source from current target state
chezmoi edit <file>         # Edit managed file (handles encryption)
chezmoi data                # Show template data
chezmoi cat <file>          # Show target contents after templating
chezmoi chattr <attrs> <target>  # Change file attributes
chezmoi forget <target>     # Remove from management without deleting target
chezmoi managed             # List all managed files
chezmoi update              # Pull + apply
```

## Templates

Templates use Go's `text/template` syntax with chezmoi extensions. Available in any file with `.tmpl` suffix.

### Common template variables

- `.chezmoi.os` -- `"darwin"`, `"linux"`, `"windows"`
- `.chezmoi.arch` -- `"amd64"`, `"arm64"`
- `.chezmoi.hostname` -- machine hostname
- `.chezmoi.homeDir` -- home directory path
- `.chezmoi.osRelease` -- Linux distro info (`.id`, `.versionID`, etc.)
- Custom data from `.chezmoi.toml.tmpl` `[data]` section and `.chezmoidata.$FORMAT` files

### Template patterns

```
{{- if eq .chezmoi.os "darwin" }}
# macOS-only content
{{- end }}

{{- if .work }}
# Work machine content
{{- end }}

{{ .chezmoi.homeDir }}/.config/foo
```

## Special Files

| File | Purpose |
|------|---------|
| `.chezmoi.toml.tmpl` | Config template; defines data variables, encryption settings |
| `.chezmoidata.toml` | Static template data (merged into `.` namespace) |
| `.chezmoiexternal.toml` | External files/archives/git-repos to fetch |
| `.chezmoiignore` | Patterns to ignore (supports templates for OS conditionals) |
| `.chezmoiremove` | Patterns of files to remove from target |
| `.chezmoiroot` | Overrides source root (e.g., contents `home` makes `home/` the root) |

## Externals (.chezmoiexternal.toml)

Pull external files, archives, or git repos into the target state. The file is always treated as a template.

```toml
[".oh-my-zsh"]
    type = "archive"
    url = "https://github.com/ohmyzsh/ohmyzsh/archive/master.tar.gz"
    exact = true
    stripComponents = 1
    refreshPeriod = "168h"
    exclude = ["*.md", ".github/**"]

[".local/bin/tool"]
    type = "archive-file"
    url = "https://github.com/org/tool/releases/download/v1.0/tool-{{ .chezmoi.os }}-{{ .chezmoi.arch }}.tar.gz"
    path = "tool"
    executable = true
```

Types: `file`, `archive`, `archive-file`, `git-repo`. Use `refreshPeriod` for cache duration (e.g., `"168h"` = 1 week). Wrap in template conditionals for OS-specific externals.

## Ignore Patterns (.chezmoiignore)

Supports templates for conditional ignoring:

```
{{ if ne .chezmoi.os "darwin" }}
Library/
{{ end }}

{{ if not .trusted }}
.ssh/**
*.age
{{ end }}
```

## Working with Encrypted Files

- Source filenames contain `encrypted_` prefix and `.age` suffix
- Use `chezmoi edit <target>` to edit (decrypts, opens editor, re-encrypts)
- Encryption config (identity, recipient) lives in `.chezmoi.toml.tmpl`
- Gate encrypted files on a `trusted` flag in `.chezmoiignore`

## Common Workflows

**Add a new dotfile:**
```sh
chezmoi add ~/.config/tool/config.toml
# Creates home/dot_config/tool/config.toml in source
```

**Add a templated file:**
```sh
chezmoi add --template ~/.config/tool/config.toml
# Creates with .tmpl suffix; replace values with template expressions
```

**Change attributes (e.g., make executable):**
```sh
chezmoi chattr +executable ~/.local/bin/myscript
```

**Preview before applying:**
```sh
chezmoi diff
chezmoi apply --dry-run --verbose
```
