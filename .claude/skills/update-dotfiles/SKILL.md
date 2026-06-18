---
name: update-dotfiles
description: Modify dotfiles to add tools, aliases, shell config, symlinks, or packages. Use when the user asks to update dotfiles, add a new tool or package to their setup, create aliases, change shell configuration, or modify install.conf.yaml.
---

# Update Dotfiles

Manage the dotbot-based dotfiles repo at `~/.dotfiles`.

## Repo Structure

```
~/.dotfiles/
├── install.conf.yaml     # Dotbot config: clean, link, shell sections
├── install                # Entry point (runs dotbot)
├── zshrc                  # Main zsh config (symlinked to ~/.zshrc)
├── bashrc                 # Main bash config (symlinked to ~/.bashrc)
├── bash_profile           # Bash login (symlinked to ~/.bash_profile)
├── gitconfig              # Git config (symlinked to ~/.gitconfig)
├── vimrc / init.vim       # Vim/Neovim config
├── .shell/
│   ├── aliases.sh         # Aliases and shell functions
│   ├── bootstrap.sh       # Environment vars, PATH, tool config
│   └── work-bookmarks.sh  # Project bookmarks and work-specific commands
├── .config/               # App configs (ghostty, zsh themes, vscode MCP)
├── .claude/               # Claude Code config + skills (symlinked to ~/.claude/)
├── .cursor/               # Cursor config (hooks)
├── .vscode/               # VS Code settings, keybindings, extensions list
├── install-iosevka.sh     # Font installer
└── install-swap.sh        # Swap setup script
```

Both `zshrc` and `bashrc` source `.shell/aliases.sh`, `.shell/bootstrap.sh`, and `.shell/work-bookmarks.sh`.

## install.conf.yaml Format

The file has three ordered sections:

### 1. clean
```yaml
- clean: ['~']
```

### 2. link — Symlink declarations
```yaml
- link:
    ~/.target:
        path: source_in_repo
        create: true    # create parent dirs if needed
        force: true     # overwrite existing
```

### 3. shell — Idempotent install commands
Each entry follows this pattern:
```yaml
    -
        command: command -v <binary> >/dev/null 2>&1 || <install command>
        description: Installing <tool>...
        quiet: false
        stdin: true
        stdout: true
        stderr: true
```

The `command -v` guard makes entries idempotent. For tools not in PATH, use `[ -d ... ]` or `[ -f ... ]` checks instead.

## Common Tasks

### Add a new CLI tool (apt)
Add to the `shell` section of `install.conf.yaml`:
```yaml
    -
        command: command -v <tool> >/dev/null 2>&1 || sudo apt-get install -y <package>
        description: Installing <tool>...
        quiet: false
        stdin: true
        stdout: true
        stderr: true
```
Place near related tools (dev tools together, GUI tools together, etc.).

### Add a new CLI tool (non-apt)
Follow the pattern of similar entries — curl a tarball, run an install script, etc. Always guard with an idempotency check.

### Add an alias or shell function
Edit `.shell/aliases.sh`. Group with related aliases. For work-specific bookmarks and project shortcuts, use `.shell/work-bookmarks.sh` instead.

### Add environment variables or PATH entries
Edit `.shell/bootstrap.sh` for env vars and PATH modifications that should apply to both bash and zsh.

### Add a new config file symlink
1. Add the source file to the repo
2. Add a link entry in `install.conf.yaml` under the `link` section

### Add a VS Code extension
Append the extension ID to `.vscode/extensions.txt`.

## Rules

- **Idempotency**: Every shell command must be safe to re-run. Always guard with `command -v`, `[ -d ... ]`, or `[ -f ... ]`.
- **Ordering in install.conf.yaml**: New shell entries go near related tools. Links go with related config groups.
- **Ubuntu/Debian**: The install script targets apt-based systems. Note this in descriptions if adding distro-specific commands.
- **No secrets**: Never add credentials, tokens, or passwords to dotfiles (`.envrc.private` files are gitignored per-project).
- **Test with `dfu`**: After changes, the user can run `dfu` (pulls and re-runs install) or `~/.dotfiles/install` directly.
