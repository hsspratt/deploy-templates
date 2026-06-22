#!/usr/bin/env bash
#
# pi-deploy.sh — pull-based deploy for ONE project on the Pi.
#
# Usage:   pi-deploy.sh <project>
# Driven by the templated systemd unit pi-deploy@<project>.timer.
#
# Reads ~/deploy/registry/<project>.conf for: REPO, SERVICE, TEST_CMD, BRANCH.
#
# Safety model (the "school of thought"):
#   * Pull-based only. Nothing inbound; GitHub can never run code on the Pi.
#   * Operates on a CLEAN deploy clone (~/deploy/<project>), never your dev dir.
#   * Refuses to run if that clone is dirty (protects accidental local edits).
#   * Tests the NEW commit in an isolated worktree BEFORE promoting it.
#   * On test failure it stays on the last-known-good commit — the bot keeps
#     running the version that last passed.
#
set -euo pipefail

PROJECT="${1:?usage: pi-deploy.sh <project>}"
DEPLOY_ROOT="${DEPLOY_ROOT:-$HOME/deploy}"
CONF="$DEPLOY_ROOT/registry/$PROJECT.conf"

log() { echo "$(date -Is) pi-deploy[$PROJECT] $*"; }

[[ -f "$CONF" ]] || { log "ERROR: no config at $CONF"; exit 1; }
# shellcheck disable=SC1090
source "$CONF"

: "${REPO:?REPO not set in $CONF}"
: "${SERVICE:?SERVICE not set in $CONF}"
BRANCH="${BRANCH:-main}"
TEST_CMD="${TEST_CMD:-}"
CLONE="$DEPLOY_ROOT/$PROJECT"

# --- First run: create the clean deploy clone -------------------------------
if [[ ! -d "$CLONE/.git" ]]; then
  log "first run: cloning $REPO -> $CLONE"
  git clone --branch "$BRANCH" "$REPO" "$CLONE"
fi

cd "$CLONE"

# --- Guard: never deploy over local edits -----------------------------------
if [[ -n "$(git status --porcelain)" ]]; then
  log "ERROR: deploy clone is dirty. Refusing to deploy; resolve manually."
  exit 1
fi

# --- Is there anything new? -------------------------------------------------
git fetch --quiet origin "$BRANCH"
LOCAL="$(git rev-parse HEAD)"
REMOTE="$(git rev-parse "origin/$BRANCH")"

if [[ "$LOCAL" == "$REMOTE" ]]; then
  log "up to date at ${LOCAL:0:8}; nothing to do"
  exit 0
fi

log "$BRANCH moved ${LOCAL:0:8} -> ${REMOTE:0:8}"

# --- Test the new commit in isolation before promoting ----------------------
WORKTREE="$(mktemp -d)"
cleanup() { git worktree remove --force "$WORKTREE" >/dev/null 2>&1 || true; rm -rf "$WORKTREE"; }
trap cleanup EXIT
git worktree add --quiet --detach "$WORKTREE" "$REMOTE"

if [[ -n "$TEST_CMD" ]]; then
  log "testing new commit: $TEST_CMD"
  if ! ( cd "$WORKTREE" && eval "$TEST_CMD" ); then
    log "TESTS FAILED on ${REMOTE:0:8}; staying on last-known-good ${LOCAL:0:8}"
    exit 1
  fi
  log "tests passed"
else
  log "no TEST_CMD set; skipping tests (not recommended)"
fi

# --- Promote: move the live clone forward and restart the service -----------
git checkout --quiet "$BRANCH"
git reset --hard --quiet "$REMOTE"
log "restarting $SERVICE"
systemctl --user restart "$SERVICE"
log "deployed ${REMOTE:0:8}"
