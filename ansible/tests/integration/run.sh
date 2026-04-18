#!/usr/bin/env bash
#
# Integration harness: run the playbook, verify state, then re-run the
# playbook and assert it reports zero changes (idempotency check).

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
ANSIBLE_DIR="$(cd -- "$SCRIPT_DIR/../.." &>/dev/null && pwd)"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; exit 1; }

cd "$ANSIBLE_DIR"

log "Run 1/2: initial playbook run"
ansible-playbook -i inventory.ini playbook.yml \
  -e "git_user_name=CI Runner" -e "git_user_email=ci@example.com"

log "Post-run verification"
ansible-playbook -i inventory.ini tests/integration/verify.yml

log "Run 2/2: idempotency check"
IDEMPOTENCY_LOG="$(mktemp)"
trap 'rm -f "$IDEMPOTENCY_LOG"' EXIT
ansible-playbook -i inventory.ini playbook.yml \
  -e "git_user_name=CI Runner" -e "git_user_email=ci@example.com" \
  | tee "$IDEMPOTENCY_LOG"

if grep -E 'changed=[1-9]' "$IDEMPOTENCY_LOG" >/dev/null; then
  die "Idempotency check failed: second run reported changes."
fi

log "Integration suite passed."
