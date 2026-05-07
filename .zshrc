export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="robbyrussell"

plugins=(git zsh-autosuggestions zsh-syntax-highlighting zsh-completions zsh-history-substring-search)

case "$OSTYPE" in
  darwin*)    plugins+=(macos brew) ;;
  linux-gnu*) plugins+=(systemd) ;;
esac

source $ZSH/oh-my-zsh.sh
source $HOME/.profile