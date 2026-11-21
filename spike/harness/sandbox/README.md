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
`--mach <service>` (repeatable, ad-hoc), `--show-profile` (prints the roots and the assembled profile on stderr; silent otherwise).

Environment given to the command (nothing else is inherited): `PATH`, `HOME=<step>/home`, `XDG_*`, `CLAUDE_CONFIG_DIR`, `CODEX_HOME`, `GEMINI_CLI_HOME` (all under `<step>/home`),
`TMPDIR=<step>/tmp`, `LANG`, `TERM=dumb`, `HTTP(S)_PROXY=http://127.0.0.1:<port>`, `FACTORY_STEP=<step id>` (the folder name). `fake-cli.py` treats `$FACTORY_STEP` as a path when `--step` is omitted, so always pass `--step`. The working directory is `<step>/repo`.
Real provider variable names are confirmed in tasks 3.x; the three above are the expected ones.

Rules: reads = system dirs, interpreter and node roots, the CLI dir, `<step>` (owner's home contents are unreadable; the ancestors of the allowed roots can be stat-ed, and `/` can be listed); writes = `home`, `tmp`, `io/out` (+ `repo` for builder);
network = only `localhost:<port>`; exec = interpreter (reviewer: no shell; builder: also `sh`, `bash`, `env`, dotnet, node); signals only within the sandbox (own process group is E11); process-info for self only; `sysctl-read` limited to a name list. **Known leak:** other owner processes' argv/environment stay readable via `KERN_PROCARGS2` (see MACH-SERVICES.md, S2 #9).
The launcher refuses a fixed list of broad roots (`/usr`, `/usr/local`, `/opt/homebrew`, ...), `$HOME` and any ancestor of `$HOME` or of the repository, and paths containing `"`, `(`, `)` or `\`. It is a guard against operator mistakes, not a proof. `launchctl`/`open` attacks are denied at **exec** (not in the exec list); the Mach-level exclusions are tested in S2 (#9).
Cache variables (`NUGET_PACKAGES`, npm cache, `PLAYWRIGHT_BROWSERS_PATH`) are deferred to S5 (#11).
Not yet restricted: toolchain caches, credential file (later tasks). `sandbox-exec` is deprecated (S6, #12).

Attack targets with `~` need `getpwuid` (a Mach service, deliberately not allowed): pass absolute paths, e.g. `--attack read-ssh="$HOME_OF_OWNER/.ssh"`; `~` then shows `error`, not `denied`.
