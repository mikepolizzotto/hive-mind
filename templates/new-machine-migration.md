# New-Machine Migration — Runbook + Gotchas

Bringing your hive-mind onto a *new* machine (not just a fresh clone, but a real "this is my daily driver now" migration), plus the traps that bite in practice. Complements [`bootstrap-procedure.md`](bootstrap-procedure.md), which is the Phase-1 memory-continuity checklist — read that first; this adds the full migration flow and the hard-won lessons.

## The model: orchestrator + driver

Run two Claude Code sessions:

- **Driver** — Claude Code on the **new** machine. It clones the memory repos, reads your canonical docs, and drives the build phase-by-phase, pausing for anything interactive.
- **Orchestrator** — Claude Code on an **existing** machine (or just you with this doc). Reviews each phase, catches issues, and folds every fix back into your *kit* (your shared-identity repo) — not just the one machine.

You relay phase reports between them. Build on the new box, review from the old, fix the kit. Going slow is worth it; the gotchas below are why.

**Kit handoff:** put a transfer folder on the new machine with a **kickoff prompt** + a **secrets manifest** + a `secrets/` subfolder of the files you're carrying. Commit the prompt/manifest into your shared-identity repo too, so they self-deliver once the new box clones — *except* the kickoff prompt itself, which you need before the repos exist (chicken-and-egg; keep it where you can paste it).

## Flow

1. **Stage secrets** from your source machine(s) into the transfer folder per your manifest. Copy what you can rather than regenerate; note which machine sources which file.
2. **Manual prereqs** on the new box: password-manager app (with CLI + biometric), build tools, package manager, install Claude Code + log in, and your git host's CLI auth.
3. **Set identity early:** hostname and `git config --global user.name/email` (see gotcha 4).
4. **Launch Claude in the kit folder, paste the kickoff prompt:** clone repos → read canonical docs → drive the build, pausing for your hands.
5. **Place secrets** (fix perms, verify key fingerprints), wire your shell rc (secrets-manager references + aliases).
6. Build in layers — **memory → tools → reach → harden → continuity** — then a final verification pass.

## Gotchas that bite in practice

1. **Native-memory path is derived from the home/working directory.** If you use Claude Code's native memory directory as a repo target, its path is the dash-encoded absolute path. A new machine with a *different username* gets a *different* encoded path. Clone to the **new** machine's path, and update your `CLAUDE.md` + `settings.json` (especially any SessionEnd hook) to match. Don't copy the old machine's hardcoded path verbatim.

2. **Multi-writer memory needs a SessionStart pull.** If only one machine ever wrote a memory repo, you may have skipped pulling it at session start. The moment a *second* machine writes it (e.g., an autosave-on-exit hook), they diverge — and the autosave push silently fails on non-fast-forward if the hook swallows errors. **Pull every writable memory repo at SessionStart on every writer.**

3. **Agent-dependent SSH configs aren't portable.** A `Host` block with no explicit `IdentityFile` works on the machine where the key is loaded in `ssh-agent` — and breaks on a fresh box. Add explicit `IdentityFile`, and `IdentitiesOnly yes` for endpoints that lock out after repeated wrong-key offers. Fix the *source* config too, so future copies are clean.

4. **Set git identity on a fresh box.** No `user.name`/`user.email` means commit-based hooks (like memory autosave) can't commit — and often fail silently. Set it before the first hook fires.

5. **Rotate anything ever exposed; reference secrets, don't inline them.** A migration is when you discover the token you pasted in a chat months ago and never rotated. Rotate it, store it in your secrets manager, and put a *reference* (e.g., a `secrets-manager read ...`) in your shell rc — never a literal token.

6. **Tooling drift.** Package names and casks change between machine builds. Verify your install list against current reality (formula renamed, moved to a different package source, now needs a runtime, etc.) rather than trusting an old list.

7. **Transfer mechanics.**
   - Local file transfer (e.g., AirDrop) often lands in a *Downloads*-type folder and **strips permissions** — move files into place and re-apply perms (private keys `600`, public/config `644`).
   - **Don't paste multi-line `sudo` blocks** — the password prompt can swallow a pasted line, so the command runs without elevation. Authenticate first (`sudo -v`) or use the GUI for one-off system toggles.
   - Verify a folder transfer actually carried its subfolders; send sensitive subfolders explicitly if unsure.

8. **Full-tunnel VPN can blackhole local-subnet access** — especially if the VPN's routed ranges overlap your local network. Test local/LAN reachability with the VPN **off**, and cloud/remote reach with it on; don't do both at once.

9. **A stealth-mode firewall won't answer ping.** That's a feature, not an outage. Check liveness via your network controller / DHCP, ARP on the local segment, mDNS discovery, or a connect to an allowed service port — not `ping`.

## Continuity / disaster-recovery seed

The migration is also when you build (or refresh) your recovery seed:

- The seed is the **not-in-repo secrets** needed to rebuild on a *new* machine (service-account keys, SSH keys, deploy keys, shell-rc tokens) plus a short `RESTORE.md` (what each file is, destinations, perms, key fingerprints). Your git-backed memory already survives; this covers what git doesn't.
- **Encrypt in a format that needs no tool install at restore time** (a native encrypted disk image beats a tool you'd have to install first when everything's gone). Strong symmetric encryption is fine since the blob is opaque.
- Store the encrypted blob **offsite** (the device might burn too). An already-encrypted blob is safe in personal cloud storage + a physical copy elsewhere.
- Keep the **passphrase in a recovery path independent of the seed** (e.g., your password manager / platform keychain), not inside it.
- **Verify the seed restores before you delete any plaintext.** Test-mount/decrypt, confirm the files are there, *then* clean up. Never delete the only copy.

## Verify (the "it actually works" pass)

- **Smoke test the brain:** open a fresh session and ask "who am I / what do I do" — it should answer from your memory repos.
- **Prove the write path:** write a throwaway memory file, let it commit/push, then remove it — confirms hooks + auth + identity all work end to end.
- **Prove reach:** connect to each system the machine should reach (local with VPN off, remote with it on).
- Update your machine roster, and **fold any new gotcha back into this runbook** so the next migration is smoother.
