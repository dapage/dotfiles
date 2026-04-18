# dotfiles

One-shot MacBook bootstrap powered by Ansible.

## Quick start (new Mac)

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/dapage/dotfiles/main/bootstrap.sh)"
```

Or, after cloning:

```sh
git clone https://github.com/dapage/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./bootstrap.sh
```

`bootstrap.sh` installs Xcode Command Line Tools, Homebrew, Ansible, the
required Galaxy collections, then runs `ansible/playbook.yml`.

## What the playbook does

| Tag | Task |
|---|---|
| `xcode` | Install Xcode Command Line Tools |
| `brew` | Ensure Homebrew is present and updated |
| `bundle` | Run `brew bundle` against the repo's `Brewfile` |
| `omz` | Install Oh My Zsh (unattended, keeps repo `.zshrc`) |
| `dirs` | Create `~/Developer`, `~/Developer/{public,private}`, `~/Applications` |
| `dotfiles` | Symlink shell configs from the repo into `$HOME` |
| `macos` | Apply macOS `defaults` (dock autohide, autocorrect off, scroll dir) |
| `git` | Configure git user, default branch, pull behavior |

Scoped runs:

```sh
ansible-playbook ansible/playbook.yml --tags macos
ansible-playbook ansible/playbook.yml --tags dotfiles --check --diff
```

## Updating `Brewfile` from a running system

```sh
./update.sh
```

Rewrites the repo's `Brewfile` from `brew bundle dump`.

## Testing

Unit tests (Linux-friendly, no Mac required):

```sh
ansible-playbook ansible/tests/unit/test_syntax.yml
ansible-playbook ansible/tests/unit/test_dotfiles_list.yml
ansible-playbook ansible/tests/unit/test_brewfile.yml
```

Integration suite (macOS only):

```sh
ansible/tests/integration/run.sh
```

Runs the playbook, verifies post-state, then re-runs to confirm
idempotency (`changed=0`).

## CI

- `.github/workflows/lint.yml` — ansible-lint, yamllint, shellcheck, syntax-check (Ubuntu, every push/PR)
- `.github/workflows/unit-tests.yml` — unit playbooks (Ubuntu, every push/PR)
- `.github/workflows/integration-macos.yml` — full bootstrap + verify + idempotency (macos-14, PR to main + weekly)

## Branching

- `main` — release branch; what fresh MacBooks pull.
- `develop` — integration branch; feature branches merge here first.
- feature branches — branch from `develop`, PR into `develop`.

## Legacy

`install.sh` is deprecated in favor of `bootstrap.sh` but kept for
muscle memory. `.macos` has been migrated into
`ansible/tasks/macos_defaults.yml`.
