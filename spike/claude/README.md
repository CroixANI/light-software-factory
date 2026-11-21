# claude, part A (spike task 3.1, issue #14)

Throwaway. `run-claude.sh` runs `claude -p` under `../harness/sandbox/base.sb` + `claude.sb` (`(deny default)`, **empty Mach list**, exec only the CLI binary), with an allowlist-only environment and the credential read from a file outside the repo (`~/.factory-spike/claude-token`, from `claude setup-token`) and by default piped to the CLI on fd 3 (`CLAUDE_CODE_OAUTH_TOKEN_FILE_DESCRIPTOR=3`, so the token is in neither argv nor the environment); `--env-token` passes `CLAUDE_CODE_OAUTH_TOKEN` instead. The token is never printed.
`shell.sb` is used only for E5 (lets the Bash tool run). Step folder: `../harness/build-step-folder.sh claude-e1 <work-root>`; gateway: `../harness/proxy/connect-proxy.mjs`.
Commands and results: [docs/spike/findings/claude.md](../../docs/spike/findings/claude.md).
