# gemini slot, part A (spike task 3.5, issue #18): tested CLI is Antigravity `agy`

Throwaway. The issue says "gemini", but Google no longer supports the Gemini CLI; the owner replaced it with the Antigravity CLI (`agy`, native binary), so **`agy -p` is what was tested** (details and the discrepancy: [docs/spike/findings/gemini.md](../../docs/spike/findings/gemini.md)). Gemini CLI 0.70.0 was not exercised.

- `run-agy.sh`: runs `agy` under `../harness/sandbox/base.sb` + `agy.sb` (`(deny default)`, exec of the one `agy` file only) with an allowlist-only environment and an isolated `HOME=<step>/home`. Extra profile fragments are passed with `--extra-sb`, Mach services with `--mach` (one at a time). `--ro-token` makes the token file read-only inside the Step (E2).
- Profile fragments, each with the reason in its first lines: `hosts.sb` (`/etc/hosts` for `localhost`), `lsbind.sb` (loopback listen for agy's in-process language server), `shell.sb` + `pty.sb` (terminal tool: `/bin/zsh`, PTY), `tokro.sb` (read-only token).
- `login.sh` + `feed-code.sh`: log agy in **inside** a sandboxed Step (`agy acp --login`; Keychain and `open` are denied, so agy prints the URL). The one-time code is read from a 0600 file, piped to agy's stdin through a FIFO, never printed. Nothing is copied from the owner's own login.
- `try.sh`: one call + the gateway hosts it caused + the error/warning lines of agy's own log.
- Step folders: `../harness/build-step-folder.sh <id> <work-root>` with `<work-root>` outside the repo; gateway: `../harness/proxy/connect-proxy.mjs`. The token file and all raw logs stay outside the repository.

Commands and results: [docs/spike/findings/gemini.md](../../docs/spike/findings/gemini.md).
