# Mach services added to the starting profile (spike task 1.4)

Rule: the profile starts with NO Mach service; add one at a time, in `base.sb`, only after a concrete denial; record the reason, the evidence and the cost.
`mach-register`, `iokit-open`, `ipc-posix` stay denied. Excluded by design (architecture §5): launchd job submission,
LaunchServices (`open`), Apple Events, Keychain/security services, pasteboard.

Ad-hoc test of a candidate without editing the profile: `run-sandboxed.sh ... --mach <service-name> -- <cmd>` appends one `mach-lookup` rule.

| # | Service (global-name) | Needed by | Evidence (macOS 27.2.1) | Cost / note |
|---|---|---|---|---|
| 0 | none | `python3` (fake CLI, both shapes), `node -e 1`, `npm --version` | run with an empty Mach list: `result.json` written and schema-valid for both shapes | — |
| candidate, **not added** | `com.apple.system.opendirectoryd.libinfo` | `pwd.getpwuid()`; only the fake CLI's `~` expansion in attack mode | without it: `KeyError: 'getpwuid(): uid not found: <uid>'`; with `--mach` it works | Would reveal the owner's real home path to the worker. Not needed for any worker: pass absolute attack targets (`--attack read-ssh=<abs path>`) instead; test with `--mach` only |

## Open items (not Mach; belong to later tasks)
- Node/V8 and Python need `sysctl-read` for a short list of names (`hw.*`, `kern.os*`, ...). It is a name allowlist in `base.sb`; `kern.proc.*`/`kern.procargs2` stay denied. Not a Mach service.
- `dotnet --version` initially failed ("Failed to resolve full path of the current executable") and passes once the ancestor directories of `/usr/local/share/dotnet` are stat-able and `sysctl-read` is on; `dotnet build/test` is S5 (#11).
- Builder `/bin/sh` prints `Error opening /private/var/select/sh` (the sh trampoline) and falls back to bash; inside it only sh/bash/env/sleep are exec-able, so real build scripts are not proven here. S5 (#11) must extend exec and reads.
- `reviewer-readonly` execs only the Python install; a real CLI (node script, native binary in the CLI dir) needs an exec rule for its install (#14/#15). The launcher also assumes a non-system `python3`.
- `kern.hostname` is allowed because `npm --version` fails without it (`RuntimeError` in the fake CLI's probe). Cost: the worker can read the host name, which may contain the owner's name. The other names were taken from what node/Python/dotnet failed without; per-name evidence is not recorded.
- Sandbox denial lines were not visible via `log show` in this session, so additions are found by failing behaviour, not by log. S5/provider tasks should try `(with report)` or a trace.
