# ADR-004 — Provider adapters map requests to a CLI command; typed I/O through files; the orchestrator owns the process

- **Status:** Proposed (2026-11-20; revised in revision 2 for A7, A22, D-53, D-58; revision 3 for B1, B9, D-62; revision 4 for B1, C4, D-65, D-66)
- **Relates to:** D-04, D-24, D-25, D-26, D-30, D-53, D-57, D-58, values 1 and 2

## Context
Three CLIs (`claude -p`, `codex exec`, Gemini CLI) differ in flags, output formats, usage reporting, effort support and their own sandboxes. Several details are unverified (facts.md covers only some of them). The factory needs one worker-call contract (D-25) whose safety does not depend on any CLI feature (D-26).

## Decision
- **Orchestrator (Station) owns** spawning a headless child process (D-57), the sandbox, environment, timeout, kill and accounting.
- An **adapter** (one small class per provider, in `Factory.Station`) does three things only:
  - `Probe()`: installed, version, credential usable without Keychain, usage if obtainable; also refreshes credentials outside any Step.
  - `BuildCommand(request)`: argv; extra allowlisted env vars, including every config/session location variable pointed at the Step's `home/`; CLI tool/permission flags derived from the preset; the CLI's flag to ignore project instruction/settings files where one exists; and the adapter's **declared list of instruction/settings files** (e.g. `CLAUDE.local.md`, `.mcp.json`; settled in the spike), which the Station excludes from copies and protects (B1); and the CLI's **own Seatbelt-based sandbox turned off**, because it cannot nest inside the Station's profile.
  - `ParseResult(exit, stdout, stderr, files)`: typed result, with usage fields that are each a value or `null` + reason, and a `failure_class`.
- **The request carries a workspace level** (`read/write`, D-53), derived from the role's preset rather than configured separately (B9), and a profile that must be in the confirmed plan's list for the role (D-58).
- **Primary I/O is files:** the manifest is materialised in `io/in/` (including role instructions and constitution from the config snapshot); the worker writes `io/out/result.json`, which is validated against the role's JSON Schema. A CLI's own structured output is used where it exists, but it is a convenience, not the contract.
- **One context mechanism in v1:** a worker that needs more context ends with `status: needs_context`. Its edits are discarded, and the step is re-issued with a larger manifest; the fetch is logged on the board. There is no live MCP tool (A22). A missing **dependency** is not context: the builder ends `blocked: dependency`, its edits are discarded (C4), and the orchestrator adds the approved package and re-issues the builder (D-65).
- **Fixed failure classes** (`timeout, rate_limited, provider_unavailable, invalid_output, policy_violation, crashed, cancelled`), each with one reaction. Retries only with new information: `crashed` is retried only if a re-probe shows something changed; there are no reservations (D-66).

## Consequences
- Adding a provider means adding one adapter and one registry entry; the safety and accounting code does not change.
- Unverified CLI features degrade to "not measured" or to the file contract, never to unsafe behaviour. A CLI that cannot run without Keychain, behind the proxy, or with its sandbox off is `unsupported`.
- Writing a result file is a write, so read-only presets may write only `io/out/`, which is outside `repo/` and enforced by Seatbelt.
- `needs_context` re-issues a whole call, which costs tokens. It is accepted for v1 because it gives one auditable path. A live tool can be reconsidered if the journal shows a high re-issue rate.

## Alternatives considered
- **Provider SDKs/APIs instead of CLIs:** contradicts D-04 (subscriptions through CLI logins).
- **Adapters as YAML command templates:** usage parsing and failure classification differ too much per provider; it would become a small language.
- **Rely on each CLI's stdout JSON as the contract:** formats differ and are partly unverified; the file contract is the same for all.
- **Live MCP `get_context` alongside `needs_context`:** two mechanisms for one job, and MCP support is unverified for all three CLIs (A22).
