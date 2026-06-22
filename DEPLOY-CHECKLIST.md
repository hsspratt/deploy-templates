# Deploy checklist & invariants

This file is the "school of thought" in writing. Link it from every project's
README. Re-read it before merging anything that touches data, secrets, or the
deploy path. A convention only survives across repos if it's written where
you'll see it again.

## Security invariants (never violate)

- **No Anthropic API key on the box.** Claude is reached via the Claude CLI
  only. There is no `ANTHROPIC_API_KEY` in any `.env`, unit, or clone.
- **The model can never send.** Outbound messages are emitted by code on a
  fixed path. The model's output is content, never a send instruction.
- **The allowlist is the gate.** Inbound is restricted by numeric user ID
  (stable, unspoofable, always present) — never by username/display name.
- **Transport code never crashes the loop.** Source/sender modules catch and
  log their own errors; a transport failure degrades, it does not kill the bot.
- **Secrets live only in `.env`.** Never committed. `.env` and any state files
  are in `.gitignore`. The bot token is a non-Anthropic credential.

## Deploy invariants

- **Pull-based only.** The Pi fetches; nothing inbound. GitHub cannot run code
  on the Pi.
- **Clean deploy clone ≠ dev dir.** Auto-deploy operates on `~/deploy/<project>`,
  never your working directory.
- **Dirty clone refuses to deploy.** Local edits in the deploy clone abort the
  run rather than being overwritten.
- **Tests gate the restart.** The new commit is tested in an isolated worktree;
  the service only restarts on green, otherwise it stays on last-known-good.
- **Auto-merge is opt-in.** A PR merges automatically only if tests pass AND it
  carries the `automerge` label. No label = manual merge = your veto.

## Pre-merge checklist (per PR)

- [ ] Tests pass locally and in CI.
- [ ] No secrets, tokens, or state files added to the diff.
- [ ] `.gitignore` still covers `.env` and state.
- [ ] No new runtime dependency added without reason (stdlib-first rule).
- [ ] If transport/allowlist/send path changed, invariants above still hold.
- [ ] `automerge` label added only when you're happy for it to ship to the Pi.

## When something breaks the deploy

- Check the deploy log: `journalctl --user -u pi-deploy@<project> -n 50`
- The service stays on last-known-good after a failed test run — safe to
  investigate without downtime.
- A dirty deploy clone aborts the run; inspect with
  `git -C ~/deploy/<project> status`.
