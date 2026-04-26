#!/usr/bin/env bats
#
# Static-grep guards on shipped dotfile content. These catch regressions
# that only show up at function-invocation or shell-startup time, where
# adding live integration tests would be flaky and platform-bound.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

# --- H1: .functions cleanup ---

@test "H1.a: .functions shebang is valid (not #!/bin/env)" {
  # /bin/env does not exist on macOS; the canonical form is /usr/bin/env.
  run head -1 "$REPO_ROOT/.functions"
  [[ "$output" != "#!/bin/env"* ]]
}

@test "H1.b: .functions does not reference Python 2 SimpleHTTPServer" {
  # SimpleHTTPServer was removed in Python 3.
  run grep -n 'SimpleHTTPServer' "$REPO_ROOT/.functions"
  [ "$status" -ne 0 ]
}

@test "H1.c: .functions does not hardcode 'en1' for default interface" {
  # Wi-Fi has been en0 on most Macs for years; en1 silently returns empty.
  run grep -n 'getifaddr en1' "$REPO_ROOT/.functions"
  [ "$status" -ne 0 ]
}

@test "H1.d: .functions does not invoke pygmentize (not in Brewfile)" {
  run grep -n 'pygmentize' "$REPO_ROOT/.functions"
  [ "$status" -ne 0 ]
}

@test "H1.e: .functions does not invoke subl (Sublime Text not installed)" {
  run grep -nE '\bsubl\b' "$REPO_ROOT/.functions"
  [ "$status" -ne 0 ]
}

# --- H2: DEVELOPER_DIR / DEVELOPER_DIRECTORY ---

@test "H2.a: .exports does not export DEVELOPER_DIR (Apple-reserved env var)" {
  # xcrun, xcodebuild, xcode-select all read DEVELOPER_DIR; clobbering it
  # to ~/Developer breaks Xcode tooling in subtle ways.
  run grep -nE '^export DEVELOPER_DIR=' "$REPO_ROOT/.exports"
  [ "$status" -ne 0 ]
}

@test "H2.b: .exports does not export DEVELOPER_DIRECTORY (redundant)" {
  run grep -nE '^export DEVELOPER_DIRECTORY=' "$REPO_ROOT/.exports"
  [ "$status" -ne 0 ]
}

# --- H3: bash/zsh dotfiles-dir env var consistency ---

@test "H3.a: .bash_profile does not reference DOTFILES_HOME" {
  # bash and zsh sessions must agree on env var names; canonical is DOTFILES_DIR
  # (matches .profile and bootstrap.sh).
  run grep -n 'DOTFILES_HOME' "$REPO_ROOT/.bash_profile"
  [ "$status" -ne 0 ]
}

@test "H3.b: .bash_profile uses DOTFILES_DIR" {
  grep -q 'DOTFILES_DIR' "$REPO_ROOT/.bash_profile"
}

# --- H4: workspace dirs out of PATH ---

@test "H4: .exports PATH lines do not include workspace dirs" {
  # Workspace dirs (~/Developer, ~/Developer/public, ~/Developer/private,
  # ~/.dotfiles) hold projects, not executables. Putting them in PATH lets
  # any random file dropped in shadow system commands.
  run grep -nE '^export PATH=.*\$(DEV_DIR|DEVELOPER_DIR|PUBLIC_DEV_DIR|PRIVATE_DEV_DIR|DOTFILES_REPO|DOTFILES_DIR)' "$REPO_ROOT/.exports"
  [ "$status" -ne 0 ]
}

# --- H5: colorls reference removed ---

@test "H5: .aliases does not reference colorls (not in Brewfile)" {
  run grep -n 'colorls' "$REPO_ROOT/.aliases"
  [ "$status" -ne 0 ]
}

# --- H6: update alias is fail-loud (not a `;`-chain) ---

@test "H6.a: bin/update script exists and is executable" {
  [ -x "$REPO_ROOT/bin/update" ]
}

@test "H6.b: update alias delegates to bin/update (not an inline ; chain)" {
  grep -qE "^alias update=" "$REPO_ROOT/.aliases"
  run grep -nE "^alias update='[^']*;[^']*;" "$REPO_ROOT/.aliases"
  [ "$status" -ne 0 ]
}
