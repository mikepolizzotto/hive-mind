#!/usr/bin/env bash
# Non-fatal sync for shared memory repos on headless machines.
#
# Call this from the top of any job that already runs on a schedule
# (cron, launchd, systemd timer). The SessionStart auto-pull hook in
# settings.json fires only when a Claude Code session starts — a
# fully headless machine never starts one, and scheduled jobs that
# read memory files directly bypass Claude Code entirely. Without
# this the local clones can drift for days or weeks before anyone
# notices.
#
# Usage: source this from an existing scheduled job, or exec it
# directly. It's intentionally non-fatal: a missing repo, broken
# network, or stale lock will not block the parent job.
#
# Add one line per repo that this machine has cloned. Omit repos
# this machine doesn't have access to.

set +e

REPOS=(
    "$HOME/repos/shared-identity"
    "$HOME/repos/homelab-memory"
)

for repo in "${REPOS[@]}"; do
    if [ -d "$repo/.git" ]; then
        git -C "$repo" pull --ff-only --quiet 2>/dev/null || true
    fi
done

exit 0
