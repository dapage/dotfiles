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

# --- L-series robustness ---

@test "L1: .profile quotes \$DOTFILES_DIR in the source-files glob" {
  # Unquoted vars in the for loop break if DOTFILES_DIR contains spaces
  # or shell metacharacters.
  grep -qE 'for file in "\$DOTFILES_DIR"' "$REPO_ROOT/.profile"
}

@test "L2: .greeting uses command -v, not the deprecated which" {
  run grep -nE '^[[:space:]]*which[[:space:]]' "$REPO_ROOT/.greeting"
  [ "$status" -ne 0 ]
  grep -q 'command -v' "$REPO_ROOT/.greeting"
}

@test "L3: .init does not unconditionally eval ssh-agent on every shell" {
  # The bare `eval "$(ssh-agent -s)"` would fork a fresh agent per shell.
  # Whatever guard we use must come before the eval line.
  ! grep -qE '^[[:space:]]*eval[[:space:]]+"\$\(ssh-agent[[:space:]]+-s\)"[[:space:]]*$' "$REPO_ROOT/.init"
}

# --- H7: infisical-env loads Infisical machine-identity creds from 1Password ---

# Extract just the infisical-env function body so secret-shape checks are
# scoped to it (avoids false positives from unrelated hex elsewhere in
# .functions, e.g. a future function that references a git SHA).
infisical_env_body() {
  awk '/^function infisical-env\(\)/,/^}/' "$REPO_ROOT/.functions"
}

@test "H7.a: .functions defines infisical-env" {
  grep -qE '^function infisical-env\(\)' "$REPO_ROOT/.functions"
}

@test "H7.b: infisical-env reads each secret via op (literals would fail this)" {
  # If someone "fixes" a broken op call by pasting the raw client ID /
  # secret / project ID, the $(op read ...) shape goes away and this fails.
  # That's the regression we care about — not the broader "any hex in the
  # file" check, which would false-positive on git SHAs.
  local body
  body="$(infisical_env_body)"
  echo "$body" | grep -qE 'CLIENT_ID=\$\(op read "op://Private/infisical-iac-runner/'
  echo "$body" | grep -qE 'CLIENT_SECRET=\$\(op read "op://Private/infisical-iac-runner/'
  echo "$body" | grep -qE 'TF_VAR_infisical_project_id=\$\(op read "op://Private/infisical-iac-runner/'
}

@test "H7.c: infisical-env exports each documented env var" {
  # Defense in depth against accidental deletion of one export line during
  # a future refactor. Separate assertions (not a `grep -c` count) so the
  # failure message names the missing var.
  local body
  body="$(infisical_env_body)"
  echo "$body" | grep -qE '^[[:space:]]*export INFISICAL_API_URL='
  echo "$body" | grep -qE '^[[:space:]]*export INFISICAL_UNIVERSAL_AUTH_CLIENT_ID='
  echo "$body" | grep -qE '^[[:space:]]*export INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET='
  echo "$body" | grep -qE '^[[:space:]]*export TF_VAR_infisical_project_id='
  echo "$body" | grep -qE '^[[:space:]]*export INFISICAL_PROJECT_ID='
}

@test "H7.d: Brewfile installs 1password-cli (the op binary)" {
  # infisical-env hard-depends on `op`. The cask "1password" installs the
  # GUI app only; the CLI is a separate package — Homebrew ships it as a
  # cask, but accept the formula form too in case upstream changes.
  grep -qE '^(brew|cask) "1password-cli"' "$REPO_ROOT/Brewfile"
}
