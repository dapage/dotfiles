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
HOMEBREW_PREFIXES="${HOMEBREW_PREFIXES:-/opt/homebrew /usr/local}"
XCODE_APP="${XCODE_APP:-/Applications/Xcode.app}"

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

_brew_at_prefix() {
  local prefix
  for prefix in $HOMEBREW_PREFIXES; do
    [ -x "$prefix/bin/brew" ] && return 0
  done
  return 1
}

install_homebrew() {
  # `command -v brew` alone is unreliable across re-runs: a fresh bash
  # invocation may not have brew on PATH even when it's installed at the
  # standard prefix. Falling back to a direct prefix probe keeps this
  # idempotent so we don't re-run the curl installer every time.
  if command -v brew >/dev/null 2>&1 || _brew_at_prefix; then
    log "Homebrew already installed."
  else
    log "Installing Homebrew."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  local prefix
  for prefix in $HOMEBREW_PREFIXES; do
    if [ -x "$prefix/bin/brew" ]; then
      eval "$("$prefix/bin/brew" shellenv)"
      return
    fi
  done
  die "Homebrew installation did not produce a brew binary in the expected location."
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

keep_sudo_alive() {
  # Cask and Mac App Store .pkg installers call `sudo installer` internally.
  # We run `brew bundle` straight from this script (rather than via Ansible's
  # command module) so stdin stays on a real TTY, but we still prime sudo
  # once up front and keep the timestamp fresh so each installer doesn't
  # re-prompt.
  if [ "${CI:-}" = "true" ]; then
    return
  fi
  log "Priming sudo (needed for Cask/MAS pkg installers)."
  sudo -v
  ( while true; do sudo -n true 2>/dev/null; sleep 60; kill -0 "$$" 2>/dev/null || exit; done ) &
  SUDO_KEEPALIVE_PID=$!
  trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true' EXIT
}

run_brew_bundle() {
  # Must run from this script (not Ansible) so Cask/MAS .pkg installers get
  # a real TTY for any sudo prompts not covered by the keepalive.
  if [ "${CI:-}" = "true" ]; then
    log "Skipping brew bundle in CI."
    return
  fi
  log "Running brew bundle against $DOTFILES_DIR/Brewfile."
  # A single failed cask/formula download (e.g. a flaky vendor CDN) makes
  # `brew bundle` exit non-zero. Without this guard, `set -e` would abort
  # before the Ansible playbook runs — meaning dotfile symlinks, macOS
  # defaults, oh-my-zsh, etc. would silently never get applied. Surface
  # the failure as a warning and let the rest of bootstrap continue;
  # the user can re-run `brew bundle` to retry transient failures.
  if ! brew bundle --file="$DOTFILES_DIR/Brewfile"; then
    warn "brew bundle reported failures (often a transient cask download)."
    warn "Continuing so the playbook still runs. Re-run later to retry:"
    warn "  brew bundle --file=$DOTFILES_DIR/Brewfile"
  fi
}

accept_xcode_license() {
  # Installing Xcode (via MAS) leaves the EULA unaccepted. Anything that
  # invokes the full Xcode toolchain (including Ansible fact-gathering on
  # some macOS versions) will then fail with rc=69 until the license is
  # accepted. `sudo xcodebuild -license accept` is the silent, idempotent
  # accept — safe to call when the license is already accepted, so we run
  # it unconditionally rather than relying on a state probe (the previous
  # `xcodebuild -version` short-circuit returned 0 when xcode-select
  # pointed at the Command Line Tools, silently skipping the accept and
  # letting ansible fail later with rc=69).
  if [ "${CI:-}" = "true" ]; then
    return
  fi
  if ! [ -d "$XCODE_APP" ]; then
    return
  fi
  log "Accepting Xcode license (idempotent)."
  sudo xcodebuild -license accept
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
  keep_sudo_alive
  run_brew_bundle
  accept_xcode_license
  run_playbook "$@"
  log "Done. Open a new Terminal window to pick up the new shell configuration."
}

# Only execute when run directly; allow tests to source this file to
# exercise individual functions without triggering main().
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
