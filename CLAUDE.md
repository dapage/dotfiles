# CLAUDE.md

Guidance for Claude Code (and humans) working in this repo.

## Project goal: cross-OS dotfiles

These dotfiles are intended to work on every OS the repo owner uses —
macOS, Linux, and Windows (under Git Bash / MSYS2 / WSL, since native
Windows zsh is not a target). When adding behavior:

- Prefer logic that works everywhere over macOS-only shortcuts.
- When something genuinely is OS-specific (e.g. `defaults write`, Homebrew,
  `systemd`), gate it on `$OSTYPE` or a capability check (`(( $+commands[brew] ))`)
  rather than assuming the host.
- The macOS bootstrap path (`bootstrap.sh` + Ansible) is the most
  thoroughly tested today; Linux/Windows parity is a direction of travel,
  not a current guarantee — call out gaps when you see them.

## Test-driven development

This repo follows TDD. **Write the test first.**

1. **Red** — Write a test that fails for the right reason (reproduces the bug
   for fixes, asserts the new behavior for features).
2. **Green** — Make the smallest change that turns the test green.
3. **Refactor** — Clean up while tests stay green.

Every bug fix lands with a regression test. Every behavior change lands with
a test that would have failed before the change. The only PRs that may skip
tests are doc-only or comment-only changes.

When fixing a bug, prove the test catches it: temporarily revert the fix and
confirm the new test fails, then re-apply the fix and confirm it passes.

## Where tests live

| Suite | Location | Runner |
|---|---|---|
| `bootstrap.sh` shell unit tests | `tests/*.bats` | `bats` |
| Ansible playbook unit tests (Linux-friendly) | `ansible/tests/unit/*.yml` | `ansible-playbook` |
| Full playbook + verify (macOS) | `ansible/tests/integration/` | `./run.sh` |

Run locally:

```sh
bats tests/bootstrap.bats
ansible-playbook ansible/tests/unit/test_syntax.yml
ansible-playbook ansible/tests/unit/test_dotfiles_list.yml
ansible-playbook ansible/tests/unit/test_brewfile.yml
ansible/tests/integration/run.sh   # macOS only
```

CI runs all unit suites on every push/PR
(`.github/workflows/{lint,unit-tests,bootstrap-macos,integration-macos}.yml`).

## Writing `bootstrap.sh` tests

`bootstrap.sh` is sourceable: `main "$@"` is guarded by `BASH_SOURCE` so tests
can `source` the file and exercise individual functions. Stub external
commands by prepending a `$TEST_TMP/bin` directory to `PATH`. See
`tests/bootstrap.bats` for the pattern.

## Branching

- `main` — release branch; what fresh MacBooks pull via the curl one-liner.
- `develop` — integration branch.
- Feature branches — branch from `develop`, PR into `develop`.

Never push directly to `main` or `develop`.

## Sensitive changes that warrant extra care

- `bootstrap.sh` runs once on a brand-new Mac with no prior dotfile state.
  A bug here means the user's shell, dotfiles, and macOS defaults silently
  don't get applied. Test failure paths, not just the happy path.
- `Brewfile` changes: don't drop entries without confirming with the
  repo owner; `update.sh` regenerates from the current system.
- Anything under `ansible/tasks/macos_defaults.yml` changes the user's
  desktop behavior. Prefer additive changes; document overrides.
