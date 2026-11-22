# codex spike, part A (task 3.3, issue #16)

Throwaway. Runs `codex exec` under the starting Seatbelt profile (`../harness/sandbox/base.sb` + `codex.sb`) with an allowlist-only environment. Results and exact commands: [docs/spike/findings/codex.md](../../docs/spike/findings/codex.md).

| File | What |
|---|---|
| `run-codex.sh` | launcher: builds the profile (`base.sb` + ancestor stat rules + `codex.sb` + extras + one `--mach` rule per service), empty environment + allowlist, `sandbox-exec` |
| `codex.sb` | CLI exec grant, write-protection of the credential copy, `requirements.toml` and CA-bundle reads |
| `shell.sb` | extras for the shell tool (`/bin/zsh`, `sh`, `bash`, a few coreutils; write to `repo/`) |
| `lib.sh` | `step <id>` (fresh Step folder + 0400 copy of `~/.codex/auth.json`), `runx` |
| `part-a.sh` | re-runs E1, E3, E4, E5 with fresh Steps; its output is `logs-part-a.txt` |
| `min-mach.sh` | greedy Mach allowlist minimisation (allow-default + deny mach-lookup + allowlist); a weaker proxy than the full profile |
| `shell-probe.sh`, `summarize.py`, `hosts.py` | one shell-tool run summarised from `--json`; gateway-log host counter |
| `mutate-auth.py` | E2: mutated credential copy with a dummy refresh token (never touches the owner's real one) |

Needs: the owner's file login in `~/.codex/auth.json`, `codex`, `node` >= 22, a scratch directory outside the repository (`SP`). The credential copy is mode 0400 inside the Step folder and must be removed with it; it is never printed or committed.
