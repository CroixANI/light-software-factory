# fake-cli (spike, throwaway)

Mimics a provider CLI in two role shapes (`reviewer-readonly`: no subprocess; `builder`: shell plus `dotnet`/`npm` probes).
Writes `<step>/io/out/result.json` (schema: `result.schema.json`, the common envelope of architecture §4). Python 3 stdlib only.

```bash
echo "prompt" | spike/harness/fake-cli/fake-cli.py --shape builder --step <step-dir> [--status done|blocked|needs_context]
spike/harness/fake-cli/validate.py <step-dir>/io/out/result.json     # stdlib validator (no jsonschema installed)
spike/harness/fake-cli/fake-cli.py --list-attacks
```

Hostile actions (S1-S5, E11) run only on request: `--attack NAME[=TARGET]`, repeatable. Each one only attempts; the outcome
(`succeeded` / `denied` + exception type) goes to `io/out/attacks.json`, not into `result.json`.
Survivor attacks (`nohup`, `setsid`, `double-fork`) start a marked `sleep` (env `FACTORY_MARKER=fake-cli-survivor`, `--marker-ttl`, default 30 s);
pids go to `tmp/survivors.txt`. Write attacks create new files only (never overwrite); the harness removes them.
`--invalid-output` writes a schema-violating result (E12); `--exit N` sets the exit code. `FACTORY_ORCH_PID` names the pid for `kill-orchestrator` / `ps-eww`.
