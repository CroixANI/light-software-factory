# claude, part A: E1–E5 (task 3.1, issue #14)

Evidence: [spike/claude/](../../../spike/claude/) (`run-claude.sh`, `claude.sb`, `shell.sb`). Plan: [../plan.md](../plan.md). Part B (E6–E12) is task 3.2.

## Setup
- macOS 27.2.1 (arm64); Claude Code 2.1.330 (native Mach-O binary in `~/.local/share/claude/versions/`, symlinked from `~/.local/bin/claude`; the launcher resolves it and grants read + exec on that `versions/` directory only).
- Credential: a long-lived token from `claude setup-token` (owner login), stored in a 0600 file outside the repo, read by the launcher and passed **only** as `CLAUDE_CODE_OAUTH_TOKEN`. Never printed or committed.
- Step folder from `build-step-folder.sh`, a gateway from `connect-proxy.mjs --port 8911` (allow all, to see every host). Profile: `base.sb` + `claude.sb` (exec of the CLI dir). **No Mach rule at all.**
- Environment (empty + allowlist): `PATH=/usr/bin:/bin`, `HOME=<step>/home`, `CLAUDE_CONFIG_DIR=<step>/home/.claude`, `TMPDIR` and `CLAUDE_CODE_TMPDIR=<step>/tmp`, `LANG`, `TERM=dumb`, `HTTP(S)_PROXY=http://127.0.0.1:<port>`, `FACTORY_STEP`, `CLAUDE_CODE_OAUTH_TOKEN`, and the hygiene switches `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 DISABLE_TELEMETRY=1 DISABLE_ERROR_REPORTING=1 DISABLE_AUTOUPDATER=1`.

Command shape (prompt on stdin): `run-claude.sh --step <step> --port 8911 -- -p --output-format json`

## Results
| # | Result | Evidence |
|---|---|---|
| E1 Keychain-free credential | **pass** | Unsandboxed with an isolated `HOME` and then sandboxed with zero Mach rules: the call completes (`is_error=false`, one answer). Without the token variable the same run fails `Not logged in · Please run /login` (rc 1): the CLI finds no credential in the empty `HOME` and nothing in the Keychain (it cannot reach it). Mechanisms present in the binary: `CLAUDE_CODE_OAUTH_TOKEN` (used), `CLAUDE_CODE_OAUTH_TOKEN_FILE_DESCRIPTOR`, `CLAUDE_CODE_OAUTH_REFRESH_TOKEN`, `.credentials.json` in the config dir (not tested). |
| E2 Credential refresh | **not measured** (recorded) | The setup-token credential is a single long-lived token; no refresh happened in any run. Its expiry is not readable from the token and was not decoded. The refreshable route (`.credentials.json` / refresh-token variable) needs the owner's refreshable login, which lives in the Keychain; extracting it was not done. Open for part B / owner: how long the setup token lives, and what happens when it expires (expect `Not logged in`, so a `provider probe` must detect it before a Step starts). |
| E3 Mach allowlist | **pass: empty** | Whole run (auth, API call, Bash tool, JSON output) works with `(deny default)` and no `mach-lookup` rule, so Keychain/`security`, launchd job submission, LaunchServices, Apple Events and pasteboard are all denied. `mach-register`, `iokit-open`, `ipc-posix` stay denied. Not covered: the `dotnet`/`node` toolchain under the claude process (S5 proved it separately), TLS to anything other than the gateway. |
| E4 Proxy compliance | **pass** | All traffic goes through `HTTPS_PROXY`: over every run the gateway log shows exactly one host, `api.anthropic.com:443` (33 CONNECTs). With `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 DISABLE_TELEMETRY=1 DISABLE_ERROR_REPORTING=1` a first run also contacted `http-intake.logs.us5.datadoghq.com`; **that host disappears once those variables are set**, so they belong in the adapter's env allowlist. Pointing `HTTPS_PROXY` at a dead port (8999): no direct connection happens (the profile only allows `localhost:<port>`); the CLI retries until the harness timeout (rc 124 at 60 s) instead of failing fast: a `timeout` failure class, not a leak. |
| E5 Own sandbox off | **pass** | Setting: `{"sandbox":{"enabled":false}}` (also the default). With `enabled:true` inside our profile the CLI tries to start its own sandbox and the attempt fails (`Failed to initialize sandbox: EPERM ... listen '<step>/tmp/srt-mux-*.sock'` in `--debug-file`); with no `failIfUnavailable` it then runs the Bash tool **unsandboxed**, so nothing is nested and nothing is enforced by it. With `enabled:false` no sandbox line appears. Pass `--settings '{"sandbox":{"enabled":false}}'` (and verify in `doctor`). Tool allow/deny and permission flags (`--allowedTools`, `--permission-mode`) work independently of it. |

## Other findings
- **`/tmp/claude-<uid>` is created regardless of `TMPDIR`** (first run: `EPERM: mkdir '/tmp/claude-501'`). `CLAUDE_CODE_TMPDIR=<step>/tmp` redirects it (it then creates `<step>/tmp/claude-501`). Needs to be in the env allowlist; no profile rule for `/tmp` is needed.
- **The oauth token is not visible to the Bash tool** (`[ -n "$CLAUDE_CODE_OAUTH_TOKEN" ]` is false inside a tool call, with and without its sandbox): the CLI strips it from child environments. The token is visible to the CLI process itself and to anything that can read its environment (see the open KERN_PROCARGS2 leak in [sandbox-s1-s2.md](sandbox-s1-s2.md); the leak makes the token readable by *other* same-owner processes, so the orchestrator-side mitigation matters more for this token than for a file credential).
- The sample repo's planted `CLAUDE.md` / `CLAUDE.local.md` were **read** by the CLI in both runs (their canary strings were echoed back); `.claude/settings.json` `permissions.allow` was reported as ignored because the workspace is untrusted. This is E8 (part B), noted here only because it affects every Step: instruction files must be excluded from the copy or ignored by flag.
- `duration_api_ms` ~0.8–7 s for a one-word answer; cost ~0.03 USD per call with the default model (E7 is part B).

## Verdict for part A
E1, E3, E4, E5 pass for `claude` with the token route; E2 recorded as not measured. No part-A condition for `unsupported` was met. Final verdict waits for part B (#15).

## Proposed effect on the architecture (for task 4.2)
- §4 Fit table, claude: credential = `CLAUDE_CODE_OAUTH_TOKEN` from `claude setup-token` (owner login, no Keychain), env only; refresh = none (long-lived, expiry unknown).
- §5: Mach allowlist for claude = empty; env allowlist additions `CLAUDE_CODE_TMPDIR`, `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC`, `DISABLE_TELEMETRY`, `DISABLE_ERROR_REPORTING`, `DISABLE_AUTOUPDATER`; gateway allowlist = `api.anthropic.com`; own sandbox off via `sandbox.enabled=false`.
