#!/usr/bin/env bats
#
# Unit tests for bootstrap.sh shell functions. Sourced (not executed)
# so individual functions can be exercised in isolation with stubs.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  TEST_TMP="$(mktemp -d)"
  export DOTFILES_DIR="$TEST_TMP"
  touch "$TEST_TMP/Brewfile"
  unset CI

  # shellcheck disable=SC1091
  source "$REPO_ROOT/bootstrap.sh"
}

teardown() {
  rm -rf "$TEST_TMP"
}

stub_brew() {
  local exit_code="$1"
  local stub_dir="$TEST_TMP/bin"
  mkdir -p "$stub_dir"
  cat > "$stub_dir/brew" <<EOF
#!/usr/bin/env bash
exit $exit_code
EOF
  chmod +x "$stub_dir/brew"
  PATH="$stub_dir:$PATH"
  export PATH
}

@test "run_brew_bundle: returns 0 and stays quiet when brew bundle succeeds" {
  stub_brew 0
  run run_brew_bundle
  [ "$status" -eq 0 ]
  [[ "$output" != *"reported failures"* ]]
}

@test "run_brew_bundle: returns 0 and warns when brew bundle fails" {
  # Regression for the fresh-Mac bootstrap abort: a single flaky cask
  # download must not stop the script — otherwise the Ansible playbook
  # never runs and the machine is left unconfigured.
  stub_brew 1
  run run_brew_bundle
  [ "$status" -eq 0 ]
  [[ "$output" == *"brew bundle reported failures"* ]]
  [[ "$output" == *"Re-run later to retry"* ]]
}

@test "run_brew_bundle: skipped entirely when CI=true" {
  export CI=true
  stub_brew 1
  run run_brew_bundle
  [ "$status" -eq 0 ]
  [[ "$output" == *"Skipping brew bundle in CI"* ]]
}

@test "install_homebrew: detects brew at standard prefix even when not on PATH" {
  # Regression: bootstrap was reinstalling Homebrew on every run when the
  # caller's PATH didn't include /opt/homebrew/bin. The detection must
  # also check the standard prefixes directly.
  local prefix="$TEST_TMP/opt/homebrew"
  mkdir -p "$prefix/bin"
  cat > "$prefix/bin/brew" <<'EOF'
#!/usr/bin/env bash
# shellenv is the only subcommand install_homebrew calls on the brew
# binary; emit a no-op so eval succeeds.
[ "${1:-}" = "shellenv" ] && echo ":"
EOF
  chmod +x "$prefix/bin/brew"

  # Scrub PATH so command -v brew fails, and install a curl stub that
  # loudly fails the test if the Homebrew installer is invoked.
  local stub_dir="$TEST_TMP/bin"
  mkdir -p "$stub_dir"
  cat > "$stub_dir/curl" <<'EOF'
#!/usr/bin/env bash
echo "FAIL: curl invoked — Homebrew installer should not have run" >&2
exit 99
EOF
  chmod +x "$stub_dir/curl"
  PATH="$stub_dir:/usr/bin:/bin"
  export PATH

  HOMEBREW_PREFIXES="$prefix" run install_homebrew
  [ "$status" -eq 0 ]
  [[ "$output" == *"already installed"* ]]
  [[ "$output" != *"Installing Homebrew"* ]]
}

@test "accept_xcode_license: skips when Xcode.app missing" {
  XCODE_APP="$TEST_TMP/no-xcode" run accept_xcode_license
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "accept_xcode_license: skips in CI even when Xcode.app present" {
  mkdir -p "$TEST_TMP/Xcode.app"
  export CI=true
  XCODE_APP="$TEST_TMP/Xcode.app" run accept_xcode_license
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "accept_xcode_license: runs sudo xcodebuild -license accept when Xcode.app present" {
  # Regression: the previous xcodebuild -version short-circuit returned 0
  # when xcode-select pointed at the Command Line Tools, so the accept
  # step was silently skipped and ansible later failed with rc=69.
  mkdir -p "$TEST_TMP/Xcode.app"
  local stub_dir="$TEST_TMP/bin"
  local sentinel="$TEST_TMP/sudo-args"
  mkdir -p "$stub_dir"
  cat > "$stub_dir/sudo" <<EOF
#!/usr/bin/env bash
echo "\$@" > "$sentinel"
EOF
  chmod +x "$stub_dir/sudo"
  # Stub xcodebuild to exit 0 so the broken short-circuit (xcodebuild
  # -version succeeding ⇒ skip accept) would skip sudo. With the fix,
  # the short-circuit is gone and sudo runs unconditionally.
  cat > "$stub_dir/xcodebuild" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$stub_dir/xcodebuild"
  PATH="$stub_dir:$PATH"
  export PATH

  XCODE_APP="$TEST_TMP/Xcode.app" run accept_xcode_license
  [ "$status" -eq 0 ]
  [ -f "$sentinel" ]
  grep -q 'xcodebuild -license accept' "$sentinel"
}
