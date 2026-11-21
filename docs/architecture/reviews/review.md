**Findings: 17 Important, 8 Nit.**

# Architecture review — Software Factory v1

Reviewed: `architecture.md` and `adr/ADR-001…007` against `README.md`, `requirements.md`, `decisions.md`, `values.md`, `glossary.md` and `facts.md`.
Notation: `arch:N` = `architecture.md` line N; `ADR-00x:N` = `adr/ADR-00x-*.md` line N; `dec:N` = `decisions.md`, `req:N` = `requirements.md`, `val:N` = `values.md`, `facts:N` = `facts.md`.
Statements about CLI behaviour that are not in facts.md are labelled **(not in facts.md — verify in spike)**.

---

## Important

### A1 — Workers share a persistent, writable provider state folder, so they can change the rules for later workers and read earlier workers' transcripts
- **Lens:** 2 (safety by structure); also 1 and 5.
- **Evidence:** `arch:131` and `ADR-005:13` let each Step write to "the provider's own state folder". `arch:132` passes "provider config-location variables from the registry", so every Step of a provider points at the same persistent folder under `_afworker`. `ADR-004:11` writes CLI settings into the per-call HOME, but the config-location variables point elsewhere. Codex keeps session logs that can be resumed (`facts:29`, "`resume`"). The three CLIs also keep global instruction files, settings, hooks and MCP server lists, and transcripts of past sessions, in that same folder **(not in facts.md — verify in spike)**.
- **Conflicts with:** value 4 "cannot … change the rules" (`val:22`); D-27 rules come only from a commit (`dec:199`); D-30 "never another worker's reasoning or transcript" (`dec:220`); D-11 no direct agent-to-agent messaging (`dec:87`); D-36 holdout scenarios are hidden (`dec:262`). The test author that writes the holdout tests (`arch:232`) leaves its transcript in that folder, where a later builder of the same provider can read it.
- **Impact:** One worker can plant global instructions, a hook or an MCP server, and every later worker of that provider will load it. This bypasses D-27 and the diff check. Builders can also read the holdout code and other workers' reasoning.
- **Remediation:**
  1. Split each provider's state into **credentials** (read-only to the worker, ideally one file or one environment token) and **session state** (per Step, under `work/<step-id>/home`, deleted with the copy).
  2. Point every config-location variable at the per-Step home. Copy only the credential file in, or mount it read-only through Seatbelt (`file-write*` deny).
  3. Deny the Seatbelt profile writes to anything outside `repo/`, `io/out/`, `home/` and temp.
  4. Add hostile-worker tests that plant a global instructions file, a settings file with a hook, and an MCP entry, then check that the next Step does not see them.
- **Fix:** local edit (the spike decides the per-CLI credential layout).

### A2 — The Seatbelt profile limits only writes and network; reads are open across Steps, into the owner's home and into provider credentials
- **Lens:** 2.
- **Evidence:** `arch:131` and `ADR-005:13` set rules only for writes and outbound network. `arch:348`: all copies sit in one folder shared with the `_afworker` group (`2770`), and every Step runs as the same user. `arch:158`: gate and holdout checks run as `_afworker`, so the holdout tests have to be inside a `work/` copy that `_afworker` can read. That contradicts `arch:157` ("the worker user cannot read …"). `ADR-005:12` claims `_afworker` "cannot read the owner's home". On macOS, the owner's home folder (`~`) is world-readable by default and many dotfiles are `0644` **(not in facts.md — verify)**. Gate Steps execute code the agents wrote, and they run as the same user that holds the provider logins. `ADR-005:14` gives gate Steps the provider API hosts as well. The per-step `FACTORY_CALL_TOKEN` (`arch:132`) can be read by any process of the same user through `ps eww`.
- **Conflicts with:** D-36 (holdout hidden from the builder), D-26 "no credentials in workers" in spirit, value 4, and lens 2 "read holdout scenarios / leak credentials".
- **Impact:** With 2 slots, item A's builder can read item B's holdout-check copy, including the holdout test code, and every other concurrent copy and manifest. Agent-written test code in the gate can read the owner's provider OAuth tokens and call the provider APIs directly (see A13). World-readable files in the owner's home, such as `.npmrc`, `.gitconfig` and shell history in some setups, are exposed.
- **Remediation:**
  1. Make the Seatbelt profile deny reads by default: allow `/System`, `/usr`, the curated toolchain directories, the Step's own `work/<step-id>/`, and that Step's credential file only.
  2. Give each Step's folder `0700`, owned by `_afworker`. Do not use a shared group folder. Let the orchestrator read it through a `sudo -u _afworker` helper (see A6).
  3. Gate, red and holdout check Steps get **no** provider credentials and no provider API hosts. Allow only package registries and localhost.
  4. Make the holdout check a separate Step that never runs concurrently with a worker Step of the same item, and whose folder no other Step can read.
  5. Pass the context token through `io/in/` with mode `0600`, not through the environment.
  6. Add hostile-worker tests that read a concurrent Step's copy, the owner's `~/.zshrc` and the provider credential file from a gate Step.
- **Fix:** local edit.

### A3 — Pushing a branch runs agent-written code in GitHub Actions with repository secrets and `GITHUB_TOKEN` before any human has seen it
- **Lens:** 2.
- **Evidence:** `arch:154`: sensitive paths, including `.github/workflows/**`, are allowed once there is a **plan** approval, which is bound to the plan hash and is given before any code exists (`arch:263`). `arch:176` and `ADR-007:14`: the orchestrator pushes `factory/*` and opens the PR. Workflows that trigger on `push` or `pull_request` run the workflow file **from the pushed branch** and execute the code the agents wrote, with secrets and a token **(GitHub behaviour, not in facts.md)**.
- **Conflicts with:** D-14 "Sensitive paths and CI workflow files always need a human" and "approval tied to a commit SHA" (`dec:108`); value 4 "cannot push, merge … leak credentials"; D-26 (`dec:192`).
- **Impact:** A builder can write a workflow, or change code that an existing workflow runs, that uses the `GITHUB_TOKEN` to push, merge or approve, or that exfiltrates Actions secrets. The orchestrator's push is the trigger, so no human sees the code first. This is the one path in the design by which a worker can push or merge.
- **Remediation:**
  1. If a diff touches `.github/**`, require a human approval **of the diff**, bound to its SHA, before it is pushed. Approving the plan is not enough.
  2. Have `doctor` check the repository settings and fail on unsafe ones: `default_workflow_permissions = read`, "Allow GitHub Actions to create and approve pull requests" off, branch protection on `main`, and, if possible, no repository secrets available to `factory/*`, for example through environments with protection rules.
  3. Record the assumption in ADR-007.
- **Fix:** needs an owner decision on what CI and secrets target repos may have; the rest are local edits.

### A4 — A GitHub "answer" comment from the owner login cannot be told apart from the factory's own comments, which contain agent text
- **Lens:** 2 (agents never count as humans).
- **Evidence:** `ADR-007:10`: every GitHub write goes through the **owner's** `gh` login. `ADR-007:13` and `arch:306`: an answer counts if "its author is the authenticated owner login and it follows the escalation comment". `arch:304`: escalation comments contain options, a recommendation and evidence written by agents. The PR bodies and follow-up issues written by the orchestrator also come from that login (`arch:176`).
- **Conflicts with:** D-14 "Agent approvals never count as human approvals" (`dec:108`); D-20 (`dec:150`); `arch:265` claims only two paths can create a human approval.
- **Impact:** Agent text that reaches a factory-posted comment, such as a later escalation on the same issue or an acknowledgement, can contain a line like `answer 1`. That line is then parsed as the owner's answer. Answers include high-risk plan approvals and holdout approvals.
- **Remediation:**
  1. Ignore any comment that the factory created. Track the ids of created comments in the store, and skip comments that contain any `factory:` marker.
  2. Accept only a comment whose **first line** matches `answer <n>` or `answer: …` and that names the question id, for example `answer q-17 2`.
  3. Quote or escape agent text in mirrored comments, for example as a blockquote, so it can never start a line with `answer`.
  4. Add a test in which an agent rationale contains `answer 1`.
- **Fix:** local edit.

### A5 — The builder can weaken the gate and the constraint rules through unprotected files, and can disable red tests without editing them
- **Lens:** 2; also 1.
- **Evidence:**
  - `arch:150`: the protected paths are only `.factory/**`, `openspec/**`, `docs/adr/**` and `.git/**`.
  - `arch:332` and `arch:458`: the enforceable constraint rules live in `tests/` and in the ESLint boundaries. Neither is protected.
  - `arch:372`: the default sensitive list does not cover `Directory.Build.props`, `.editorconfig`, the ESLint, Prettier and Playwright config files, `*.runsettings`, the `.sln`, or the scripts section of `package.json`. The architecture's own `web-lint` check (`arch:367`) runs a script that the builder can redefine.
  - `arch:153`: the red-test lock covers only files the test author touched.
  - `arch:173`: `gating` passes when "all checks pass". Nothing checks that the red tests actually **ran**.
  - The test-count ratchet (`arch:460`) compares with the baseline on main. That baseline does not include the new red tests, so disabling them still passes the ratchet.
- **Conflicts with:** D-22 "Changing the constraints is high risk and needs a human" (`dec:164`); D-26 "may not touch red-step tests" (`dec:192`); D-27 (`dec:199`); value 4 "cannot change the rules".
- **Impact:** Possible moves include setting `TreatWarningsAsErrors=false`, setting analyzer severities to `none`, editing an architecture test, changing `"lint": "true"`, or removing the new test project from the solution. Each one produces a green gate on code that breaks the constraints or never passes the red tests.
- **Remediation:**
  1. Add a built-in, non-removable list of **gate-defining paths**: the build props and targets, `.editorconfig`, lint and format configs, test-runner configs, solution files, the `scripts` of `package.json`, and the folder named in the constitution for constraint tests. Treat it as protected, or as sensitive with a human diff approval.
  2. Have the red check record the **test IDs** of the red tests. Have `gating` parse the TRX/JUnit output and fail if any of those IDs did not execute and pass.
  3. Optionally, run the gate commands from definitions in the config snapshot, not from scripts in the repo.
- **Fix:** local edit.

### A6 — The kill switch, timeouts and clean-up do not work across the user boundary on macOS
- **Lens:** 2 and 4.
- **Evidence:** `arch:130` launches workers with `sudo -n -u _afworker sandbox-exec …`. `arch:93` handles a timeout by "kill the process group". `arch:226` makes `factory kill` kill "all worker process groups". `arch:127` and `arch:186` have the orchestrator delete copies. The orchestrator runs as the owner. A process of the owner cannot signal processes of `_afworker`, and `sudo` does not forward `SIGKILL`. A worker can also `setsid` or daemonise and leave the process group. Files created by `_afworker` in subfolders it created are not removable by the owner, because the setgid bit sets the group but not group-write, and sudo resets the umask to `0022` **(POSIX/macOS behaviour, not in facts.md)**. After the orchestrator crashes, its `sudo` children keep running. The resume step (`arch:186`) does not mention them.
- **Conflicts with:** D-38 "A kill switch stops everything" (`dec:276`); D-19 wall time per item (`dec:143`); D-28 "a limit stops new work" (`dec:206`).
- **Impact:** Workers that keep running after kill, timeout or a crash go on spending subscription quota. They can also change a copy **after** the orchestrator has hashed it, between the hash and the apply (`arch:126-127`), which defeats the diff check. Copies cannot be deleted, so `work/` grows without bound.
- **Remediation:**
  1. Add narrow sudoers helpers that run as `_afworker`: `kill-step <step-id>`, which kills every `_afworker` process whose Seatbelt profile or working directory belongs to that Step (or `pkill -u _afworker` when killing everything), and `rm-step <step-id>`.
  2. Before hashing, confirm that no `_afworker` process for the Step remains. Then hash and apply from an APFS clone of `repo/` taken after that check, so the apply cannot race a live process.
  3. On resume, first kill every `_afworker` process, then clean up.
  4. Add hostile-worker tests that use `nohup` and `setsid` and then check that kill and timeout still work.
  5. Alternatively, drop the separate user (see N7). Same-user processes are trivially killable.
- **Fix:** local edit.

### A7 — As specified, workers and gates cannot build or test inside the station
- **Lens:** 4.
- **Evidence:**
  - `arch:123` and `arch:132`: HOME is an empty folder for each call.
  - `arch:131`: network goes only to the gateway. `arch:147`: the builder preset has "no web". `arch:158`: only gate Steps get the package registries. A builder or test author running `dotnet test` and `npm` in its copy therefore has no NuGet or npm cache and no egress to the registries.
  - `arch:171`: the red check needs a build. `arch:363` and `arch:369`: the gate uses `npx azurite` and `npx playwright test`. Playwright browsers live in a per-user cache, but `doctor` checks them for an unspecified user (`arch:402`).
  - `arch:112` and `arch:133`: the CLIs' own sandboxes are kept as an "extra layer". On macOS, Codex's sandbox (and Claude Code's optional sandbox) is itself Seatbelt, and Seatbelt cannot be nested inside `sandbox-exec` **(not in facts.md — verify)**.
- **Conflicts with:** D-45 (red step), D-46 and D-47 (Azurite and Playwright with no Docker; `doctor` checks them), D-29 (a check that could not run is a failure, so every item would fail).
- **Impact:** Builds fail at package restore. Every gate run re-downloads all packages and Azurite, and possibly the browsers. CLI shell tools may fail when they apply the inner sandbox.
- **Remediation:**
  1. Create shared, read-only caches owned by `_afworker` and filled by `doctor` or `init`: the NuGet global packages folder, the npm cache, `PLAYWRIGHT_BROWSERS_PATH`, and an Azurite install. Pass their locations in the environment allowlist.
  2. Restore packages in a check Step that has registry egress before every worker Step that has `run commands`. Workers then run offline.
  3. Turn off each CLI's own Seatbelt-based sandbox when it runs inside the outer profile, and record this in ADR-005.
  4. Have `doctor` run every check as `_afworker` under the real profile.
- **Fix:** local edit.

### A8 — Most item plans are never critiqued; the council runs only when the planner raises a question itself
- **Lens:** 1.
- **Evidence:** `arch:169`: `planning` goes straight to `red` when the plan has no design questions. `arch:242`: the council is "used for `design` Questions raised in the item plan". Nothing critiques the plan itself; the spec lens looks only at the diff, after building (`arch:249`).
- **Conflicts with:** R3 "For every item the factory runs an analysis, critiques it and changes it if needed" (`req:21`); D-06 "councils vote on … design **and plan** decisions" (`dec:52`); README "council votes on discrete design options" in every item's flow (`README:21`).
- **Impact:** The planner is the only judge of whether a question exists. An unquestioned plan (wrong approach, wrong declared files, wrong e2e decision) is caught only after red, building, gating and review have spent their tokens.
- **Remediation:**
  1. Add one critique Step at the end of `planning` that is not a new role and has a typed output. Either a critic with a `plan` lens returns findings, or the council votes on `accept plan / revise (reason)`.
  2. A `revise` result sends the plan back to the planner once, with the findings as new information.
  3. Let the critique also check the e2e decision (see A9).
- **Fix:** needs an owner decision (per-item cost compared with R3).

### A9 — The E2E decision happens in the wrong order: the human never sees the planner's decision, and the lens checks it only after building
- **Lens:** 1 and 5.
- **Evidence:** `arch:223`: the plan preview, which costs no tokens, shows a **heuristic** default. `arch:464`: the planner may change values that are not pinned **after** confirmation. `arch:249`: the spec lens checks `not-applicable` reasons during `reviewing`. `arch:175`: `reviewing` can lead only to `building`, and the builder may not write red-step tests (`arch:153`). There is no way back to `red`.
- **Conflicts with:** D-44: the planner proposes, the spec lens checks, and "the human can override in the plan preview" (`dec:318`). D-45: E2E tests are written in the red step (`dec:325`). D-28 (`dec:206`) as the cause of the tension.
- **Impact:** A wrong `not-applicable` is found after building. Either the builder writes the E2E tests, which breaks test-first, or the item is parked. The human's override applies to a heuristic, not to the decision that is actually made.
- **Remediation:**
  1. Check every `not-applicable` before `red`, as part of the plan critique in A8.
  2. If the planner changes the heuristic, park the item for human confirmation, or show the change in the Inbox as a non-blocking notice. The owner chooses which.
  3. Add a `reviewing → red` (re-red) transition for an e2e decision found wrong late.
  4. Write in §17 that D-44's "plan preview" is reinterpreted as a heuristic plus a later notice.
- **Fix:** needs an owner decision.

### A10 — Paths into `red` skip re-planning, the file-overlap check and the high-risk approval
- **Lens:** 4; also 2.
- **Evidence:** `arch:169`: `planning` leads to `deciding` **or** to `parked` for high risk, with no stated order. `arch:170`: `deciding` succeeds straight into `red`. The overlap check appears only at the exit from `planning` (`arch:169`), while the lock is taken at `red` (`arch:182`). `parked → resume_state` (`arch:179`) does not repeat the check. The item plan, with its declared files and red tests, was written **before** the council chose an option.
- **Conflicts with:** D-38 "run in parallel only when … declared files do not overlap" (`dec:276`); D-14 / §8 "plan approval before `red`" (`arch:263`); D-12 / D-06 (a decision that the plan does not reflect).
- **Impact:** Two items can both reach `red` holding overlapping locks. This happens when item A goes `planning → deciding` and item B takes the files meanwhile. A high-risk item with design questions skips plan approval, then hits refusal rule 5 (`arch:154`) and parks. If the council picks an option the planner did not assume, the declared files are stale and the builder gets `policy_violation`.
- **Remediation:**
  1. Make `deciding → planning` (revise with the decided options as input; no new questions) the success path.
  2. Take "check the overlap and acquire the lock" as one atomic transition on **every** entry into `red`.
  3. Fix the order planning → deciding → approval → red, and re-check the approval binding on entry into `red`.
- **Fix:** local edit.

### A11 — Files the orchestrator writes on item branches will conflict between parallel items, parking almost every second PR
- **Lens:** 4.
- **Evidence:** `arch:460`: an improved ratchet value is written into `.factory/ratchet.yaml` on the **item branch**. Test count is one of the metrics, and it rises with every item. `arch:245`: council ADRs are rendered into `docs/adr/` on the item branch, so parallel items may pick the same sequence number. These files are outside the declared-file locks (`arch:182`). `arch:177`: when `pr_open` merges main into the branch and gets a conflict, the item goes to `parked`.
- **Conflicts with:** D-38 "predictable conflicts" (`dec:276-277`); D-37 (`dec:269`).
- **Impact:** Once the first of two parallel PRs merges, the second almost always conflicts on `ratchet.yaml` and parks for a human.
- **Remediation:**
  1. Tighten ratchet baselines only in the group's closing PR, or resolve `ratchet.yaml` conflicts deterministically with a strictest-value merge done by the orchestrator.
  2. Name ADRs by question id (`docs/adr/q-<id>-<slug>.md`), not by sequence number.
  3. Let the orchestrator auto-resolve conflicts only in files it writes itself; park on everything else.
- **Fix:** local edit.

### A12 — Configuration drifts during a run: later items branch from a newer main
- **Lens:** 1 and 2.
- **Evidence:** `arch:223`: the config comes from the base commit. `arch:182` and D-37: a dependent item starts from **current** main. `arch:177`: main is merged into open branches. `arch:234`: retrospective and Config-screen PRs (`arch:319`) change `.factory/**` and can merge mid-run. The copy contains `.factory/constitution.md` and the role files from the item head (`arch:123`). The manifest kind `instructions` (`arch:79`) does not say which commit it comes from.
- **Conflicts with:** D-27 "a run reads the factory config, roles and constraints from the commit it started on" (`dec:199`).
- **Impact:** Workers can read a constitution or role instructions that differ from the confirmed snapshot. The gate uses the snapshot while the copy holds the newer files, so behaviour is mixed and cannot be audited.
- **Remediation:**
  1. Deliver the constitution and role instructions **only** through the manifest, from the snapshot.
  2. When polling sees a change to `.factory/**` on main, stop starting new items and mark the run `expired` (re-plan) or `draining`.
  3. Exclude `.factory/**` from the copies, or treat it as unreadable.
- **Fix:** local edit.

### A13 — Budgets have accounting holes: items start without a reservation, killed work is not charged, and direct API use is not metered
- **Lens:** 4 and 5.
- **Evidence:** `arch:294`: before an item leaves `queued`, the run's remaining budget "must cover the item's estimate", but nothing is reserved. Two slots therefore check against the same remainder. `arch:186`: abandoned Steps "release their reservations" instead of being charged. `arch:99` and `arch:226`: cancelled Steps are re-issued, and their spend is not stated. `arch:142` and A2: commands can reach provider API hosts with the provider credentials, which the CLI never reports. `arch:85`: when usage is `null`, it is charged at the estimate, so a provider that reports nothing never pushes a budget past its limit.
- **Conflicts with:** D-28 "Budgets are reserved before dispatch" (`dec:206`); D-19 (`dec:143`); value 1 test "every run reports spend against its budget" (`val:9`).
- **Impact:** A run can admit items it cannot finish; they then park mid-way. After a crash or kill, real spend is missing. Agent-written code can spend quota outside any budget.
- **Remediation:**
  1. Reserve the item's estimate at run and group scope when the item leaves `queued`, and draw each Step's reservation from it.
  2. Charge abandoned, cancelled and timed-out Steps at their reservation, flagged `estimated`.
  3. Block provider hosts for commands: allow them only for the CLI process itself, or at minimum for the CLI's own connections through the gateway, and deny them for gate and check Steps (A2).
  4. Count Steps and wall time as a budget dimension that always works, alongside tokens that may not be measured.
- **Fix:** local edit.

### A14 — Every worker gets the whole repository, and its reads are not logged
- **Lens:** 5 and 1.
- **Evidence:** `arch:79`: the repo copy is a manifest entry, "readable on demand". `arch:120`: there is "one disposable copy per worker Step" for **every** role, including council voters, the judge and the moderator. `arch:85`: `context_reads` are recorded only "when the CLI reports them". `arch:249`: each critic lane gets a full copy.
- **Conflicts with:** D-30 "manifest of exactly what it receives (spec slice, plan, diff, gate results) … extra context is fetched on demand through tools and logged on the board" (`dec:220`); value 2 "never … a repository dump" and its test "extra context is fetched by a tool and logged" (`val:12-13`); D-11 "read … only through the orchestrator" (`dec:87`).
- **Impact:** Agentic CLIs explore the copy freely. This costs tokens that no budget line explains, and the board cannot show what a worker actually read (value 5).
- **Remediation:**
  1. Give no workspace to council voters, the judge or the moderator; they work from the manifest alone.
  2. Give critics and verifiers a sparse copy: changed files, declared files and the spec slice. Anything else they fetch through `needs_context`.
  3. Keep a full copy for the builder and the test author, who need it to build, and log their reads where the CLI reports them, or through Seatbelt file-read tracing.
  4. Record in §17 that this is the trade-off.
- **Fix:** needs an owner decision on whether a readable copy of the repo counts as a "repository dump".

### A15 — Voters and the judge receive other workers' rationales
- **Lens:** 1 and 5.
- **Evidence:** `arch:246`: the judge receives "the published vote rationales", and round-2 voters get "an unattributed summary of the arguments". §17 (`arch:515`) lists D-30 as honoured, with no note.
- **Conflicts with:** D-30 "never another worker's reasoning" (`dec:220`); D-10 "identical agents voting is one opinion counted several times" (`dec:81`). Sharing arguments between rounds makes the votes less independent.
- **Impact:** This reinterprets D-30 without saying so. Round-2 votes follow the most persuasive voter rather than being independent, which weakens the meaning of a majority.
- **Remediation:**
  1. Either give round 2 only the refined options and criteria (no arguments), or get the owner to accept that "published typed rationale ≠ reasoning".
  2. Record the choice in §17.
- **Fix:** needs an owner decision.

### A16 — The "run only the repo's tests" switch is enforced only by the prompt or CLI layer, although a structural option exists
- **Lens:** 1 and 2.
- **Evidence:** `arch:143` and `arch:502` ("Partial"): the command-level limit is left to "the CLI's own layer". `ADR-005:22` says the same.
- **Conflicts with:** D-17 "Switches are enforced by the station, not by the prompt" (`dec:129`); D-26 "Provider CLIs' own sandbox … is an extra layer, not the main one" (`dec:192`).
- **Impact:** For roles with this switch, the main safety layer is the one the decisions call secondary. The containment of effects relies on A2 and A13, which are themselves open.
- **Remediation:**
  1. Implement the switch as **no shell** for the role, plus a `run_tests` request: either a `needs_context` kind or a gateway tool. The orchestrator runs it as a check Step and returns the results.
  2. Mark D-17 as honoured, not partial.
- **Fix:** local edit; the owner may accept the "by effect" reading instead.

### A17 — Holdout scenarios are not required to differ from the scenarios the builder can already see
- **Lens:** 1 and 5.
- **Evidence:** `arch:232`: holdout scenarios are drafted "from the OpenSpec change". The OpenSpec change, with its WHEN/THEN scenarios, is inside every builder copy (`arch:123`; `openspec/**` is protected from writes, not reads, `arch:150`) and is in the spec slice (`arch:249`). D-45 already makes the test author write visible E2E tests for each acceptance scenario.
- **Conflicts with:** P1 / D-36 "stored where the builder cannot see them" (`req:73`, `dec:262`); value 1 "no two agents asked the same question without a distinct reason" (`val:8`).
- **Impact:** If the holdout set restates the OpenSpec scenarios, it hides only the test code, not the behaviour, and spends a planner call, a test-author call and a check per item on checks that are already visible.
- **Remediation:**
  1. Define holdout scenarios as variations and edge cases that are **not** in the OpenSpec text: the same requirement with other data, boundaries or negative paths.
  2. Have the human approval check that the sets do not overlap, for example by a deterministic text-similarity flag.
  3. State in §7 that the holdout text must never be written into `openspec/`.
- **Fix:** needs an owner decision.

---

## Nit

### A18 — The board's `delivery` column contradicts the triggers that reject updates
- **Lens:** 4. **Evidence:** `arch:278` has `delivery (pending/delivered/failed)` on the board row and SQLite triggers that reject `UPDATE`. **Impact:** Either delivery status cannot change, or the trigger has an exception. **Remediation:** (1) Record delivery as new `task.delivered` / `task.failed` entries. (2) Remove the column. **Fix:** local edit.

### A19 — It is not defined which files the diff check covers
- **Lens:** 4. **Evidence:** `arch:123` creates a fresh `.git` inside every copy, while `arch:150` lists `.git/**` as protected, so any `git add` by an agent would trip rule 1. Build output (`bin/`, `obj/`) and `.gitignore` handling are not defined (`arch:126`, `arch:152`), so every build would trip the declared-files rule. `arch:101`: whether a Step that ends with `needs_context` has its partial edits applied is not defined. **Remediation:** (1) Exclude the copy's own `.git` from the tree manifest. (2) Apply the **base commit's** ignore rules, not the copy's, and discard ignored files. (3) Discard the edits of a Step that ends with `needs_context`. **Fix:** local edit.

### A20 — The protected-path rule contradicts the fallback for archiving OpenSpec
- **Lens:** 1. **Evidence:** `arch:150` says no role may change `openspec/**`. `arch:547` (Q6) falls back to "a planner Step limited to `openspec/**`". **Remediation:** (1) Archive in code inside the spec adapter: moving the folder and merging deltas is deterministic. (2) Otherwise state the one exception explicitly in rule 1. **Fix:** local edit.

### A21 — There are more states than needed
- **Lens:** 3. **Evidence:** Items have 14 states (`arch:166-180`), runs 8 (`arch:222`) and groups 6 (`arch:231`). `gating` and `holdout` are both deterministic check states with the same exit on failure. `publishing` is a single idempotent action. The run states `confirmed` and `running` have no work between them, and `expired` is a refusal, not a state (`arch:224`). **Remediation:** (1) Merge `gating` and `holdout` into `checking`, with the holdout as its last check. (2) Fold `publishing` into the entry of `pr_open`. (3) Drop the run states `confirmed` and `expired`. **Fix:** local edit.

### A22 — Retries and re-issues spend tokens without new information
- **Lens:** 5 (value 1). **Evidence:** `arch:98`: `crashed` gets one retry with nothing new. `arch:101`: a `needs_context` re-issue repeats the whole call, and there is a second, parallel mechanism (MCP `get_context`, `ADR-004:13`, `arch:545`). **Remediation:** (1) Retry `crashed` only after a provider probe shows something changed. (2) Choose one context mechanism for v1. **Fix:** local edit.

### A23 — The isolation stack is heavier than D-26 needs (value 3)
- **Lens:** 3. **Evidence:** ADR-005 decision 3 (`ADR-005:12`) and `arch:130` use a dedicated user, a sudoers rule and Seatbelt. ADR-005 rejects "same user + Seatbelt" (`ADR-005:27`) only because of the Keychain. Once A2's read-deny profile exists, the separate user adds little, but it causes A6 and Q1. **Remediation:** (1) In the spike, try running as the same user with a Seatbelt profile that denies reads by default and denies the `mach-lookup` Keychain services, with provider credentials supplied by file or environment token. (2) Keep `_afworker` only if that fails. **Fix:** needs an owner decision (after the spike).

### A24 — Dependabot (always on, D-23) is missing
- **Lens:** 1. **Evidence:** D-23 lists Dependabot as always on (`dec:171`). §15 (`arch:452-465`) and `init` (`arch:403`) do not mention it, and §17 (`arch:509`) marks D-23 as honoured. **Remediation:** (1) Have `init` add `.github/dependabot.yml` through the config PR. (2) Define how the factory treats Dependabot PRs when it polls main; for example, they are not factory merges and do not count toward the breaker. **Fix:** local edit.

### A25 — The owner API is the only path for human approvals, but its protection against CSRF and HTML injection is not specified
- **Lens:** 2. **Evidence:** `arch:440` uses a cookie session on `127.0.0.1`. `arch:265` makes the owner API one of only two sources of human approvals. The UI renders text written by agents: options, findings, rationales. **Remediation:** (1) Use a `SameSite=Strict` cookie. (2) Require a custom header on writes and check `Origin` and `Host`. (3) Never render agent Markdown as raw HTML. **Fix:** local edit.

---

## Strengths worth keeping
- A single process writes all state, and `Board.Append(entry, change)` commits the board entry and the state change in one transaction (ADR-001, ADR-002). There are no races between cross-process writers and no replay engine.
- The orchestrator computes the diff from its own tree hashes, never from the copy's `.git`, and applies refusal rules in a fixed order, each naming the rule that refused (`arch:126`, `arch:149-155`).
- The typed file-based I/O contract does not depend on any CLI feature (ADR-004). Usage fields are nullable ("not measured" is not 0), and an unverified CLI capability fails closed as `unsupported`.
- The traceability table is honest: it marks partial and reinterpreted decisions (`arch:489`, `arch:502`, `arch:504`) instead of hiding them.
- Hostile-worker tests are a first-class project (`arch:64`). GitHub writes are idempotent through markers, and the risk tier is deterministic (`arch:257`).

## Questions only the owner can answer
1. D-04 says each provider runs "in a terminal". Are headless child processes, observed through `board tail` and transcripts, acceptable (`arch:489`)?
2. R3 and D-06: should **every** item plan be critiqued (one critic Step or a council vote per item), and at what token cost (A8)? Relatedly, should a planner's change to the E2E decision block the item for your confirmation, or only notify you (A9)?
3. Must holdout scenarios be different from the OpenSpec scenarios (variations and edge cases), or is hiding the test code enough (A17)?
4. D-30: is a voter's published rationale "another worker's reasoning", and is a readable repo copy a "repository dump" (A14, A15)?
5. D-28: does confirming a plan allow runtime switches to another profile in the allowlist (P7, `arch:94`), or must every switch be one of the profiles you confirmed?
6. Will target repos have GitHub Actions secrets or write-scoped workflow tokens? May `doctor` refuse to run until the repository settings are read-only (A3)?
