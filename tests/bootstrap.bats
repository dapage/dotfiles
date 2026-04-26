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

@test "run_brew_bundle: writes brew output to a log file on failure (so users can diagnose)" {
  stub_brew 1
  BOOTSTRAP_LOG_DIR="$TEST_TMP" run run_brew_bundle
  [ "$status" -eq 0 ]
  [[ "$output" == *"$TEST_TMP"* ]]
  ls "$TEST_TMP"/dotfiles-brew-*.log >/dev/null 2>&1
}

@test "clone_repo: skips when DOTFILES_DIR is already a valid git repo" {
  local repo_dir="$TEST_TMP/dotfiles-existing"
  mkdir -p "$repo_dir"
  ( cd "$repo_dir" && git init --quiet )
  DOTFILES_DIR="$repo_dir" run clone_repo
  [ "$status" -eq 0 ]
  [[ "$output" == *"already at"* ]]
  [[ "$output" != *"Cloning"* ]]
}

@test "clone_repo: dies when .git exists but is not a valid git repository" {
  local fake_dir="$TEST_TMP/dotfiles-corrupt"
  mkdir -p "$fake_dir/.git"
  DOTFILES_DIR="$fake_dir" run clone_repo
  [ "$status" -ne 0 ]
  [[ "$output" == *"not a valid git repo"* ]]
}

@test "clone_repo: invokes git clone when DOTFILES_DIR is absent" {
  local target="$TEST_TMP/dotfiles-not-yet"
  local stub_dir="$TEST_TMP/bin"
  local sentinel="$TEST_TMP/git-args"
  mkdir -p "$stub_dir"
  cat > "$stub_dir/git" <<EOF
#!/usr/bin/env bash
echo "\$@" > "$sentinel"
EOF
  chmod +x "$stub_dir/git"
  PATH="$stub_dir:$PATH"
  export PATH
  DOTFILES_DIR="$target" run clone_repo
  [ "$status" -eq 0 ]
  grep -q "clone --branch" "$sentinel"
  grep -q "$target" "$sentinel"
}

@test "install_ansible: skips when ansible-playbook is already on PATH" {
  local stub_dir="$TEST_TMP/bin"
  mkdir -p "$stub_dir"
  cat > "$stub_dir/ansible-playbook" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$stub_dir/ansible-playbook"
  cat > "$stub_dir/brew" <<'EOF'
#!/usr/bin/env bash
echo "FAIL: brew install must not be invoked when ansible is present" >&2
exit 99
EOF
  chmod +x "$stub_dir/brew"
  PATH="$stub_dir:/usr/bin:/bin"
  export PATH
  run install_ansible
  [ "$status" -eq 0 ]
  [[ "$output" == *"already installed"* ]]
}

@test "install_ansible: invokes brew install ansible when missing" {
  local stub_dir="$TEST_TMP/bin"
  local sentinel="$TEST_TMP/brew-args"
  mkdir -p "$stub_dir"
  cat > "$stub_dir/brew" <<EOF
#!/usr/bin/env bash
echo "\$@" > "$sentinel"
EOF
  chmod +x "$stub_dir/brew"
  PATH="$stub_dir:/usr/bin:/bin"
  export PATH
  run install_ansible
  [ "$status" -eq 0 ]
  grep -q "install ansible" "$sentinel"
}

@test "run_playbook: passes --ask-become-pass when not in CI" {
  local stub_dir="$TEST_TMP/bin"
  local sentinel="$TEST_TMP/playbook-args"
  mkdir -p "$stub_dir"
  cat > "$stub_dir/ansible-playbook" <<EOF
#!/usr/bin/env bash
echo "\$@" > "$sentinel"
EOF
  chmod +x "$stub_dir/ansible-playbook"
  PATH="$stub_dir:/usr/bin:/bin"
  export PATH
  run run_playbook
  [ "$status" -eq 0 ]
  grep -q -- '--ask-become-pass' "$sentinel"
}

@test "run_playbook: omits --ask-become-pass when CI=true" {
  local stub_dir="$TEST_TMP/bin"
  local sentinel="$TEST_TMP/playbook-args"
  mkdir -p "$stub_dir"
  cat > "$stub_dir/ansible-playbook" <<EOF
#!/usr/bin/env bash
echo "\$@" > "$sentinel"
EOF
  chmod +x "$stub_dir/ansible-playbook"
  PATH="$stub_dir:/usr/bin:/bin"
  export PATH
  CI=true run run_playbook
  [ "$status" -eq 0 ]
  ! grep -q -- '--ask-become-pass' "$sentinel"
}

@test "keep_sudo_alive: trap covers EXIT INT TERM HUP (signal-killed bootstraps don't leak the keepalive)" {
  # Static check on the source: testing the live trap would require
  # stubbing sudo and reading `trap -p` from a forked shell.
  local trap_line
  trap_line=$(grep -E '^[[:space:]]*trap .*EXIT' "$REPO_ROOT/bootstrap.sh")
  [ -n "$trap_line" ]
  [[ "$trap_line" == *INT* ]]
  [[ "$trap_line" == *TERM* ]]
  [[ "$trap_line" == *HUP* ]]
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
