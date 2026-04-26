#!/usr/bin/env bats
#
# Regression guards on supply-chain pinning. These prevent silent
# unpinning of third-party code that loads into every shell or runs
# as part of the playbook.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

@test "M1: oh_my_zsh.yml does not curl|sh the upstream installer" {
  # Cloning at a pinned SHA via the git module is the supported pattern;
  # curl|sh-ing master is what we're guarding against re-introducing.
  run grep -nE 'curl[[:space:]]+(-[[:alpha:]]+[[:space:]]+)*https?://' "$REPO_ROOT/ansible/tasks/oh_my_zsh.yml"
  [ "$status" -ne 0 ]
}

@test "M1: oh_my_zsh.yml pins ohmyzsh to a specific commit SHA" {
  grep -qE '^[[:space:]]+version:[[:space:]]+[0-9a-f]{40}' "$REPO_ROOT/ansible/tasks/oh_my_zsh.yml"
}

@test "M2: every zsh plugin in zsh_plugins.yml has a 40-char SHA pin" {
  # Five plugins listed; each must have a `version:` line with a SHA.
  local n
  n=$(grep -cE '^[[:space:]]+version:[[:space:]]+[0-9a-f]{40}' "$REPO_ROOT/ansible/tasks/zsh_plugins.yml")
  [ "$n" -eq 5 ]
}

@test "M3: requirements.yml caps community.general's upper bound" {
  # Must contain an upper bound (`<N.0.0` form). The previous bare
  # `>=7.0.0` would silently accept a future major version that
  # changes osx_defaults / homebrew module signatures.
  grep -qE 'community\.general' "$REPO_ROOT/ansible/requirements.yml"
  grep -qE '<[0-9]+\.[0-9]+\.[0-9]+' "$REPO_ROOT/ansible/requirements.yml"
}
