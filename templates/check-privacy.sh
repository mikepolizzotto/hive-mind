#!/usr/bin/env bash
# Verify that each configured memory repo has a PRIVATE GitHub remote.
#
# Memory files often contain personal preferences, credentials, or
# infrastructure details. Accidentally cloning or pushing a memory repo
# with a public remote is the single setup mistake that actually matters
# — this script catches it before you start writing memories.
#
# Usage: edit REPOS below to match the repos cloned on this machine,
# then run the script. Requires the `gh` CLI, authenticated with at
# least read access to each repo.

set -u

REPOS=(
    "$HOME/repos/shared-identity"
    "$HOME/repos/work-memory"
)

fail=0

for repo in "${REPOS[@]}"; do
    if [ ! -d "$repo/.git" ]; then
        echo "SKIP  $repo (not a git repo)"
        continue
    fi

    visibility=$(cd "$repo" && gh repo view --json visibility --jq '.visibility' 2>/dev/null) || {
        echo "WARN  $repo — could not query visibility (auth missing, repo deleted, or no gh remote?)"
        fail=1
        continue
    }

    if [ "$visibility" = "PRIVATE" ]; then
        echo "OK    $repo ($visibility)"
    else
        echo "FAIL  $repo is $visibility — memory repos should not be public"
        fail=1
    fi
done

exit $fail
