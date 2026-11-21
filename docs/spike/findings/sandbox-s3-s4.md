# S3/S4 findings: network egress and write confinement

Task 2.2 of `spike-sandbox-and-providers`, experiments S3 and S4 (plan: [docs/spike/plan.md](../plan.md)), issue #10.
Evidence: [spike/sandbox/s3-s4/](../../../spike/sandbox/s3-s4/) (`run.sh`, `probe.py`, `diffcheck.py`, `profiles/*.sb` = the exact profiles used, `results/<shape>/*.json|txt`, `results/baseline/` = the same probes without a sandbox). Paths in results are sanitised (`<work>`, `<repo>`, `<home>`). Re-run: `spike/sandbox/s3-s4/run.sh` (about 20 s, needs python3 and node; it starts and stops its own listeners and proxies).
Environment: macOS 27.2.1 (arm64), Python 3.14.5, Node v24.21.0, `sandbox-exec`. Profiles of task 1.4 (`spike/harness/sandbox/`, not edited). Fake CLI `fake-cli.py` for the attacks it has (`reach-github`, `push`, `connect-port`), `probe.py` for the rest.

## Verdict

| Experiment | Result |
|---|---|
| **S3 network** | **PASS.** Direct egress (TCP, UDP, DNS, mDNSResponder) fails in all four shapes. A worker reaches only its own gateway port; every other Step's gateway, the check-Step service ports and an unrelated local listener are `denied`. A check-Step profile reaches only its own service ports (modelled shape). Every denial is EPERM from the sandbox itself (the gateway log is not a detector for this: the proxy logs only CONNECT/HTTP requests, so a bare TCP connect would not appear in it either). |
| **S4 writes** | **PASS**, with one structural point: protected paths and lock files inside `repo/` **are writable by the builder** (by design, `repo/` is its workspace). They are caught by the diff check, not by Seatbelt (checked with a model of that check, `diffcheck.py`). Writes outside `repo/`, `io/out`, `home`, `tmp` are denied in every shape; a restore-Step profile cannot write the shared caches. |

Both pass for the **fake CLI and probe scripts**. They are not yet repeated with a real provider CLI (task 3.x, "re-run S1-S5"). The check-Step and restore profiles are **modelled here** (a patched copy of the profile directory; the repository's profiles only know `reviewer-readonly` and `builder`); the Station will need to generate them (see "For the Station").

## Method

- `run.sh` starts: four gateways (`connect-proxy.mjs`, one port per Step; step-a, step-b, restore, step-c), two check-Step "service" listeners (8913, 8914), one unrelated listener standing in for an orchestrator API (8915). All listen on 127.0.0.1. The service listeners send a banner; the gateways do not (own-gateway `succeeded` is a TCP handshake, corroborated by the CONNECT 200 through the same port).
- Four sandboxed runs, each in its own Step folder and with the launcher's empty environment: `reviewer-readonly` (gateway A), `builder` (gateway C), `check-step` (ports 8913 and 8914, no gateway), `restore` (gateway R, writes only the item overlay). The only change to the repository's profiles is mechanical: the network rule moves from `base.sb` into each shape file so a shape can replace it. `profiles/` has the assembled files.
- The caches and overlays are **owner-writable** files outside the Step folder, so a denial is the profile's doing and not a file mode. Each shape starts from the same cache and overlay state (reset between runs).
- **Baseline** (same probes, no sandbox) shows each target exists and each call works. Baseline outcomes other than `succeeded` (the baseline is not like-for-like for `deny-owner-home`, whose baseline marker sits in the work folder, and the external-IP probes time out): `refused` for the LAN/IPv6 addresses (the listeners bind 127.0.0.1 only), `error` for `127.0.0.2` (not routable on this host).
- Outcome words: `denied` = EPERM/EACCES, `refused` = ECONNREFUSED (the sandbox let the attempt through, nothing listened), `error` = anything else, `succeeded`.

## S3: network (results/\<shape\>/net.json, fake-cli-attacks.json)

| Probe | reviewer-readonly | builder | check-step | restore |
|---|---|---|---|---|
| own gateway port | **succeeded** | **succeeded** | n/a (no gateway) | **succeeded** |
| another Step's gateway port (all three others) | denied | denied | denied | denied |
| check-Step service ports 8913/8914 | denied | denied | **succeeded** (own ports) | denied |
| unrelated local listener 8915 | denied | denied | denied | denied |
| direct TCP `1.1.1.1:443`, `8.8.8.8:53` | denied | denied | denied | denied |
| direct UDP to `8.8.8.8:53` | denied | denied | denied | denied |
| `getaddrinfo("github.com")` | error (`gaierror`) | error | error | error |
| AF_UNIX `/var/run/mDNSResponder` | denied | denied | denied | denied |
| bind+listen on 127.0.0.1:8920 | denied | denied | denied | denied |
| fake CLI `reach-github`, `push` | error (no DNS), push denied at exec | same | same | same |
| fake CLI `connect-port` (another gateway / service port) | denied / denied | denied / denied | denied / **succeeded 8913** (own service) | denied / denied |
| CONNECT through the own gateway: allowed host | 200 | 200 | n/a | 200 (`registry.npmjs.org`) |
| CONNECT through the own gateway: other host | 403 | 403 | n/a | 403 |

Reading it:
- **Direct egress cannot happen**: raw TCP and UDP are denied, including an external IP on the Step's *own* gateway port number (`direct-ext-ip-on-gw-*-port`: EPERM at once in every shape, a timeout in the baseline). So the allowed rule is not "port N anywhere". Name resolution also fails (most likely because the resolver's Mach service is not allowed; not measured), so a missing DNS service is not the only barrier.
- **Gateway isolation is the sandbox's work**: connects to another Step's gateway port fail with EPERM at the sandbox (the unsandboxed baseline connects to the same ports). `results/proxy-events.txt` shows the allowlists at work (200 for allowed hosts, 403 for others, logged as `denied`); it is not evidence about bare connects, which the proxy does not log.
- **No listening**: a worker cannot open a listener (`network-bind` is denied by `(deny default)`), so a worker cannot become a service for another Step.
- **Check-Step**: with only its own two ports in the profile, it reaches those and nothing else, including no gateway. This confirms B8's design is expressible with the same Seatbelt mechanism; the port list is generated per Step.

### Findings and limits (S3)
1. **`localhost:<port>` matches local interface addresses, not only 127.0.0.1 (two observed: the LAN IP and `::1`).** With the reviewer profile, a connect to the machine's LAN IP on the Step's own gateway port was *let through* (`refused`, nothing listened there), as was `::1`; `127.0.0.2:<port>` and every other port were denied. For the Step's own port this is harmless **if the gateway binds 127.0.0.1 only**. Requirement for the Station: bind gateways to `127.0.0.1` explicitly, never `0.0.0.0`. (Observed for the connect side only; the proxy in this spike binds 127.0.0.1.)
2. **The hostname `localhost` does not resolve inside the sandbox** (`gaierror`), as no name does. Anything configured with `localhost` (proxy URLs, `ASPNETCORE_URLS`, Azurite endpoints, test runners) fails; use `127.0.0.1`. The launcher already sets `HTTPS_PROXY=http://127.0.0.1:<port>`. A check-Step's service URLs must be literal IPs too.
3. **Not tested:** traffic through the gateway to a real provider API; a worker holding a real socket opened before the sandbox (not possible with the launcher); IPv6 service ports; Unix sockets other than mDNSResponder (the base profile allows none, and no `network*` operation beyond the one rule is granted).
4. The check-Step "services" were Python listeners, not Azurite or an app under test; the point of the test is the port rule only.

## S4: writes (results/\<shape\>-writes/writes.json, diffcheck.txt)

| Probe | reviewer-readonly | builder | check-step | restore |
|---|---|---|---|---|
| new file / edit existing file in `repo/` | denied | **succeeded** | **succeeded** | denied |
| `packages.lock.json`, `package-lock.json`, `CLAUDE.md` edit, `.github/` in `repo/` (the sample repo still contains instruction files; the product removes them from `repo/` per §5 step 2, where a planted one would show as `added`) | denied | **succeeded**, then **flagged by the diff check** | same | denied |
| symlink in `repo/` pointing outside | denied | succeeded, **flagged by the diff check**; a write *through* it is **denied** (tested for builder and check-step only; elsewhere creating the symlink was already denied) | same | denied |
| `io/out`, `home`, `tmp` | succeeded | succeeded | succeeded | succeeded |
| Step root, `io/in`, `io/` (mkdir), another Step's `home` (create or edit), factory state, parent folder, owner's home, `rename` out of `repo/`, symlink at the Step root | denied | denied | denied | denied |
| shared caches: read | succeeded | succeeded | succeeded | succeeded |
| shared caches: create, append, truncate, unlink, chmod, mkdir, rename out | denied | denied | denied | denied |
| item overlay: read | succeeded | succeeded | succeeded | succeeded |
| item overlay: create / append | denied | denied | denied | **succeeded** |
| another item's overlay: create / append | denied | denied | denied | denied |

- **Caches untouched** after every run (`caches-after.txt`: same files, sizes and modes as before; they were owner-writable, so the profile did it). The restore profile wrote only the item's own overlay (`overlays-after.txt`: item 1 changed, item 2 not).
- **No marker** appeared in the owner's home, in the parent folder of the Steps, or in the symlink target (`through-symlink-effect.txt`).
- **Diff check model** (`diffcheck.py`: manifest path→sha256/mode/link excluding `.git`; the check flags protected paths, symlinks, mode changes, and any change by a reviewer or restore role). A benign builder run (edit a source file, add a source and a test file) is **not** flagged; the hostile run is flagged on `packages.lock.json`, `package-lock.json`, `CLAUDE.md`, `.github`, and the symlink (5 paths). The reviewer and restore runs left `repo/` untouched, so the check passes with "no differences". It is a model of architecture §5 steps 3-5, not the product's check.

### Findings and limits (S4)
1. **Lock files and instruction files are the diff check's job.** Seatbelt cannot express "writable except these files" more cheaply than the diff check does, and it need not: a builder run that touches them is flagged and discarded. Confirmed with the model. The protected list used in `diffcheck.py` is a starting point for the Station, not the decision.
2. **Writes through a planted symlink are denied** because Seatbelt matches the resolved path; so a symlink in `repo/` cannot be used to write outside during the run. The symlink itself would still travel back when the diff is applied, which is why the diff check must treat it as a flagged entry (and the orchestrator must never follow it, e.g. no `cp -R` of the snapshot into the worktree with link-following).
3. **`home/` and `tmp/` are writable by design**, so a Step can plant `home/.claude/CLAUDE.md`. That is not a repository change and is covered by D-27 and the CLIs' own flags (tasks 3.x), not by this profile.
4. **Restore profile and `repo/`:** the restore Step here has no `repo/` write at all (architecture: "the item's package overlay only"). `dotnet restore` writes `obj/project.assets.json` next to the project; whether the restore Step really can run without any write to `repo/` (or needs `RestorePackagesPath`/`--packages` plus `BaseIntermediateOutputPath` redirected into the overlay) is **not tested here**; S5 ran the builder shape and only offline restores. Record it when the Station builds the restore Step.
5. **The restore profile covers only the locked restore into the overlay.** §5's dependency step 3 has a registry-egress restore Step regenerate `packages.lock.json`/`package-lock.json` in `repo/`; that variant needs its own shape (e.g. `repo/` writable, lock files only by the diff check) and is not modelled here.
6. Write probes cover paths under the work folder and the owner's home only; `/private/tmp`, `/private/var/folders` and the read-only CLI directory were not probed (expected denied under `(deny default)`).
7. **Not tested:** hard links; `fcntl`/`flock`/xattr-based writes; writes by already-existing child processes after kill (E11, task 3.x); a restore through the real gateway; very large file counts; extended attributes or ACLs on the caches.

## For the Station

- Generate the profile per Step from a template: shape file + one network line chosen by role (gateway port, service-port list, or none). The check-Step and restore variants used here are in `spike/sandbox/s3-s4/profiles/`.
- Bind every gateway and service to `127.0.0.1` and use literal IPs in configuration (finding S3-1, S3-2).
- Lock files and instruction files (architecture §5 rule 1) and symlinks must stay flagged by the diff check (S4-1, S4-2). `.github/**` is a *rule path* under §5 rule 5 / D-50 (allowed when declared, high risk, human approval), not a protected path; `diffcheck.py` lists it, `Directory.*.props`, `nuget.config` and `.npmrc` only as a conservative model and omits `openspec/**` and `docs/adr/**`, so its list is neither the decision nor complete.
- Caches and overlays can be given to a Step as plain read rules; no further rule is needed for them to be read-only, only the absence of a write rule.

## Surprises

- `bind`/`listen` on loopback is denied with no extra rule, so a worker cannot act as a local server for other Steps.
- The first run of the harness had its service listeners silently not running (a heredoc and `</dev/null` on the same command); the baseline column showed `refused` for them, which is how it was caught. Lesson kept in the baseline: always check that a positive control succeeds before trusting a `denied`.
