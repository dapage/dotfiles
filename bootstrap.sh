#!/usr/bin/env bash
#
# bootstrap.sh — one-shot MacBook setup.
#
# Usage:
#   ./bootstrap.sh                  # full run (interactive sudo prompt)
#   ./bootstrap.sh --check          # Ansible dry-run
#   ./bootstrap.sh --tags macos     # scoped run
#
# Can be curl-piped on a fresh Mac:
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/dapage/dotfiles/main/bootstrap.sh)"

set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
DOTFILES_REPO_URL="${DOTFILES_REPO_URL:-https://github.com/dapage/dotfiles.git}"
DOTFILES_BRANCH="${DOTFILES_BRANCH:-main}"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
die() { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; exit 1; }

require_macos() {
  [ "$(uname -s)" = "Darwin" ] || die "bootstrap.sh only supports macOS."
}

install_xcode_clt() {
  if xcode-select -p >/dev/null 2>&1; then
    log "Xcode Command Line Tools already installed."
    return
  fi
  log "Installing Xcode Command Line Tools — a GUI dialog will appear. Click Install and wait for it to finish."
  xcode-select --install || true
  until xcode-select -p >/dev/null 2>&1; do
    sleep 10
  done
  log "Xcode Command Line Tools ready."
}

install_homebrew() {
  if command -v brew >/dev/null 2>&1; then
    log "Homebrew already installed."
  else
    log "Installing Homebrew."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  else
    die "Homebrew installation did not produce a brew binary in the expected location."
  fi
}

clone_repo() {
  if [ -d "$DOTFILES_DIR/.git" ]; then
    log "Dotfiles repo already at $DOTFILES_DIR."
    return
  fi
  log "Cloning $DOTFILES_REPO_URL into $DOTFILES_DIR."
  git clone --branch "$DOTFILES_BRANCH" "$DOTFILES_REPO_URL" "$DOTFILES_DIR"
}

install_ansible() {
  if command -v ansible-playbook >/dev/null 2>&1; then
    log "Ansible already installed."
  else
    log "Installing Ansible via Homebrew."
    brew install ansible
  fi
}

install_collections() {
  log "Installing Ansible Galaxy collections."
  ansible-galaxy collection install -r "$DOTFILES_DIR/ansible/requirements.yml"
}

run_playbook() {
  log "Running Ansible playbook."
  local become_flag=()
  if [ "${CI:-}" = "true" ]; then
    become_flag=()
  else
    become_flag=(--ask-become-pass)
  fi
  ansible-playbook \
    -i "$DOTFILES_DIR/ansible/inventory.ini" \
    "$DOTFILES_DIR/ansible/playbook.yml" \
    ${become_flag[@]+"${become_flag[@]}"} \
    "$@"
}

main() {
  require_macos
  install_xcode_clt
  install_homebrew
  clone_repo
  install_ansible
  install_collections
  run_playbook "$@"
  log "Done. Open a new Terminal window to pick up the new shell configuration."
}

main "$@"
