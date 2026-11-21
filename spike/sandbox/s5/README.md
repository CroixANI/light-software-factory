# S5: toolchain under the builder profile (spike task 2.3, issue #11)

Throwaway. `./run-s5.sh` builds a Step folder, fills read-only caches in `<step>/io/in/cache/{nuget,npm}` (setup, NOT sandboxed), then runs the
cases under `builder.sb` with the empty-env launcher. Output excerpts: `results/` (paths replaced by `<step>`, `<spike>`). Findings: `docs/spike/findings/sandbox-s5.md`.

- `launcher.sh`: copy of `harness/sandbox/run-sandboxed.sh` plus `--extra <fragment>` (so the harness files stay untouched). `run.sh`: toolchain env on top.
- `extra-dotnet.sb` (restore only), `extra-vstest-loopback.sb` (`dotnet test` only): the only additions to the profile; each was added after a concrete failure.
- `fixtures/`: one xunit test project (net10.0) and one npm project (`ms@2.1.3`). NuGet packages come from the local global-packages folder used as a feed (override with `NUGET_FEED`); npm needs the network once.
