# S6 findings: `sandbox-exec` status on the current macOS

Task 2.4 of `spike-sandbox-and-providers`, experiment S6, question Q3 (architecture §19). Issue #12. Decisions: D-63 (no dedicated user; if the sandbox cannot hold, the provider is `unsupported`), ADR-004, ADR-005.
Evidence is the commands and results summarised below (not raw logs); nothing was committed besides this file. Runs were done from an agent session on the owner's machine; whether that session was itself sandboxed was not checked (the plain `(allow default)` run succeeded, so applying a profile was possible).

## Versions

| Item | Value |
|---|---|
| macOS | 27.2.1 (build 26B131), Darwin 27.2.0, arm64 (Apple M-series) |
| SIP | enabled |
| `/usr/bin/sandbox-exec` | present, universal Mach-O (`arm64e`, `arm64e.x1`), 135 KB, signed by Apple (`com.apple.sandbox-exec`, platform binary), links `/usr/lib/libsandbox.1.dylib` |
| Xcode / SDK | Xcode 27.2 (27B52); the binary's `minos` and SDK are 27.2, so Apple rebuilt it with this release |

## Deprecation

- `man sandbox-exec` still says: "sandbox-exec - execute within a sandbox (DEPRECATED)" and tells developers to adopt App Sandbox instead. The man page is the only place the deprecation shows.
- **No runtime warning:** a plain run prints nothing on stderr (0 bytes) and exits 0. The tool is deprecated on paper only; on 27.2.1 nothing in its output signals it (no other version was tested).
- The tool was not removed in 27.2.1. It is still shipped and rebuilt, but Apple gives no support promise: it can disappear in any release. The adapter must treat "missing or not working" as a normal state.

## Behaviour on this macOS (all run against `sandbox-exec -p '<profile>'`)

Profile used: `(version 1)(deny default)(allow process-exec*)(allow process-fork)(allow file-read*)` plus one `(deny file-read* (subpath <secret dir>))`.

| Check | Result |
|---|---|
| `(allow default)` then `/usr/bin/true` | exit 0 |
| `(deny default)` only, then `/usr/bin/true` | exit 71, `execvp() of '/usr/bin/true' failed: Operation not permitted` (exec must be allowed explicitly) |
| Read of a path denied by the profile | `Operation not permitted`, exit 1 |
| Read elsewhere, allowed | works |
| Write outside the allowed paths | `Operation not permitted`, file not created |
| Network (`curl https://example.com`) with no network rule | exit 6 (`Could not resolve host`): DNS lookup is already denied |
| Profile from a file (`-f`) | works, same as `-p` |
| Syntax error in the profile | exit 65 with the parser's message and position; the command is not run |
| Applying a sandbox inside a sandbox | under the deny-default profile: `sandbox_apply: Operation not permitted`, exit 71. Under an `(allow default)` outer profile the nested `sandbox-exec` succeeds (exit 0), so nesting is not forbidden as such; the outer profile denies it. Relevant to CLIs with their own inner sandbox: whether it can start depends on the outer profile (re-check if the builder profile is loosened) |
| Built-in profiles `-n no-network`, `-n pure-computation` | the command is killed (exit 137). Do not use the built-in profiles; use our own profile files |
| Harness (`spike/harness/sandbox/run-sandboxed.sh`, `builder` shape, fake CLI, gateway port) | the fake CLI ran, `result.json` validates (`VALID`), and its `attacks` list was empty (the harness's own attack set was not run here; that is S1–S4) |

So the primitive behaves as D-56 / architecture §5 layer 1 assumes: deny by default, reads and writes denied unless allowed, and network (one probe: DNS lookup failed; a direct IP connection was not tried, S3 in task 2.2 covers it), failures are visible as `EPERM` or a non-zero exit.

## Change since the previous release

Not measurable here: only macOS 27.2.1 was available, and no earlier results were recorded in this repository (the S1–S5 findings of tasks 2.1–2.3 should record this version). The baseline for future comparison is the table above plus the harness run. Re-run the same commands after each macOS update (Q3 mitigation, design.md risk list).

## Consequences for the design

1. **No change to D-63 or ADR-005 is needed.** The mechanism works on the current macOS; the risk is future removal or silent behaviour change.
2. **`doctor` check (proposal for the owner to accept via a decision, not decided here):** on each macOS version change, run the hostile-worker set (the S1–S4 attacks) and the three probes `(allow default)` exec, a denied read, a denied write. If the binary is missing, any probe differs, or the run fails, mark all providers `unsupported` and refuse to run Steps; never fall back to unsandboxed execution (value 4, D-63).
3. Record `sw_vers` (version and build) with every run's evidence so a regression can be tied to an update.
4. Use only our own profile files (`-f`), not `-n` built-ins, which were killed (exit 137) on this version; no earlier version was compared.
5. Longer term, if Apple removes the tool, the only options under D-63 are the C API `sandbox_init` through a small launcher (same engine, also undocumented/deprecated; not tested here) or a container/VM (v2 option in D-63).

## Not done / open

- The comparison with a previous macOS release (no second machine or older OS).
- `sandbox_init` / `libsandbox` called directly was not tried.
