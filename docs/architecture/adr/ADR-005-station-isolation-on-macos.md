# ADR-005 — Station isolation: same user under a true deny-by-default Seatbelt profile, per-step folder and gateway port, orchestrator-side diff

- **Status:** Proposed (2026-11-20; rewritten in revision 2 per D-56; revised in revision 3 for B1–B3, B8, B9; revision 3a per D-63; revision 4 per D-65, D-66, D-67, D-71, C2, C4; 4.1 for K2, K3)
- **Relates to:** D-17, D-26, D-27, D-38, D-53, D-56, D-60, D-62, D-63, D-65, D-66, D-71, value 4 (and its collision with value 3)

## Context
D-26 requires a disposable copy per worker, an empty environment + allowlist, no Git push/GitHub credentials in workers, and an orchestrator-side diff check. On the owner's Mac, a process running as the owner can by default:
- read `~/.ssh`, `~/.config/gh`, other Steps' folders and the Keychain (A2);
- plant config for later workers or reviewers through provider folders or repo-level instruction files (A1, B1);
- start code **outside** any sandbox through launchd, LaunchServices or Apple Events, or signal the orchestrator (B2);
- poison package caches shared by other items and by main (B3).

D-56 and D-63 make "same user + deny-by-default Seatbelt" the only mode. Value 3 outranks value 4, but D-26 is binding, so the simplest design that **meets** D-26 wins.

## Decision
1. **Item worktree** (orchestrator-owned, branch `factory/<issue>-<slug>`) holds the committed state; workers never see it.
2. **Per-Step folder** `work/<step-id>/`, deleted after the Step. It holds:
   - `home/` (all provider config/session locations);
   - `io/in`, `io/out`, `tmp/`;
   - one read-only provider credential;
   - `repo/`: an APFS clone of the head **without** `.git`, `.factory/**` and agent-instruction files (built-in list ∪ each adapter's declared list, e.g. `CLAUDE.local.md`, `.mcp.json`). Those files are also protected paths.
3. **True `(deny default)` Seatbelt profile per Step:**
   - file reads: system paths, toolchains, read-only caches and overlay, own folder, own credential;
   - file writes: own `repo/` (builder preset), `io/out`, `home`, `tmp`;
   - `mach-lookup` only for the services each CLI, `dotnet` and `node` need (from the spike). Launchd job submission, LaunchServices, Apple Events, Keychain and pasteboard are excluded;
   - `signal`/`process-info` only within the Step's own process group;
   - `process-exec`: `reviewer-readonly` → CLI binaries + read-only helpers, no shell; `builder` (builder and test author, D-71) → shell and offline toolchain;
   - network: worker Steps only to their own gateway port; check Steps only to their own service ports; the restore Step to its own gateway port.
4. **Worker gateway, one localhost port per Step**, closed at the Step's end:
   - CONNECT allowlist: provider API hosts ∪ role web allowlist for worker Steps; registries only for restore; no gateway for other checks.
   - Hosts, connections and bytes are logged as telemetry and flagged when above what the CLI reports, not charged or blocked (D-60, D-66).
5. **Empty environment + allowlist**; no GitHub/SSH/cloud variables.
6. **Packages (D-62, D-65):**
   - Shared caches are filled only from main by the orchestrator and are read-only to every Step.
   - New direct dependencies enter only through the orchestrator's dependency step: allowlist or owner approval, then reference and lock files written by the orchestrator, then a locked restore (`--ignore-scripts`) into the item overlay.
   - The project file or `package.json` that receives the reference joins the item's file lock. Lock files are protected, orchestrator-owned and regenerated on merge conflicts (K3).
7. **Process tracking:** own process group, `FACTORY_STEP` marker, per-second PID tracking. Kill = TERM, KILL, marker scan. On exit: kill leftovers → close port → APFS snapshot → diff from the snapshot.
8. **Diff by orchestrator tree hashes.** The copy's `.git` is excluded, the base commit's ignore rules apply, and edits of `needs_context`/`blocked`/failed Steps are discarded (C4). Rules in order:
   1. protected paths;
   2. role paths;
   3. declared files; a new dependency refuses the whole diff and goes through the dependency step (K2);
   4. red-test lock;
   5. rule paths and **new suppressions in the diff** (human diff approval bound to SHA before push; C2);
   6. sensitive paths;
   7. hygiene.
9. Provider CLI tool flags are an **extra** layer; the CLIs' own Seatbelt sandboxes are off (they cannot nest).
10. **Hostile-worker tests** (architecture §3): planted instructions, IPC escapes, cross-Step gateway use, cache writes, lock-file writes, `nohup`/`setsid`.

If the sandbox cannot hold for a CLI, that provider is `unsupported` (D-63). There is no other isolation mode in v1.

## Consequences
- The value-4 test holds without trusting the CLI or the prompt: a misbehaving worker of any provider cannot push, merge, change the rules or touch protected paths. It also cannot read other Steps or the owner's credentials, start unsandboxed code, plant instructions for reviewers, or poison other items' packages.
- The test author runs arbitrary local code in its own sandbox, exactly as the builder does (D-71). Its writes are still limited to test globs, and the red check is independent.
- The design depends on the Mach allowlist found in the spike (architecture Q1).
- Builder and test-author shells can reach provider hosts through their gateway. This is recorded and flagged, not blocked (D-60, D-66).
- Residual risks: `sandbox-exec` deprecation; double-forked processes (they have no network once the port closes). Each ends in `unsupported`, never in running unsandboxed.

## Alternatives considered
- **Dedicated OS user:** stronger Keychain separation, but needs sudo helpers; excluded by D-63.
- **Same user with only Keychain services denied (revision 2):** leaves launchd/LaunchServices/Apple Events routes open (B2).
- **Tests-only exec limit for the test author (revision 3):** needed a shim and a nested check Step; removed by D-71.
- **Docker/VM per worker:** a heavy prerequisite (D-47 avoids Docker); a v2 option.
- **git worktree per worker:** shares `.git` (config, hooks, remotes) with the orchestrator.
