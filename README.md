# dotfiles

> 工欲善其事，必先利其器。

Fish, Neovim (LazyVim), tmux, Alacritty, ranger and an optional i3/X11 desktop, all in the [Solarized Osaka](https://github.com/craftzdog/solarized-osaka.nvim) palette. Managed with [chezmoi](https://www.chezmoi.io/).

## Install

```sh
chezmoi init --apply m1ngsama/dotfiles
```

On Linux, chezmoi asks once whether to enable the i3/X11 profile. Preview changes with `chezmoi diff` before `chezmoi apply`.

Neovim installs its plugins on first start. `:Lazy restore` pins them to `lazy-lock.json`.

On Windows, import `keymap/capstoctrl.reg` to map Caps Lock to Control.

## Keys

| Where | Keys | Action |
| --- | --- | --- |
| tmux | `C-t` | Prefix |
| tmux | `prefix h/j/k/l` | Move between panes |
| tmux | `prefix \|` / `prefix -` | Split |
| tmux | `prefix g` | lazygit popup |
| Fish | `C-g` | Jump to a ghq repository with fzf |
| Neovim | `ss` / `sv` | Split |
| Neovim | `sh/sj/sk/sl` | Move between windows |
| i3 | `Super-Return` / `Super-d` | Terminal / rofi |

Optional tools are used when installed: eza, zoxide, ghq, fzf, lazygit, thefuck and lolcat.

## License

[MIT](LICENSE). Vendored files keep their licenses in `third_party/`.
