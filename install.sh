#!/usr/bin/env sh
#
# DEPRECATED: prefer ./bootstrap.sh, which installs Xcode CLT, Homebrew,
# Ansible, and runs the full setup playbook. This script is kept for
# backwards compatibility and only copies .zshrc and .profile.

cd $HOME;

function doIt() {
    cp .zshrc $HOME/.zshrc
    cp .profile $HOME/.profile
}

if [ "$1" == "--force" -o "$1" == "-f" ]; then
	doIt;
else
	read -p "This may overwrite existing files in your home directory. Are you sure? (y/n) " -n 1;
	echo "";
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		doIt;
	fi;
fi;
unset doIt;