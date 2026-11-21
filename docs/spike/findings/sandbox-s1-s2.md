# S1/S2 findings: reads denied, no IPC route outside the sandbox

Task 2.1 of `spike-sandbox-and-providers`, experiments S1 and S2 (plan: [docs/spike/plan.md](../plan.md)), plus the extra requirement from #8 (argv/environment of other processes). Issue #9.
Evidence: [spike/sandbox/s1-s2/](../../../spike/sandbox/s1-s2/) (`run.sh`, `extra.py`, `mitigation.sh`; `results/` = current profile, `results-mitigated/` = candidate fix, `results/baseline/` = the same probes without sandbox). Paths in results are sanitised (`<home>`, `<repo>`, `<work>`).
Environment: macOS 27.2.1, Python 3.14 (Homebrew), profiles of task 1.4 (`spike/harness/sandbox/`, unmodified), launcher `run-sandboxed.sh`, both shapes (`reviewer-readonly`, `builder`), fake CLI `fake-cli.py` for the S1/S2 attacks it has, `extra.py` (ctypes) for the rest. Re-run: `spike/sandbox/s1-s2/run.sh`, then `mitigation.sh`.

## Verdict

| Experiment | Result |
|---|---|
| **S1 reads denied** | **PASS** in both shapes. Every protected target is denied; the Step's own folder stays readable (control). |
| **S2 no route outside the sandbox** | **PASS for exec, Mach and signals** (launchctl, open, osascript, security, kill; LaunchServices, Keychain, pasteboard, Apple Events lookups). **FAIL for process information**: `ps eww` is denied only at exec; the same data (orchestrator argv and environment) is readable via KERN_PROCARGS2 (extra requirement below). Overall S2: **FAIL with the current profile**, passes with the candidate. |
| **Extra (#8): argv/environment of other processes** | **FAIL with the current profile**: a worker reads argv and environment of any same-owner process (`sysctl KERN_PROCARGS2`). **Fixable** with a two-line rule, verified here with the fake CLI and the builder probes only (see below). |

So the exit criterion "S1–S5 pass" is not yet met for S2 until the rule below is adopted in `base.sb` (a later task or the owner's decision, since `spike/harness` is outside this task's declared files).

## Method

- `run.sh` builds three Step folders (`step-a` reviewer, `step-base` builder, `step-b` = "another Step", containing a canary file), a fake "factory state" folder with a credential canary, and starts an **orchestrator stand-in**: a Python process outside the sandbox with a secret in its **environment** and in its **argv** (random canary strings).
- Per shape it runs the fake CLI under the launcher with the attacks below, then `extra.py` (ctypes), then (builder only) the exec attacks through `/bin/sh -c` by absolute path.
- **Baseline** (same probes, no sandbox) shows every target exists and every call works, so a denial in the sandbox is the profile's doing, not a missing file. Positive controls: `read-path=<step>/home` and `<step>/io/out` succeed inside the sandbox; `procargs2-self` succeeds.
- Outcome words are the fake CLI's and `extra.py`'s (`denied` = EPERM/EACCES, or Mach kern_return 1100; anything else is `error`): `denied` = EPERM/EACCES, `error` = anything else, `succeeded`. No `error` outcome occurred for a protected target (all `denied`).

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

**Signals:** `kill-0` and `SIGTERM` on the orchestrator stand-in are denied (`kill -0 1` is denied in the baseline too, so it is no evidence); the stand-in was still alive after the run (results/*/orchestrator-after.txt). Baseline SIGTERM kills it.

**Caveat on "ps eww denied":** it is an exec denial only. The same information is available through the leak below.

## Extra requirement (#8): argv and environment of other owner processes

| Attack | Baseline | Current profile | Candidate profile |
|---|---|---|---|
| `sysctl(KERN_PROCARGS2, <orchestrator pid>)` | read; env and argv canaries found | **succeeded: env canary FOUND, argv canary FOUND** (both shapes) | denied |
| same, for the parent (the launcher; its argv carried the canary because the harness passed it on the command line) | read | succeeded | denied |
| same, for pid 1 | EINVAL | denied (EPERM; the sandbox changes the answer) | denied |
| `proc_listallpids` (orchestrator pid visible) | 859-867 pids across runs | **succeeded, pid visible** | denied |
| `proc_name`, `proc_pidpath` of the orchestrator | read | **succeeded** | denied |
| `sysctl kern.proc.all` (process table) | readable | denied | denied |
| `sysctl(KERN_PROCARGS2, self)` | read | succeeded | succeeded (control) |

**Answer to the decision B2/Q4 question:** it **succeeds** with the profile as it is: any worker can read the secrets in the argv and environment of the orchestrator and, by the same mechanism, of other processes of the owner (tested only on the Python stand-in and the launcher, not on a browser or terminal). Not a Step-to-Step issue only.

**Candidate rule (verified here):**
- Ad-hoc measurements on a copy of the assembled profile (the probe was a one-off, not committed): denying `process-info-pidinfo` alone stops `sysctl(KERN_PROCARGS2)` for every pid, including self, so that operation governs it *(inferred from this single-operation test)*; denying each other `process-info-*` operation alone, `(deny process-info-pidinfo (target others))`, `(deny sysctl-read (sysctl-name-prefix "kern.proc"))` and the `kern.procargs*` names had no effect.
- Candidate: replace base.sb's two lines `(allow process-info* (target self))` / `(deny process-info* (target others))` with `(deny process-info*)` and `(allow process-info-pidinfo (target self))`. `mitigation.sh` builds exactly this replacement (not an append) from a copy of the profile directory and re-runs everything; `spike/harness/sandbox/` itself was not edited (outside the declared files).
- Result (results-mitigated/): KERN_PROCARGS2, `proc_listallpids`, `proc_name`, `proc_pidpath` of other processes are denied, self still works; all S1/S2 results above are unchanged; the fake CLI writes a schema-valid `result.json` in both shapes and the builder's `sh`, `dotnet --version`, `npm --version` still work.
- **Side effect:** every other `process-info` operation on *self* is now denied too (rusage, codesignature, dirtycontrol, setcontrol, listpids...). Only the fake CLI and `--version` probes were run; a real CLI or runtime that calls `proc_pid_rusage(getpid())` or checks its own signature may fail.

**What the orchestrator must do:**
1. Adopt the replacement above in `base.sb` (and drop the "KNOWN LEAK" comments), then re-run S1/S2 and the toolchain checks. This is the recommended fix.
2. Until then, and as defence in depth: start the orchestrator and every helper it spawns **without secrets in the environment or argv** (read credentials from files or the Keychain at the moment of use, pass nothing on the command line). The same applies to other owner processes, which the factory cannot control, so (1) is required; (2) alone is not enough.
3. Open risks for the provider tasks (3.x), untested here (no real CLI): the self side effect above, and `proc_pidinfo` on a CLI's own children (not "self"). If a CLI breaks, add the narrowest allow (`process-info-pidinfo (target same-sandbox)`, or the failing self operation), re-run `extra.py`, record it.

## Surprises and limits

- Under the profile `/bin/sh` prints `Error opening /private/var/select/sh: Operation not permitted` (it cannot read its shell selector) and falls back; the exec attacks still run through it (results/builder/shell-attacks.txt). Already noted in MACH-SERVICES.md.
- The baseline controls use benign variants of the S2 commands (`launchctl help`, `open` without args, `ps eww -p <shell pid>`), not the exact attack commands; `launchctl bootstrap` was not tried separately from `launchctl submit` (both are the same exec denial).
- The `$(...)` capture of a background process keeps the pipe open (run.sh hung once); fixed by redirecting the stand-in's streams.
- `procargs2-parent` finds the canary only because `run.sh` passes the canaries on the launcher's command line; it is not an independent leak.
- Not covered: real provider CLIs (3.x), other Mach services a CLI may need (3.x), `sandbox-exec` deprecation (S6, #12), network (S3, #10), writes (S4).
