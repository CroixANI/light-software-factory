# Seatbelt starting profile and empty-env launcher (spike task 1.4)

Throwaway. `(deny default)` profile (architecture §5 layer 1) + allowlist-only environment (layer 2). macOS only, Python 3 and optionally Node.

Files: `base.sb` (common rules), `reviewer-readonly.sb` / `builder.sb` (shape-specific exec and write rules),
`run-sandboxed.sh` (launcher), `MACH-SERVICES.md` (each Mach service with its reason).

```bash
S=$(spike/harness/build-step-folder.sh demo)        # prints <step>
node spike/harness/proxy/connect-proxy.mjs --port 8901 --step demo > /dev/null &   # the Step's gateway
CLI=$PWD/spike/harness/fake-cli
echo "prompt" | spike/harness/sandbox/run-sandboxed.sh --shape builder --step "$S" --port 8901 --cli-dir "$CLI" -- \
  python3 "$CLI/fake-cli.py" --shape builder --step "$S"
"$CLI/validate.py" "$S/io/out/result.json"
```

`--shape reviewer-readonly|builder`, `--step <step-dir>`, `--port <gateway port>`, `--cli-dir <dir of the CLI, read-only>`,
`--mach <service>` (repeatable, ad-hoc), `--show-profile` (prints the assembled profile on stderr).

Environment given to the command (nothing else is inherited): `PATH`, `HOME=<step>/home`, `XDG_*`, `CLAUDE_CONFIG_DIR`, `CODEX_HOME`, `GEMINI_CLI_HOME` (all under `<step>/home`),
`TMPDIR=<step>/tmp`, `LANG`, `TERM=dumb`, `HTTP(S)_PROXY=http://127.0.0.1:<port>`, `FACTORY_STEP`. The working directory is `<step>/repo`.
Real provider variable names are confirmed in tasks 3.x; the three above are the expected ones.

Rules: reads = system dirs, interpreter and node roots, the CLI dir, `<step>` (so the owner's home is unreadable); writes = `home`, `tmp`, `io/out` (+ `repo` for builder);
network = only `localhost:<port>`; exec = interpreter (reviewer: no shell; builder: also `sh`, `bash`, `env`, dotnet, node); signals/process-info only for self.
Not yet restricted: toolchain caches, credential file (later tasks). `sandbox-exec` is deprecated (S6, #12).
