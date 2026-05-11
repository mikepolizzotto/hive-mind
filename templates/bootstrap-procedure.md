# Bootstrap Procedure — Fresh Machine

A checklist for bringing a new machine into the hive-mind. Phase 1 gets you to memory continuity (Claude knows who you are). Phase 2 is a stub — your domain-specific tools and credentials go there, captured inside your shared-identity repo so it's reproducible.

See the README's "Bootstrapping a Fresh Machine" subsection for the high-level framing.

## Prerequisites

- macOS or Linux (Windows works with WSL, but path syntax differs; adapt as needed)
- Modern shell (zsh, bash, fish)
- Internet access; `git` installed
- A password manager / secrets store available, ideally with a CLI

## Phase 1 — Memory continuity

### 1.1 Install Claude Code

Follow Anthropic's documented install method for your platform.

### 1.2 Auth Claude Code

`/login` with the Anthropic identity this machine is primarily for. If you have two identities (e.g., personal + Claude Enterprise), the README's "Two Accounts, One Machine" section covers the multi-account model.

### 1.3 Install GitHub CLI

```bash
brew install gh    # or apt / dnf / equivalent
gh auth login
```

If using SSH (recommended — avoids repeated HTTPS auth prompts):

```bash
ssh-keygen -t ed25519 -C "claude@<machine-name>"
gh ssh-key add ~/.ssh/id_ed25519.pub --title "<machine-name>"
```

### 1.4 Clone the memory repos

Pick a canonical path. `~/repos/` is conventional:

```bash
mkdir -p ~/repos
gh repo clone <you>/<shared-identity-repo> ~/repos/<shared-identity-repo>
gh repo clone <you>/<work-memory-repo>     ~/repos/<work-memory-repo>     # only if this machine should have access
gh repo clone <you>/<other-domain-repo>    ~/repos/<other-domain-repo>    # add more as your topology requires
```

If you use Claude Code's native memory directory as a clone target (see the "Using Claude's Native Memory Directory as the Repo" section in the README), your work-memory clone destination becomes `~/.claude/projects/<encoded-cwd>/memory` instead of `~/repos/`.

### 1.5 Drop in `~/.claude/CLAUDE.md`

Pick the role-appropriate variant from `templates/` in this repo:

- `CLAUDE.md.primary` — read-write on your primary work and shared-identity repos
- `CLAUDE.md.bridge` — sees everything, may be read-only on some repos
- `CLAUDE.md.headless` — automation only, scheduled-pull pattern
- `CLAUDE.md.isolated` — single-domain machine, minimal repo access

Customize repo names and paths for your setup. Replace any `<machine-name>` placeholders with your machine identifier (used for commit prefix attribution).

### 1.6 Drop in `~/.claude/settings.json`

Start from `templates/settings.json`. Adjust the auto-pull hook's repo list to match what you cloned in 1.4. If this machine should run the parallel-session safety net, the SessionEnd autosave hook is in the template — keep or remove based on whether this machine writes memory.

### 1.7 Smoke test the identity layer

Open Claude Code. Ask: "What do you know about me and how I work?"

The answer should reflect content from your shared-identity repo — collaboration preferences, design rules, anything you've written for yourself there. If the answer is generic, CLAUDE.md isn't being read. Verify:

- The file path is exactly `~/.claude/CLAUDE.md` (not `~/claude/CLAUDE.md` or similar)
- The cloned repos contain a `MEMORY.md` index (the framework relies on this for discovery)
- A manual `git pull` in each repo succeeded (the auto-pull hook may not have fired yet on this brand-new session)

## Phase 2 — Domain-specific tooling (per user)

This is where your own CLI inventory lives. Don't try to memorize it; document it in your shared-identity repo as something like `cli-inventory.md` and read it during fresh-machine bootstraps. At minimum, capture:

- Which CLIs you install on this class of machine (cloud, infra, productivity, identity)
- How each one authenticates (password manager item names, OAuth flows, service-account file paths)
- Critical machine-specific files that are NOT in any git repo — service account JSONs, deploy SSH keys, environment-variable secrets in your shell rc, scheduled-job plists/units

When a machine dies, this list is the difference between an hour of recovery and an afternoon of "what was that tool again?"

## End-to-end smoke test

Run these once after Phase 1 (and after Phase 2 if you have one):

1. Open Claude Code; have it read a specific memory file you wrote previously. Should succeed without permission issues.
2. Have Claude write a trivial test memory: `cd <appropriate-repo> && echo "ok" > _bootstrap_test.md && git add _bootstrap_test.md && git commit -m "[<machine>] bootstrap smoke test" && git push`.
3. From a different machine, `git pull` the repo. Confirm the bootstrap commit appears in `git log`.
4. Delete the test file: `git rm _bootstrap_test.md && git commit -m "[<machine>] remove bootstrap test" && git push`.
5. End the Claude session. If you wired up a SessionEnd autosave hook, check the log file you point it at for confirmation that it fired even with no changes to commit.

If those pass, the machine is fully bootstrapped.

## Known gaps to plan around

- Files outside the memory repos are not in git. Service account keys, env-var secrets in your shell rc, deploy SSH keys, scheduled-job plists — all machine-local. Either back them up, document a regeneration procedure, or accept the recovery cost. The framework doesn't sync them by design.
- The first session after bootstrap may have a stale local memory clone if the auto-pull hook hasn't fired yet. Do a manual `git pull` in each cloned repo before the first real session if timing matters.
- See the README's "Limitations" section for the general caveats (subagents not always seeing fresh memory, MCPs being account-tied, etc.).
