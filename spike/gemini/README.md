# gemini slot, part A (spike task 3.5, issue #18): tested CLI is Antigravity `agy`

Throwaway. The issue says "gemini", but the owner reported that Google no longer supports the Gemini CLI (not verified here) and replaced it with the Antigravity CLI (`agy`, native binary), so **`agy -p` is what was tested** (details and the discrepancy: [docs/spike/findings/gemini.md](../../docs/spike/findings/gemini.md)). Gemini CLI 0.70.0 was not exercised.

- `run-agy.sh`: runs `agy` under `../harness/sandbox/base.sb` + `agy.sb` (`(deny default)`, exec of the one `agy` file only) with an allowlist-only environment and an isolated `HOME=<step>/home`. Extra profile fragments are passed with `--extra-sb`, Mach services with `--mach` (one at a time). `--ro-token` makes the token file read-only inside the Step (E2).
- Profile fragments, each with the reason in its first lines: `hosts.sb` (`/etc/hosts` for `localhost`), `lsbind.sb` (loopback listen for agy's in-process language server; conflicts with S3, see findings E3), `shell.sb` + `pty.sb` (terminal tool: `/bin/zsh`, PTY), `tokro.sb` (read-only token).
- `login.sh` + `feed-code.sh`: log agy in **inside** a sandboxed Step (`agy acp --login`; Keychain and `open` are denied, so agy prints the URL). The one-time code is read from a 0600 file, piped to agy's stdin through a FIFO, never printed. Nothing is copied from the owner's own login.
- `try.sh`: one call + the gateway hosts it caused + the error/warning lines of agy's own log.
- Step folders: `../harness/build-step-folder.sh <id> <work-root>` with `<work-root>` outside the repo; gateway: `../harness/proxy/connect-proxy.mjs`. The token file and all raw logs stay outside the repository.

Commands and results: [docs/spike/findings/gemini.md](../../docs/spike/findings/gemini.md).

## Part B (spike task 3.6, issue #19)
Throwaway scripts for E6–E12 and S1–S5 with `agy`; results and method in [docs/spike/findings/gemini.md](../../docs/spike/findings/gemini.md), output in `logs-part-b.txt`.
- `mock-api.mjs`: a fake model endpoint for agy's enterprise-gateway route (`AGY_LLM_GATEWAY_URL`, no login, no quota); scripted turns, HTTP errors, a hang, request-body dumps into a private scratch dir. `bodyinfo.py` summarises a dumped body (tools, canaries, last turns).
- `part-b-lib.sh` (helpers), `part-b-e6.sh`, `part-b-perm.sh`, `part-b-e8.sh`, `part-b-e9.sh`, `part-b-e10.sh`, `part-b-e11.sh` (+ `e11-spawn.sh`, `e11-kill.sh`, `kill.sb`), `part-b-e12.sh`, `part-b-s1s5.sh` (+ `s1s5.sh`, `s5.sb`), `part-b-all.sh` (runs them all, redacted log).
- `part-b-real.sh` + `part-b-real-lib.sh`: the only runs against the real model (3 model calls in the script, plus one exploratory call made by hand before it); need a login made by `login.sh` (`LOGIN_HOME`), token copied read-only into neutral-path Steps. `SUMMARY_ONLY=1` re-prints the summary of an earlier run without any call.
- `with-timeout.pl`: TERM-then-KILL wall-clock limit (agy ignores SIGALRM, so `perl -e 'alarm'` does not work).
- Scratch directories (`SP`) must be outside the repository; request dumps, token copies and raw logs never go into it.
