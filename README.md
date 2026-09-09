# dotfiles

Personal config for macOS and GCP Linux VMs.

## What's tracked

| File | What |
|------|------|
| `.zshrc` | Shell config, VM aliases, tunnel management |
| `.tmux.conf` | tmux with vim-tmux-navigator, OSC 52 clipboard |
| `.gitconfig` | Git aliases, SSH signing, credential helpers |
| `.vimrc` | Vim config (fallback when neovim unavailable) |
| `nvim/` | LazyVim-based neovim config |
| `lazygit/` | Lazygit config |
| `hunk/` | Hunk diff viewer config |
| `ssh_config` | SSH host aliases for EIQ GCP VMs (IAP tunnels) |
| `Obsidian/` | Obsidian app config |
| `install.sh` | Cross-platform bootstrap (Mac + Linux) |

## Setup

```bash
git clone git@github.com:njoselson/dotfiles.git ~/dotfiles
cd ~/dotfiles && bash install.sh
```

Machine-local secrets go in `~/.zshrc.local` (gitignored, template created by install).

## Flags

- `bash install.sh --claude-only` — skip packages/dotfiles, just set up Claude Code config
