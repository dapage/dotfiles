#!/usr/bin/env sh

export DOTFILES_DIR="$HOME/.dotfiles"

cd $DOTFILES_DIR;

function updateBrewfile() {
    rm $DOTFILES_DIR/Brewfile && brew bundle dump;
}

function update() {
    cp $HOME/.zshrc $DOTFILES_DIR/.zshrc;
    cp $HOME/.profile $DOTFILES_DIR/.profile;

    if test -f $DOTFILES_DIR/"Brewfile"; then
        updateBrewfile;
    fi
}

if [ "$1" == "--force" -o "$1" == "-f" ]; then
	update;
else
	read -p "This may overwrite existing files in your home directory. Are you sure? (y/n) " -n 1;
	echo "";
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		update;
	fi;
fi;
unset doIt;