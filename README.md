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
| `brew` | Ensure Homebrew is present and updated |
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

### Updating git identity

`user.name` / `user.email` are only prompted for when unset. To change
them later, pass overrides:

```sh
ansible-playbook ansible/playbook.yml --tags git \
  -e git_user_name="New Name" -e git_user_email="new@example.com"
```

## Updating `Brewfile` from a running system

```sh
./update.sh
```

Rewrites the repo's `Brewfile` from `brew bundle dump`. Review the
diff before committing. (Not to be confused with `bin/update`, which
the `update` shell alias calls to run all package-manager updates.)

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
- `.github/workflows/bootstrap-macos.yml` — `bootstrap.sh --check` end-to-end (macos-14, PR to main/develop + weekly)
- `.github/workflows/integration-macos.yml` — full playbook + verify + idempotency (macos-14, PR to main + weekly)

## Branching

- `main` — release branch; what fresh MacBooks pull.
- `develop` — integration branch; feature branches merge here first.
- feature branches — branch from `develop`, PR into `develop`.

## Legacy

`.macos` has been migrated into `ansible/tasks/macos_defaults.yml`.
