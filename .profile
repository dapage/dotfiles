#!/usr/bin/env sh
export DOTFILES_DIR="$HOME/.dotfiles"
for file in "$DOTFILES_DIR"/.{exports,functions,aliases,init,greeting}; do
    [ -r "$file" ] && [ -f "$file" ] && . "$file"
done
unset file
