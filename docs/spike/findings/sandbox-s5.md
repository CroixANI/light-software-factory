# S5 findings: `dotnet build/test` and `npm` offline under the builder profile

Task 2.3 of `spike-sandbox-and-providers`, experiment S5 (plan: "Toolchain under the profile"), issue #11. Evidence: [spike/sandbox/s5/](../../../spike/sandbox/s5/) (`run-s5.sh`, `results/<case>.txt`, profile fragments).

## Setup
- macOS 27.2.1 (arm64), .NET SDK 10.0.100 (`net10.0`, xunit 2.9.3, Microsoft.NET.Test.Sdk 17.13.0, VSTest 18.0.1), Node v24.21.0, npm 12.0.2. `sandbox-exec` with the spike profile `builder.sb` over `base.sb` (task 1.4, unchanged), empty environment, `--port 8999` (nothing listens there).
- Caches are **read-only** inside the Step: `<step>/io/in/cache/nuget` (`NUGET_PACKAGES`) and `<step>/io/in/cache/npm` (`NPM_CONFIG_CACHE`). They sit under `io/in`, which the profile already lets the worker read and never write; nothing had to be added for them. They were filled before the run, outside the sandbox (`chmod -R a-w`). `npm`/NuGet are forced offline (`NPM_CONFIG_OFFLINE=true`; no feed is reachable).
- Toolchain env given through `/usr/bin/env` (the launcher's empty env cannot carry it): `NUGET_PACKAGES`, `DOTNET_CLI_HOME=<step>/home`, `DOTNET_NOLOGO`, `DOTNET_CLI_TELEMETRY_OPTOUT`, `DOTNET_SKIP_FIRST_TIME_EXPERIENCE`, `DOTNET_GENERATE_ASPNET_CERTIFICATE=false`, `MSBUILDDISABLENODEREUSE=1`, `DOTNET_CLI_USE_MSBUILD_SERVER=0`, `NPM_CONFIG_{CACHE,OFFLINE,UPDATE_NOTIFIER,AUDIT,FUND}`. Also `-p:NuGetAudit=false` (the audit feed is unreachable and only warns, NU1900).
- Method: failures were found by behaviour (denial lines are still not visible in `log show`), one rule added per concrete failure; the two fragments were re-tested as a whole by removing them (cases 00, 04), not rule by rule.

## Result: S5 passes (15 cases, 6 sandbox-message checks and info lines, all in `results/summary.txt`; no failures)

| Case | Result |
|---|---|
| 01 `dotnet restore` (offline, from the read-only cache) | pass, needs rule 1 (00: fails without it) |
| 02 `dotnet build --no-restore` | pass |
| 03 `dotnet test --no-build` | pass (1 test), **needs rule 2** (loopback) |
| 06 `npm ci --offline`, 07 `npm test` | pass, no extra rule |
| 04 `dotnet test` without rule 2 | fails (`SocketException (13)`), so the rule is necessary |
| 08/09 (these show offline behaviour and the proxy variable, not a profile block) install a package that is not cached (`npm`, `dotnet add package`) | fail: `ENOTCACHED`; NuGet `Connection refused (127.0.0.1:8999)` (the tool honours `HTTPS_PROXY`, so it goes to the Step's gateway port) |
| 10/11 write into the NuGet / npm cache | denied, message `Operation not permitted` checked (the caches are also `a-w`, so only the message proves the sandbox did it) |
| 12 write to the Step root (outside `repo/`, `io/out`, `home`, `tmp`) | denied |
| 13 direct TCP to 1.1.1.1:443 | denied, `code=EPERM` checked |
| 15/16 exec `/bin/cat`, `/usr/bin/git` | denied at exec (`Operation not permitted`) |

## Extra Mach services: none
`dotnet restore/build/test`, `npm ci` and `npm test` all pass with **zero** `mach-lookup` rules (the profile's Mach list stays empty, as for the fake CLI). The only Mach-related symptom is a harmless line `CSSM_ModuleLoad(): One or more parameters passed to a function were not valid.` from `dotnet restore` and `dotnet add package` (Security framework, X.509 chain code; no failure, the build continues with its own `trustedroots` bundle). Nothing in the Keychain/security family needs to be allowed (consistent with the architecture §5 exclusions). Caveat: only the offline paths were run, with NuGet signature verification at its default (the `CSSM_ModuleLoad` line suggests a Security framework call that failed quietly; a restore Step with verification enabled may need trust services); a real restore over the gateway uses TLS and may touch the Security framework again (to be seen when the gateway carries a real NuGet restore).

## Rules the toolchain needed beyond `builder.sb` (not Mach; both stay out of the base profile)
1. **`/tmp/.dotnet` read/write (+ stat of `/tmp`), restore only** (`extra-dotnet.sb`). NuGet's restore task takes the named mutex `NuGet-Migrations`, which .NET implements under `/tmp/.dotnet`; without it: `IOException ... stat("/tmp/", ...) == -1; errno == EPERM` (case 00, also with the first-use sentinels present). The dotnet CLI's own first-use code failed the same way in an ad hoc run (a fresh `HOME`, not kept as a case); pre-seeding the three sentinel files in `<step>/home/.dotnet` (`setup.sh`) removes that need: `build --no-restore` and `test` then pass without the rule (cases 02, 03). **Note for the Station:** `/tmp` is a symlink to `/private/tmp` and Seatbelt matches resolved paths; a rule generated at run time (from `TMPDIR` or a per-Step directory) must use the resolved path and allow the stat of the parent. **Cost:** `/tmp/.dotnet` is a host-wide directory shared by every dotnet process (the owner's too): a weak cross-Step channel (locks, shared memory); it also outlives the Step, so a Step could plant or hold files there and disturb the owner's own dotnet builds. **Recommendation:** grant it only to the restore Step (which already has its own profile, B3); builder/check Steps run `--no-restore` with pre-seeded sentinels and get no `/tmp` access.
2. **Loopback bind + connect on any port** (`extra-vstest-loopback.sb`). `dotnet test` (VSTest) listens on a random 127.0.0.1 port and the test host connects back; without it: `SocketException (13): Permission denied` in `SocketServer.Start` (case 04; `dotnet build` needs nothing). **Cost: breaks S3.** `network-outbound` to `localhost:*` also reaches other Steps' gateway ports and any local service, and `network-bind`/`network-inbound` let the Step **listen** on any loopback port: it could squat a port the orchestrator later hands out as another Step's gateway (receiving that Step's proxied traffic or blocking the gateway) and accept connections from other Steps. Not acceptable for a builder profile as is. Options (not tried): a profile that allows only an ephemeral range is not expressible per process; Microsoft.Testing.Platform / xunit v3 run tests in-process without the VSTest socket (`dotnet test` through MTP); a fixed VSTest port was not looked for beyond the `dotnet test` help (untried). Open item for the owner: either use an in-process test runner for dotnet Steps, or accept loopback for check Steps only (they already have service ports, §5) and re-run S3 with it.

## Other findings that change the design
- **The builder exec list is too small for real scripts.** `builder.sb` execs only `sh`, `bash`, `env`, `sleep`, the Python install, dotnet and node. `cat` and `git` (cases 15, 16; `tail` seen ad hoc) fail with `Operation not permitted` (e.g. `... | tail` in a build script). Also `Error opening /private/var/select/sh: Operation not permitted` on every `sh` (it falls back to bash and works). `npm test` runs the script through `sh` and works; scripts that call coreutils or `git` will not. Needs a decision: add a fixed list of coreutils to the builder exec rule, or forbid shell pipelines in worker scripts.
- **Node aborts at startup (exit 134) if its stdout/stderr is a regular file outside the readable roots** (case 14; stack in `InitializeOncePerProcessInternal`). A pipe works (every other case), and a file under `io/out` works; python and dotnet with a file outside the Step also work (info line in `summary.txt`). **The orchestrator must give the worker pipes or files inside the Step** (the Station already owns the logs under `io/out`).
- The dotnet host needs no rule for the `dotnet` install beyond `builder.sb` (the launcher already stats its ancestors); `MSBUILDDISABLENODEREUSE=1` and `DOTNET_CLI_USE_MSBUILD_SERVER=0` were set from the start to keep MSBuild from leaving worker nodes behind; their effect was not measured (no run without them).
- `dotnet restore` (not build) wrote `obj/` in `repo/` (allowed); `bin/obj` inside `repo/` count as changes for the diff check (architecture §5), so they must be ignored by the Station's diff or live in `.gitignore`.
- Timing was not compared with an unsandboxed run (a cold build took 20 s in one ad hoc run, 2 s in the matrix).

## Not covered (kept for later tasks)
- Real project shapes (multi-project solution, analyzers, source generators, `playwright`): only one project and one dependency set were used.
- Gateway-carried restore (TLS) for the restore Step: S4 / 3.x.
- Re-run with each real CLI as the parent process: part B of group 3.

## Proposed effect on the architecture (for the consolidation task 4.2)
- §5 "doctor runs every check under the real profile": add the two rules above as named, justified exceptions; state that the Mach allowlist for the builder preset stays empty for dotnet and npm.
- §5 Station: stdout/stderr of the worker are pipes or Step files; per-Step dotnet first-use sentinel pre-seeded; decide the coreutils question for the builder exec list.
