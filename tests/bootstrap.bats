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
