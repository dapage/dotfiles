#!/usr/bin/env bats
#
# Structural checks on shell init files. These guard against bugs that
# only show up at terminal-launch time (where adding live integration
# tests would be flaky and platform-bound).

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  TEST_TMP="$(mktemp -d)"
}

teardown() {
  rm -rf "$TEST_TMP"
}

# Source .zshrc inside zsh with $OSTYPE faked, then print the resulting
# plugins array. We stub $ZSH/oh-my-zsh.sh and $HOME/.profile so sourcing
# .zshrc doesn't try to actually load Oh My Zsh or the user's profile.
plugins_for_ostype() {
  local ostype="$1"
  local fake_home="$TEST_TMP/home"
  local fake_zsh="$fake_home/.oh-my-zsh"
  mkdir -p "$fake_zsh"
  : > "$fake_zsh/oh-my-zsh.sh"
  : > "$fake_home/.profile"
  HOME="$fake_home" zsh -c "OSTYPE='$ostype'; source '$REPO_ROOT/.zshrc'; print -r -- \${plugins[@]}"
}

@test ".zprofile must not source .zshrc (causes duplicate init on login+interactive shells)" {
  # Regression: macOS Terminal opens shells as both login AND interactive,
  # so zsh runs .zprofile then .zshrc. If .zprofile sources .zshrc, the
  # whole .profile / .init / .greeting chain runs twice — two ssh-agent
  # PIDs, two banners, two fortunes per terminal window.
  run grep -nE '(^|[^a-zA-Z_])(source|\.)[[:space:]]+[^[:space:]]*\.zshrc' "$REPO_ROOT/.zprofile"
  [ "$status" -ne 0 ]
}

@test "base plugins load on every OS" {
  for ostype in darwin24.0 linux-gnu cygwin msys; do
    result="$(plugins_for_ostype "$ostype")"
    for plugin in git zsh-autosuggestions zsh-syntax-highlighting zsh-completions zsh-history-substring-search; do
      [[ " $result " == *" $plugin "* ]] || { echo "missing $plugin under OSTYPE=$ostype: $result"; return 1; }
    done
  done
}

@test "macOS adds macos and brew plugins" {
  result="$(plugins_for_ostype darwin24.0)"
  [[ " $result " == *" macos "* ]] || { echo "got: $result"; return 1; }
  [[ " $result " == *" brew "* ]]  || { echo "got: $result"; return 1; }
}

@test "Linux does not load macOS-only plugins" {
  result="$(plugins_for_ostype linux-gnu)"
  [[ " $result " != *" macos "* ]] || { echo "got: $result"; return 1; }
  [[ " $result " != *" brew "* ]]  || { echo "got: $result"; return 1; }
}
