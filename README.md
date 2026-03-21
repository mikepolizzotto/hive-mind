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

Individual memories go in separate `.md` files with frontmatter:

```markdown
---
name: Collaboration style
description: How I prefer to work with AI
type: user
---

I'm a senior engineer who uses AI as a collaborator, not a task executor.
Challenge my decisions. Keep responses concise. No trailing summaries.
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

### Team Use

This framework is designed for one person across multiple machines. For team use, you'd want shared repos with branch-based writes or PR-based reviews. That's a different problem.

## Limitations

- **No mid-session sync.** If you're on Machine A and Machine B writes a memory simultaneously, Machine A won't see it until the next session. This is fine — you're not on two machines in the same conversation.
- **Claude must follow CLAUDE.md instructions.** The commit-and-push behavior isn't enforced by tooling — it's instructed via CLAUDE.md. New sessions don't carry behavioral patterns from previous ones; they just read the instructions. If Claude forgets to push, the other machines get stale data.
- **Claude won't proactively check repos unless told to.** Without explicit instructions, Claude will say "I don't know" instead of checking shared repos. The templates include a "When to check shared repos" section that tells Claude to check MEMORY.md indexes when asked about specific projects or names it doesn't recognize. This is scoped to avoid checking repos for general knowledge questions.
- **Hook format may change.** Claude Code hooks are relatively new. The schema may evolve. Check the [hooks documentation](https://docs.anthropic.com/en/docs/claude-code/hooks) if you hit errors.
- **Git pull on every session start.** The hook fires on the first `Read` call. If you're offline, the pull silently fails and Claude works with whatever was last pulled. No data loss, just potentially stale data.

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
