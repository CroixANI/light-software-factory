# S1/S2 findings: reads denied, no IPC route outside the sandbox

Task 2.1 of `spike-sandbox-and-providers`, experiments S1 and S2 (plan: [docs/spike/plan.md](../plan.md)), plus the extra requirement from #8 (argv/environment of other processes). Issue #9.
Evidence: [spike/sandbox/s1-s2/](../../../spike/sandbox/s1-s2/) (`run.sh`, `extra.py`, `mitigation.sh`; `results/` = current profile, `results-mitigated/` = candidate fix, `results/baseline/` = the same probes without sandbox). Paths in results are sanitised (`<home>`, `<repo>`, `<work>`).
Environment: macOS 27.2.1, Python 3.14 (Homebrew), profiles of task 1.4 (`spike/harness/sandbox/`, unmodified), launcher `run-sandboxed.sh`, both shapes (`reviewer-readonly`, `builder`), fake CLI `fake-cli.py` for the S1/S2 attacks it has, `extra.py` (ctypes) for the rest. Re-run: `spike/sandbox/s1-s2/run.sh`, then `mitigation.sh`.

## Verdict

| Experiment | Result |
|---|---|
| **S1 reads denied** | **PASS** in both shapes. Every protected target is denied; the Step's own folder stays readable (control). |
| **S2 no route outside the sandbox** | **PASS** for launchctl, open, osascript, ps eww, security, kill (as exec/signal denials) and for the Mach lookups of LaunchServices, Keychain, pasteboard, Apple Events. |
| **Extra (#8): argv/environment of other processes** | **FAIL with the current profile**: a worker reads argv and environment of any same-owner process (`sysctl KERN_PROCARGS2`). **Fixable** with a two-line rule that was verified here (see below). |

So the exit criterion "S1–S5 pass" is not yet met for S2 until the rule below is adopted in `base.sb` (a later task or the owner's decision, since `spike/harness` is outside this task's declared files).

## Method

- `run.sh` builds three Step folders (`step-a` reviewer, `step-base` builder, `step-b` = "another Step", containing a canary file), a fake "factory state" folder with a credential canary, and starts an **orchestrator stand-in**: a Python process outside the sandbox with a secret in its **environment** and in its **argv** (random canary strings).
- Per shape it runs the fake CLI under the launcher with the attacks below, then `extra.py` (ctypes), then (builder only) the exec attacks through `/bin/sh -c` by absolute path.
- **Baseline** (same probes, no sandbox) shows every target exists and every call works, so a denial in the sandbox is the profile's doing, not a missing file. Positive controls: `read-path=<step>/home` and `<step>/io/out` succeed inside the sandbox; `procargs2-self` succeeds.
- Outcome words are the fake CLI's: `denied` = EPERM/EACCES, `error` = anything else, `succeeded`. No `error` outcome occurred for a protected target (all `denied`).

## S1: reads (results/reviewer-readonly/attacks.json, results/builder/attacks.json)

| Target | Baseline | Sandbox (both shapes) |
|---|---|---|
| `<home>/.ssh` | listed | denied |
| `<home>/.zshrc` | read | denied |
| `<home>/.config/gh` | listed | denied |
| `<home>/Library/Keychains/login.keychain-db` | read | denied |
| `/Library/Keychains/System.keychain` | read | denied |
| another Step's folder and a file in its `home/` | read | denied |
| factory-state folder and its credential file | read | denied |
| `<home>/Documents` and the repository's `spike/harness` | listed | denied |
| own `<step>/home`, `<step>/io/out` (control) | n/a | **succeeded** (as intended) |

Notes: targets were passed as absolute paths (`~` needs `getpwuid`, which the profile deliberately blocks; see MACH-SERVICES.md). The Keychain is protected two ways: the file reads above and the Mach lookups of `com.apple.SecurityServer` / `securityd.xpc`, both denied (below); `/usr/bin/security` is not exec-able (builder shell attack list, results/builder/shell-attacks.txt).

## S2: no route outside the sandbox

**Exec attacks** (fake CLI, both shapes): `launchctl submit`, `open -g -j -a Terminal`, `osascript -e 'return 1'`, `ps eww -p <orchestrator>` all `denied` (EPERM from `exec`, the binaries are not in the exec list). Builder shape through a shell: `/bin/launchctl`, `/usr/bin/open`, `/usr/bin/osascript`, `/bin/ps`, `/usr/bin/security`, `/bin/kill` all `Operation not permitted`, rc 126 (results/builder/shell-attacks.txt). Baseline: the same binaries run (`launchctl help`, `osascript`, `ps eww`, `security` rc 0; `open` rc 1 = usage), so exec denial is the only thing stopping them.

**Mach lookups** (`extra.py`, `bootstrap_look_up`, the "tested in S2" item of the README): LaunchServices (`com.apple.coreservices.launchservicesd`, `com.apple.CoreServices.coreservicesd`), Keychain (`com.apple.SecurityServer`, `com.apple.securityd.xpc`), pasteboard, Apple Events, `opendirectoryd.libinfo`, `cfprefsd.daemon`, `trustd`: all `kern_return 1100` in the sandbox, all `0` (found) in the baseline. So even a worker with its own binary cannot reach these services; the exec denial is not the only layer.

**Signals:** `kill-0` and `SIGTERM` on the orchestrator stand-in and `kill -0 1` are denied; the stand-in was still alive after the run (results/*/orchestrator-after.txt). Baseline SIGTERM kills it.

**Caveat on "ps eww denied":** it is an exec denial only. The same information is available through the leak below.

## Extra requirement (#8): argv and environment of other owner processes

| Attack | Baseline | Current profile | Candidate profile |
|---|---|---|---|
| `sysctl(KERN_PROCARGS2, <orchestrator pid>)` | read; env and argv canaries found | **succeeded: env canary FOUND, argv canary FOUND** (both shapes) | denied |
| same, for the parent (the launcher; its argv carried the canary because the harness passed it on the command line) | read | succeeded | denied |
| same, for pid 1 | EINVAL | denied (not owner) | denied |
| `proc_listallpids` (orchestrator pid visible) | 865 pids | **succeeded, pid visible** | denied |
| `proc_name`, `proc_pidpath` of the orchestrator | read | **succeeded** | denied |
| `sysctl kern.proc.all` (process table) | readable | denied | denied |
| `sysctl(KERN_PROCARGS2, self)` | read | succeeded | succeeded (control) |

**Answer to the decision B2/Q4 question:** it **succeeds** with the profile as it is: any worker can read the secrets in the argv and environment of the orchestrator and of every other process of the owner (browser, terminal, other tools). Not a Step-to-Step issue only.

**Narrower rule found (verified here):** KERN_PROCARGS2 is governed by the Seatbelt operation `process-info-pidinfo`.
- `(deny process-info-pidinfo (target others))` (what base.sb has in spirit) does **not** stop it; denying `sysctl-read` for `kern.procargs2` or `kern.proc*` names does not either (tested on a copy of the assembled profile).
- `(deny process-info*)` followed by `(allow process-info-pidinfo (target self))` **does**: the call on other pids fails with EPERM, the call on self still works, `proc_listallpids`, `proc_name`, `proc_pidpath` of others are denied too (results-mitigated/).
- With that rule the fake CLI still produces a schema-valid `result.json` in both shapes, and the builder's probes (`sh`, `dotnet --version`, `npm --version`) still work (results-mitigated/builder/result.json: `tools_used: sh, dotnet, npm`). All S1/S2 results above are unchanged (results-mitigated/*/attacks.json).
- `mitigation.sh` builds the candidate from a copy of the profile directory; `spike/harness/sandbox/` itself was not edited (outside this task's declared files).

**What the orchestrator must do:**
1. Adopt the two rules in `base.sb` (replacing the `process-info*` lines and the "KNOWN LEAK" comments), then re-run S1/S2 and the toolchain checks. This is the recommended fix.
2. Until then, and as defence in depth: start the orchestrator and every helper it spawns **without secrets in the environment or argv** (read credentials from files or the Keychain at the moment of use, pass nothing on the command line). The same applies to other owner processes, which the factory cannot control, so (1) is required; (2) alone is not enough.
3. Open risk for the provider tasks (3.x): a real CLI may call `proc_pidinfo` on its own children (not "self"). If a CLI breaks, add the narrowest `(allow process-info-pidinfo (target same-sandbox))` and re-run `extra.py`; record it. Not tested here (no real CLI in this task).

## Surprises and limits

- The `$(...)` capture of a background process keeps the pipe open (run.sh hung once); fixed by redirecting the stand-in's streams.
- `procargs2-parent` finds the canary only because `run.sh` passes the canaries on the launcher's command line; it is not an independent leak.
- Not covered: real provider CLIs (3.x), other Mach services a CLI may need (3.x), `sandbox-exec` deprecation (S6, #12), network (S3, #10), writes (S4).
