# Claude Hive Mind

A framework for keeping Claude Code's memory in sync across multiple machines using git-backed repos and auto-pull hooks.

## The Problem

Claude Code's [auto memory](https://docs.anthropic.com/en/docs/claude-code/memory) is machine-local. If you use Claude Code on more than one machine — a work laptop, a home desktop, a headless server — each one is its own island. Context learned on one machine doesn't exist on the others. You end up re-explaining who you are, how you work, and what you're building every time you switch machines.

There's no built-in sync. [People have been asking for it.](https://github.com/anthropics/claude-code/issues/25739)

## The Solution

Use private git repos as shared memory stores, with Claude Code hooks that auto-pull on session start and CLAUDE.md files that tell each instance where to look.

The key insight: **not all memory should go everywhere.** Different machines have different roles and different security boundaries. This framework uses domain-scoped repos with an access matrix so each machine sees only what it should.

## Architecture

### Domain-Scoped Repos

Instead of one giant synced folder, split memory into domains. Each domain gets its own private git repo:

| Repo | Domain | Example Contents |
|------|--------|-----------------|
| `work-memory` | Work / professional | Server configs, API credentials, vendor details, SaaS audits |
| `shared-identity` | Universal (shared by all machines) | User profile, collaboration preferences, feedback rules |
| `homelab-memory` | Homelab / personal infra | Device baselines, network configs, monitoring dashboards |

You might only need two repos, or you might need four. The number depends on your setup. The important thing is that each repo has a clear boundary.

**A note on naming.** The repo names above (`work-memory`, `shared-identity`, `homelab-memory`) are descriptive placeholders — use whatever tells you what's inside at a glance. Many users pick a theme so the names are memorable: brain anatomy, geography, mythology, whatever. The framework doesn't care about the names; your CLAUDE.md is what maps each repo to its purpose.

### The Shared Identity Layer

One repo must be readable by **every** machine. This is your shared identity layer — it holds memories about *you*, not about any specific environment:

- How you like to collaborate with Claude
- Design principles and standards you follow
- Feedback and corrections that apply everywhere
- Personal project notes

This is the glue that makes Claude feel like the same entity across machines.

### Access Matrix

Each machine gets explicit read/write permissions per repo:

| | work-memory | shared-identity | homelab-memory |
|---|---|---|---|
| **Work Machine** | read-write | read-write | read-only |
| **Home Laptop** | read-write | read-write | read-only |
| **Homelab Server** | **no access** | read-write | read-write |

Key principles:
- **Write access = source of truth.** Only one or two machines should write to each repo.
- **Read-only access = cross-referencing.** A machine can see context without being able to modify it.
- **No access = security boundary.** Sensitive work data (API keys, internal IPs) shouldn't exist on every machine.

Customize this matrix for your setup. The framework doesn't enforce it — your CLAUDE.md files do.

## Setup

### 1. Create Your Memory Repos

Create private repos on GitHub for each domain. At minimum, you need two:

```bash
# Your shared identity (required — this is what all machines share)
gh repo create shared-identity --private

# Your primary domain (work, homelab, whatever your main machine does)
gh repo create work-memory --private
```

Each repo should have a `MEMORY.md` index file that serves as a table of contents:

```markdown
# Shared Identity

## User Profile
See [user_profile.md](user_profile.md) for collaboration preferences.

## Feedback
See [feedback_design.md](feedback_design.md) for design standards.
See [feedback_code_style.md](feedback_code_style.md) for code style preferences.
```

Individual memories go in separate `.md` files with frontmatter. Claude Code's built-in [auto-memory](https://docs.anthropic.com/en/docs/claude-code/memory) uses four memory types — `user`, `feedback`, `project`, `reference` — and sets expectations about how each type should be structured. If you're using Claude's native memory system, match its conventions so future sessions parse your memories correctly.

**`user` — who you are and how you work:**

```markdown
---
name: Collaboration style
description: How I prefer to work with AI
type: user
---

I'm a senior engineer who uses AI as a collaborator, not a task executor.
Challenge my decisions. Keep responses concise. No trailing summaries.
```

**`feedback` — corrections and validated approaches. Include `Why:` and `How to apply:` so future sessions can judge edge cases:**

```markdown
---
name: No trailing summaries
description: Terse responses without recap of what just happened
type: feedback
---

Don't summarize what you just did at the end of a response. I read the diff.

**Why:** Trailing summaries inflate responses without adding information.
**How to apply:** Skip end-of-turn recaps. State results and decisions directly, then stop.
```

**`project` — facts and decisions about ongoing work. Also uses `Why:` / `How to apply:`:**

```markdown
---
name: Homelab freeze window
description: No non-critical changes during the freeze
type: project
---

Homelab changes are frozen until 2026-05-15.

**Why:** Mid-migration to new hypervisor; don't want churn.
**How to apply:** Flag any proposed homelab work after 2026-05-15 — before then, only critical fixes.
```

**`reference` — pointers to external systems:**

```markdown
---
name: Bug tracker
description: Where bugs live outside this repo
type: reference
---

Bugs are tracked in Linear project "INFRA". Check there for context on ticket IDs.
```

### 2. Clone Repos on Each Machine

Pick a standard path. `~/repos/` works well:

```bash
mkdir -p ~/repos
gh repo clone yourname/shared-identity ~/repos/shared-identity
gh repo clone yourname/work-memory ~/repos/work-memory
# Only clone on machines that should have access:
gh repo clone yourname/homelab-memory ~/repos/homelab-memory
```

### 3. Create `~/.claude/CLAUDE.md`

This is the user-level config that tells Claude where to find shared memory. It applies regardless of which directory you launch Claude Code from.

See the [templates](templates/) directory for examples. Here's the general pattern:

```markdown
## Shared Memory

This machine has access to the following memory repos:
- **work-memory**: ~/repos/work-memory/ (read-write)
- **shared-identity**: ~/repos/shared-identity/ (read-write)
- **homelab-memory**: ~/repos/homelab-memory/ (read-only — never commit/push)

### Rules
- On session start, pull shared repos before reading
- When you need context on a topic, read the relevant repo's MEMORY.md index first
- After writing memories, commit and push to the appropriate repo
- Use the correct repo for each domain — don't put work memories in shared-identity
- After writing: git add, commit with [machine-name] prefix, push
```

### 4. Add the Auto-Pull Hook

Add this to `~/.claude/settings.json` so Claude automatically pulls fresh data on the first file read of each session:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Read",
        "hooks": [
          {
            "type": "command",
            "command": "git -C ~/repos/shared-identity pull --ff-only 2>/dev/null; git -C ~/repos/work-memory pull --ff-only 2>/dev/null; true"
          }
        ]
      }
    ]
  }
}
```

Only include repos that exist on that machine. The trailing `true` ensures the hook doesn't fail if a pull has no changes.

See [templates/settings.json](templates/settings.json) for a complete example.

### 5. Commit Message Convention

Tag every commit with the machine name so `git log` shows which Claude wrote what:

```
[work-laptop] updated network documentation after firewall changes
[homelab-server] added proxmox baseline metrics
[home-laptop] updated collaboration preferences
```

This is configured in your CLAUDE.md rules, not enforced by git.

## How It Works

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Work Machine   │     │   Home Laptop   │     │ Homelab Server  │
│                 │     │                 │     │                 │
│ Claude Code     │     │ Claude Code     │     │ Claude Code     │
│   ↕ read/write  │     │   ↕ read/write  │     │   ↕ read/write  │
│ work-memory     │     │ work-memory (r) │     │ homelab-memory  │
│ shared-identity │     │ shared-identity │     │ shared-identity │
│ homelab (ro)    │     │ homelab (ro)    │     │                 │
└────────┬────────┘     └────────┬────────┘     └────────┬────────┘
         │                       │                       │
         └───────────┬───────────┴───────────┬───────────┘
                     │                       │
              ┌──────┴──────┐         ┌──────┴──────┐
              │   GitHub    │         │   GitHub    │
              │ (private    │         │ (private    │
              │  repos)     │         │  repos)     │
              └─────────────┘         └─────────────┘
```

1. **Session start** → Hook fires on first `Read` call → `git pull --ff-only` on all shared repos
2. **Claude needs context** → Reads `MEMORY.md` index from relevant repo → Reads specific memory files
3. **Claude writes a memory** → Writes to the correct repo based on domain → Commits with `[machine-name]` prefix → Pushes to GitHub
4. **Next session on any machine** → Hook pulls → New memory is available everywhere

## File-Per-Memory Pattern

Each memory is a separate `.md` file. This is critical for avoiding merge conflicts — two machines would have to edit the exact same file between pulls to conflict. In practice, this doesn't happen.

The `MEMORY.md` file in each repo is just an index with one-line pointers:

```markdown
See [network.md](network.md) for firewall and VLAN documentation.
See [backups.md](backups.md) for backup infrastructure deep dive.
```

Keep `MEMORY.md` under 200 lines. Claude Code truncates it beyond that. If your index is growing, your individual memory files should absorb the detail.

## Customizing for Your Setup

### Two Machines (Simplest)

You might only need two repos:

| Repo | Purpose |
|------|---------|
| `shared-identity` | Who you are + universal preferences |
| `primary-memory` | Everything else |

Both machines get read-write on both repos. No access restrictions needed.

### Three+ Machines with Security Boundaries

Add repos per domain and restrict access. A machine that doesn't need work credentials shouldn't have a clone of the repo that contains them.

### Headless Machines (No Interactive Sessions)

The auto-pull hook in `settings.json` fires on Claude Code's first `Read` call — which means it only fires during **interactive** sessions. If a machine only ever runs automated jobs (a homelab server, a CI runner, a scheduled scraper) and you never open a Claude Code session on it directly, the hook never runs and the local clone silently goes stale. In practice this can drift by days or weeks before anyone notices.

**Fix:** piggyback `git pull --ff-only` onto an existing scheduled job on that machine (cron, launchd, systemd timer). Don't create a new dedicated sync-only job — just add the pull at the top of a job that already runs on the cadence you need.

`templates/headless-sync.sh` is a drop-in helper:

```bash
# In a launchd plist, cron entry, or systemd unit that already runs daily:
~/repos/claude-hive-mind/templates/headless-sync.sh
# ...then the rest of your scheduled job
```

The helper is intentionally non-fatal: missing repos, broken network, or stale locks won't block the parent job. See `templates/CLAUDE.md.headless` for a full CLAUDE.md template designed for this machine role.

### Team Use

This framework is designed for one person across multiple machines. For team use, you'd want shared repos with branch-based writes or PR-based reviews. That's a different problem.

## Using Claude's Native Memory Directory as the Repo

Claude Code has a built-in auto-memory system that writes to a directory keyed off your working directory — typically something like `~/.claude/projects/<path-encoded-cwd>/memory/`. By default, this directory is just a local folder and nothing syncs it anywhere.

**The trick:** clone your memory repo *as* that native directory instead of into `~/repos/`. Claude's built-in memory tooling then writes straight into your git repo with no translation layer.

The native path is your working directory with slashes replaced by dashes, under `~/.claude/projects/`. For example, a working directory of `/Users/alice` becomes `~/.claude/projects/-Users-alice/memory/`. List `~/.claude/projects/` to see which ones Claude has already created for you:

```bash
ls ~/.claude/projects/
# find the entry that matches your main working directory, then:

cd ~/.claude/projects/<your-encoded-cwd>/
# Back up anything already in memory/ before this next step — rm is destructive:
mv memory memory.bak 2>/dev/null
gh repo clone yourname/work-memory memory
```

After that, anything Claude writes via the auto-memory system is a regular file in a regular git repo, ready to commit and push. If you had memories in `memory.bak`, move them into the new clone and commit.

**Tradeoffs:**
- **Pro:** zero indirection. Claude's native memory UI, the `MEMORY.md` index, and your git repo are all the same thing.
- **Pro:** works automatically with future changes to Claude's built-in memory behavior — no custom path mapping to maintain.
- **Con:** the native memory path is keyed off working directory, so it differs per machine (different username → different encoded path). Each machine's clone destination has to be computed separately.
- **Con:** if Claude Code changes its native memory path scheme in a future release, your clone location may need to move.

This is optional — if you prefer to keep memory in `~/repos/` and point CLAUDE.md at it, that also works. The native-dir pattern is just the lowest-friction option once you're comfortable with the layout.

## Limitations

- **No mid-session sync.** If you're on Machine A and Machine B writes a memory simultaneously, Machine A won't see it until the next session. This is fine — you're not on two machines in the same conversation.
- **Claude must follow CLAUDE.md instructions.** The commit-and-push behavior isn't enforced by tooling — it's instructed via CLAUDE.md. New sessions don't carry behavioral patterns from previous ones; they just read the instructions. If Claude forgets to push, the other machines get stale data.
- **Claude won't proactively check repos unless told to.** Without explicit instructions, Claude will say "I don't know" instead of checking shared repos. The templates include a "When to check shared repos" section that tells Claude to check MEMORY.md indexes when asked about specific projects or names it doesn't recognize. This is scoped to avoid checking repos for general knowledge questions.
- **Hook format may change.** Claude Code hooks are relatively new. The schema may evolve. Check the [hooks documentation](https://docs.anthropic.com/en/docs/claude-code/hooks) if you hit errors.
- **Git pull on every session start.** The hook fires on the first `Read` call. If you're offline, the pull silently fails and Claude works with whatever was last pulled. No data loss, just potentially stale data.
- **Auto-pull hook only fires in interactive sessions.** On fully headless machines (servers that only run scheduled jobs, never an interactive Claude Code session), the `Read`-matcher hook never runs. See the "Headless Machines" section above for the scheduled-pull fix.

## FAQ

**Why git and not iCloud/Dropbox/Syncthing?**

Git gives you history, attribution, conflict resolution, and selective access (don't clone repos you don't want on a machine). Cloud sync services sync everything and can have race conditions with concurrent writes.

**Why not one big repo?**

Security boundaries. If your work repo has API keys and internal IPs, you don't want it cloned on every machine. Domain scoping lets you control what lives where.

**Why private repos?**

Memory files may contain personal preferences, infrastructure details, or workflow patterns you don't want public. Always use private repos for memory.

**Can I use this with Claude Code on a remote server (SSH)?**

Yes. Clone the repos on the server, create the CLAUDE.md and settings.json, and it works the same way. Just make sure the server has git access to your private repos (SSH key or token).

**What if two machines write to the same file?**

The file-per-memory pattern makes this rare. If it happens, `git pull --ff-only` will fail silently (the `2>/dev/null` suppresses it), and the next manual pull will show the conflict. Resolve by keeping the newer version.

## License

MIT
