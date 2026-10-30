# dotfiles

The repository mirrors `$HOME`. `install.sh` symlinks every file under the given paths into place and skips files that already exist. Without arguments it links `.config`.

```sh
git clone https://github.com/m1ngsama/dotfiles ~/code/github/m1ngsama/dotfiles
~/code/github/m1ngsama/dotfiles/install.sh
~/code/github/m1ngsama/dotfiles/install.sh .xinitrc .xprofile .Xresources .Xmodmap   # Arch with i3
```

`windows/capstoctrl.reg` remaps Caps Lock to Ctrl on Windows and is applied by hand. `licenses/` holds the licenses of vendored code.
