# Implementation spike — plan

**Status:** planned, not started. **Derived from:** [architecture §19 open questions](../architecture/architecture.md#19-open-questions-and-risks-top-10-each-with-a-proposed-default) (Q1–Q5, Q8),
the "verify" cells of [§4 Fit per provider](../architecture/architecture.md#4-provider-adapter-contract), [§5 Station and sandbox](../architecture/architecture.md#5-station-and-sandbox),
[ADR-004](../architecture/adr/ADR-004-provider-adapter-file-based-typed-io.md) and [ADR-005](../architecture/adr/ADR-005-station-isolation-on-macos.md).
This plan adds no requirements. Anything it finds that conflicts with a decision goes to the owner as a new decision entry.

## Goal

Find out, per provider CLI, whether it can run as a v1 worker: headless, as the owner's user, inside a true `(deny default)`
Seatbelt profile, with a Keychain-free read-only credential, behind the per-Step gateway, with its own sandbox off (D-56, D-57, D-63).
Each CLI ends the spike `supported` or `unsupported`. There is no third outcome and no fallback isolation mode (D-63).

Out of scope: orchestrator code, the board, the UI, GitHub integration. Spike code is throwaway and lives in `spike/`.

## Setup (shared by all experiments)

- One Mac on the current macOS release; record the macOS version, each CLI's version and install path.
- A hand-built step folder exactly as in §5: `work/<step-id>/{home,io/in,io/out,tmp,repo}`, mode 0700; `repo/` is an APFS clone of a small sample repo
  **with** planted `CLAUDE.md`, `CLAUDE.local.md`, `AGENTS.md`, `GEMINI.md`, `.claude/`, `.codex/`, `.gemini/`, `.mcp.json` (to test B1).
- A minimal localhost CONNECT proxy on one port per Step that logs host, connections and bytes (§5 layer 3).
- Empty environment + allowlist only (§5 layer 2): `PATH`, `HOME=<step>/home`, provider config-location variables → `<step>/home`, `TMPDIR`, `LANG`, `TERM=dumb`, `HTTPS_PROXY`/`HTTP_PROXY`, `FACTORY_STEP`.
- A starting Seatbelt profile with `(deny default)` and the file/network rules of §5; Mach services added one at a time, each with the reason it is needed.
- A fake prompt per role shape: reviewer-readonly (no shell) and builder (shell + offline toolchain), each asked to write `io/out/result.json` against a small JSON Schema.

## Experiments per provider CLI

Run every row for `claude -p`, `codex exec` and the Gemini CLI. Record the exact command line, flags, env vars and profile used.

| # | Experiment | Pass when | Refs |
|---|---|---|---|
| E1 | **Keychain-free credential.** Find the CLI's file or token credential; copy it read-only into the Step; deny all Keychain/security Mach services | The CLI authenticates and completes a call with Keychain denied | Q1, D-56, ADR-005 §3 |
| E2 | **Credential refresh.** Let the credential approach expiry; run the CLI's own refresh outside any repo (`provider probe`), then a Step with the read-only copy | No Step fails on refresh; the probe-based refresh is enough | Q2, ADR-004 `Probe()` |
| E3 | **Mach-service allowlist.** Start from none; add only what the CLI, `dotnet` and `node` need; log each denial | The allowlist excludes launchd job submission, LaunchServices, Apple Events, Keychain and pasteboard; `mach-register`, `iokit-open`, `ipc-posix` stay denied unless proven needed | Q1, §5 layer 1 |
| E4 | **Proxy compliance.** Block direct egress in the profile; allow only the Step's gateway port | All provider traffic goes through `HTTPS_PROXY`; the gateway log shows every host the CLI contacts | Q3, §5 layer 3 |
| E5 | **Own sandbox off.** Find the flag/config that turns off the CLI's Seatbelt-based sandbox while keeping its tool allow/deny and approval flags | The CLI runs inside the outer profile without trying to nest a sandbox | Q3, ADR-004, ADR-005 §9 |
| E6 | **Headless flags and typed output.** Prompt on stdin; model and effort flags (Gemini: effort `n/a`); the CLI's JSON output where it exists | The CLI writes a schema-valid `io/out/result.json`; its own JSON output parses; exit codes are recorded | §4 Fit table, ADR-004 |
| E7 | **Usage reporting.** Read tokens and cost from the CLI output; look for remaining subscription quota | Each usage field is a value or `null` + reason; quota is a value or `not measured` | Q5, §10, D-66 |
| E8 | **Instruction and settings files (B1).** With the planted files in `repo/` and in `home/`: which ones does the CLI read? Is there a flag to ignore project instruction/settings files? | A complete declared list per CLI (feeds the adapter's list and the protected paths); with the files excluded from the copy, the CLI reads none of them | Q3, B1, §5 step 2, rule 1 |
| E9 | **`needs_context` re-issue.** The worker ends with `status: needs_context`; the harness discards its edits and re-runs it with a larger manifest | The re-issued call completes with the new input; no state leaks from the first call except through `home/` (record what is there) | ADR-004, D-30 |
| E10 | **No shell (`reviewer-readonly`).** `process-exec` limited to the CLI binary and its bundled read-only helpers | The CLI still produces its result without a shell | Q3, §5 presets |
| E11 | **Kill and escape.** Worker tries `nohup`, `setsid`, double fork; then the harness kills: TERM to the group and tracked PIDs, KILL after 10 s, marker scan, close the gateway port | No marked process survives; any survivor has no network after the port closes | Q4, ADR-005 §7 |
| E12 | **Failure classes.** Force `rate_limited`/`quota`, `timeout`, invalid output, a sandbox denial | Each maps to one ADR-004 failure class from exit code or output pattern | ADR-004 |

## macOS sandbox experiments (provider-independent)

Run with a fake CLI (a script) under the same profile; these are the seeds of the hostile-worker tests in architecture §3.

- **S1 Reads denied:** `~/.ssh`, `~/.zshrc`, `~/.config/gh`, another Step's folder, factory state, the Keychain (A2, ADR-005 Context).
- **S2 No route outside the sandbox:** `launchctl submit`/`bootstrap`, `open -a Terminal`, `osascript`, `kill`/`ps eww` on the orchestrator PID (B2).
- **S3 Network:** direct egress fails; another Step's gateway port is unreachable; a check-Step profile reaches only its own service ports (B8).
- **S4 Writes:** protected paths and lock files in `repo/` are caught by the diff check; writes outside `repo/`, `io/out`, `home`, `tmp` are denied; a restore-Step profile cannot write the shared caches (B3).
- **S5 Toolchain under the profile:** `dotnet build/test` and `npm` run offline against read-only caches with the builder preset; record the extra Mach services they need (§5, "doctor runs every check under the real profile").
- **S6 `sandbox-exec` status:** record the deprecation warning and behaviour on the current macOS; note any change since the previous release (Q3).
- **S7 OpenSpec archive (secondary):** run OpenSpec's own archive on fixture changes once and keep its output as the reference for the spec adapter's unit fixtures (Q8).

## Outcome per CLI (D-63)

| Result | Condition | Effect |
|---|---|---|
| `supported` | E1, E3, E4, E5, E6, E8, E10, E11 pass; E2, E7, E9, E12 recorded | Adapter can be written; the Mach allowlist and declared file list go into it |
| `unsupported` | E1, E3, E4, E5 or E11 fails (credential needs Keychain, Mach services cannot be narrowed, traffic bypasses the proxy, own sandbox cannot be turned off, escapes keep network) | The factory runs without this provider; `config validate` and the plan reject its profiles |
| `supported, usage not measured` | Supported, but E7 finds no quota | Usage threshold does not apply; `rate_limited` is the hard signal (Q5, §10) |

A gap in E6 (e.g. no JSON output) is not a failure: the result file is the contract (ADR-004).

## Exit criteria

The spike is done when all of these hold:
1. Every CLI has a `supported` or `unsupported` verdict with evidence (commands, profile, logs).
2. The findings state whether the supported providers still give enough distinct profiles for the diversity rule (D-10; a different provider is preferred). If no provider is supported, stop and escalate to the owner before any v1 code.
3. A per-CLI Mach allowlist and declared instruction/settings file list exist for every supported CLI.
4. S1–S5 pass with the fake CLI and with every supported CLI.
5. Every "verify" cell in the §4 Fit table is either confirmed or replaced with the observed value.

## What the spike produces

- `docs/spike/findings.md`: per CLI the verdict, versions, exact flags, env vars, credential mechanism, Mach allowlist, declared files, usage fields, failure patterns; and the S1–S7 results.
- Proposed updates to architecture §4 (Fit table), §5 (Mach allowlist, declared files) and §19 (each Q1–Q5, Q8 closed, narrowed or kept with new evidence),
  submitted as a PR for the owner. Decision changes go in as new entries in [decisions.md](../decisions.md), never as silent edits.
- Throwaway harness code and Seatbelt profiles in `spike/`, kept only as reference for `Factory.Station` and its hostile-worker tests.
