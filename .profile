#!/usr/bin/env sh
for file in $HOME/.{exports,functions,aliases,init,greeting}; do
    [ -r "$file" ] && [ -f "$file" ] && source "$file"
done
unset file
