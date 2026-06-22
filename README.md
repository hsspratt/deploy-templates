# deploy-templates

One place that holds the reusable CI + auto-merge workflow, the Pi pull-deploy
machinery, and the deploy checklist. Each project carries only a tiny caller +
a one-file config. Improvements made here propagate instead of drifting.

## What's in here

```
.github/workflows/ci-automerge.yml   Reusable workflow (CI + label-gated auto-merge)
pi/pi-deploy.sh                       Generic pull-deploy script (one per Pi, not per project)
pi/pi-deploy@.service                 systemd --user template unit (%i = project name)
pi/pi-deploy@.timer                   systemd --user template timer (polls every 5 min)
pi/registry/EXAMPLE.conf              Copy per project -> registry/<project>.conf
DEPLOY-CHECKLIST.md                   Security + deploy invariants. Read before merging.
```

## The two halves

**GitHub side.** Each repo adds a ~10-line `.github/workflows/ci.yml` that
calls `ci-automerge.yml` here. Tests run on every PR; a PR squash-merges
automatically only when tests pass *and* it has the `automerge` label.

**Pi side.** One clean deploy clone per project under `~/deploy/<project>`,
plus ONE templated systemd timer. Every 5 minutes it fetches `main`, tests the
new commit in an isolated worktree, and restarts the service only on green.

## Onboard a new project (the whole point)

1. Add the caller workflow to the project repo (see `SETUP-GUIDE.md`).
2. On the Pi: `cp ~/deploy/registry/EXAMPLE.conf ~/deploy/registry/<project>.conf`
   and edit REPO / SERVICE / TEST_CMD.
3. `systemctl --user enable --now pi-deploy@<project>.timer`

That's it — no new code, no copy-pasted pipeline. Full walkthrough in
`SETUP-GUIDE.md`.
