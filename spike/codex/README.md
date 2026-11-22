# codex spike, part A (task 3.3, issue #16)

Throwaway. Runs `codex exec` under the starting Seatbelt profile (`../harness/sandbox/base.sb` + `codex.sb`) with an allowlist-only environment. Results and exact commands: [docs/spike/findings/codex.md](../../docs/spike/findings/codex.md).

| File | What |
|---|---|
| `run-codex.sh` | launcher: builds the profile (`base.sb` + ancestor stat rules + `codex.sb` + extras + one `--mach` rule per service), empty environment + allowlist, `sandbox-exec` |
| `codex.sb` | CLI exec grant, write-protection of the credential copy, `requirements.toml` and CA-bundle reads |
| `shell.sb` | extras for the shell tool (`/bin/zsh`, `sh`, `bash`, a few coreutils; write to `repo/`) |
| `lib.sh` | `step <id>` (fresh Step folder + 0400 copy of `~/.codex/auth.json` with a **dummy refresh token**), `step_nocred`, `plant` |
| `part-a.sh` | re-runs E1-E5 (incl. the mutated-credential E2 runs) with fresh Steps and removes them on exit; its output is `logs-part-a.txt` |
| `min-mach.sh` | greedy Mach allowlist minimisation (allow-default + deny mach-lookup + allowlist); a weaker proxy than the full profile |
| `shell-probe.sh`, `summarize.py`, `hosts.py` | one shell-tool run summarised from `--json`; gateway-log host counter |
| `mutate-auth.py` | credential copy with a dummy refresh token (modes `dummy-refresh`, `old-last-refresh`, `bad-access-token`, `both`) and `show-exp` (token lifetimes, no values); never touches the owner's real file |

Needs: the owner's file login in `~/.codex/auth.json`, `codex`, `node` >= 22, a NEW scratch directory outside the repository (`SP`; `part-a.sh` refuses an existing directory it did not create). The credential copy is mode 0400 inside the Step folder; `part-a.sh` removes the Step folders on exit (other helpers do not: remove `$SP/work` yourself). It is never printed or committed.

## Part B (task 3.4, issue #17)
Results and commands: [docs/spike/findings/codex.md](../../docs/spike/findings/codex.md) (part B section); output of the final run of every script: `logs-part-b.txt`.

| File | What |
|---|---|
| `part-b-lib.sh` | helpers: `gwstart`/`gwstop` (gateway, optional host allowlist), `runx` (one `codex exec` run under the profile, 120 s wall clock), hygiene flag set `HYG` |
| `part-b-e6.sh` | E6 (model/effort flags, `--output-schema` strict-mode limits, `-o`), E7 (usage, quota from the rollout), E10 (no shell, tool inventory) |
| `part-b-e8.sh` | E8: which planted instruction/config/skill/rules files reach the model's context (read from the rollout), per flag set and with the files excluded |
| `part-b-e9.sh` | E9: `needs_context` re-issue with a discarded and rebuilt Step; control with a reused `home/` |
| `part-b-e11.sh`, `e11-spawn.sh`, `e11-kill.sh`, `kill.sb` | E11: escapes from the codex shell tool and the harness kill procedure (tool-shell group, marker scan) |
| `part-b-e12.sh`, `mock-api.mjs` | E12: API errors forced with a fake Responses API, plus unknown model, sandbox denial, invalid output, timeout |
| `part-b-s1s5.sh`, `s1s5.sh`, `s5.sb` | S1–S5 re-run with the codex shell tool as the worker |
| `result.schema.strict.json` | the envelope `fake-result/1` rewritten as an OpenAI strict-mode schema (all keys required, optionals nullable) |

Needs the same as part A. `SP` must be a NEW scratch directory outside the repository (or one made by these scripts: `part-b-lib.sh` refuses any other existing directory). Usage: `SP=<dir> LSF_CODEX_DIR=<this dir> H=<spike/harness> R=<run-codex.sh> bash part-b-e6.sh` (same for the other scripts; each starts the gateways it needs and stops them on exit, `part-b-e8.sh` and `part-b-e9.sh` expect one on 8961 allowing `chatgpt.com`, started with `. part-b-lib.sh; gwstart 8961 chatgpt.com`). The scripts write only under `$SP` (Step folders in `$SP/work/<their ids>`, prompt/output/gateway logs next to them) and start/kill only their own processes (gateways, mock, marked escape probes); remove `$SP/work` (it holds credential copies with a dummy refresh token and the live access token) when done.

**Known gaps of `logs-part-b.txt`:** it was produced before two prints were added to the scripts: the E8 stderr warning count (V0) and the E9 call-2 `status`; both facts were confirmed by hand and are named as such in the findings; the values appear in the log at the next run (a full re-run was not done on purpose: the quota is shared with the owner's Codex app). The last changes to `part-b-lib.sh` (`gwstop`), `part-b-e11.sh` (EXIT trap) and `part-b-s1s5.sh` (EXIT trap with `launchctl remove lsf.spike`, which runs outside the sandbox and was **not** executed during the review) were checked statically (`bash -n`) and with a dry run without model calls (gateway stop twice, marked-process cleanup on exit).
