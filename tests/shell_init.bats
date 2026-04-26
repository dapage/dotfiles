#!/usr/bin/env bats
#
# Structural checks on shell init files. These guard against bugs that
# only show up at terminal-launch time (where adding live integration
# tests would be flaky and platform-bound).

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

@test ".zprofile must not source .zshrc (causes duplicate init on login+interactive shells)" {
  # Regression: macOS Terminal opens shells as both login AND interactive,
  # so zsh runs .zprofile then .zshrc. If .zprofile sources .zshrc, the
  # whole .profile / .init / .greeting chain runs twice — two ssh-agent
  # PIDs, two banners, two fortunes per terminal window.
  run grep -nE '(^|[^a-zA-Z_])(source|\.)[[:space:]]+[^[:space:]]*\.zshrc' "$REPO_ROOT/.zprofile"
  [ "$status" -ne 0 ]
}
