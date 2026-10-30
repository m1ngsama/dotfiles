#!/bin/sh
set -eu
cd "$(dirname "$0")"
[ $# -gt 0 ] || set -- .config

for path; do
  find "$path" -type f ! -name .DS_Store | while IFS= read -r file; do
    src=$PWD/$file
    dest=$HOME/$file
    if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
      continue
    fi
    if [ -e "$dest" ] || [ -L "$dest" ]; then
      echo "skip $dest: already exists" >&2
      continue
    fi
    mkdir -p "$(dirname "$dest")"
    ln -s "$src" "$dest"
  done
done
