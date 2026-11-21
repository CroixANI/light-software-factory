# Mach services added to the starting profile (spike task 1.4)

Rule: start from none; add one service at a time, only after a concrete denial; record the reason, the evidence and the cost.
`mach-register`, `iokit-open`, `ipc-posix` stay denied. Excluded by design (architecture §5): launchd job submission,
LaunchServices (`open`), Apple Events, Keychain/security services, pasteboard.

Ad-hoc test of a candidate without editing the profile: `run-sandboxed.sh ... --mach <service-name> -- <cmd>` appends one `mach-lookup` rule.

| # | Service (global-name) | Needed by | Evidence (macOS 27.2.1) | Cost / note |
|---|---|---|---|---|
| 0 | none | `python3` (fake CLI, both shapes), `node -e 1`, `npm --version` | run with an empty Mach list: `result.json` written and schema-valid for both shapes | — |
| 1 | `com.apple.system.opendirectoryd.libinfo` | `pwd.getpwuid()` (libc `getpwuid`), used by the fake CLI to resolve `~` | without it: `KeyError: 'getpwuid(): uid not found: 501'`; with `--mach` it returns the home dir | The worker can read user/group names. Revisit in S2 (#9) |

## Open items (not Mach; belong to later tasks)
- `sysctl-read` was needed by node/V8 (`LowLevelAlloc arithmetic overflow` without it). It is in `base.sb`; not a Mach service.
- `dotnet --version` still fails under the builder shape (`Failed to resolve full path of the current executable`); the fake CLI reports it as `unavailable` and stays valid. Cause not yet found (tried `process-info*`, `file-read-metadata`); owned by S5 (#11).
- Sandbox denial lines were not visible via `log show` in this session, so additions are found by failing behaviour, not by log. S5/provider tasks should try `(with report)` or a trace.
