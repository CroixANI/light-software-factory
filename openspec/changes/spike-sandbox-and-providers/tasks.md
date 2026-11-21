# Tasks

Each top-level task is one session and one PR, and maps 1:1 to a GitHub Sub-Issue of Parent Issue #4 (D-73). All work is pre-spike: only `spike/`, `docs/spike/`, `openspec/`. Findings files are per task, so declared files do not overlap.

## 1. Shared harness

- [ ] 1.1 Create `spike/harness/` step-folder builder (`work/<step-id>/{home,io/in,io/out,tmp,repo}`, mode 0700), the sample repo with planted `CLAUDE.md`, `CLAUDE.local.md`, `AGENTS.md`, `GEMINI.md`, `.claude/`, `.codex/`, `.gemini/`, `.mcp.json`, and a `spike/.gitignore` for `work/` and raw logs; verify by building a folder, listing its modes and running `git status` clean. `#5` — blocked by: none
- [ ] 1.2 Write the localhost CONNECT proxy (one port per Step; logs host, connections, bytes); verify with a curl through it and a log excerpt. `#6` — blocked by: none
- [ ] 1.3 Write the fake CLI (reviewer-readonly and builder shapes) and the `io/out/result.json` JSON Schema; verify the fake CLI emits a schema-valid result for both shapes. `#7` — blocked by: none
- [ ] 1.4 Write the `(deny default)` Seatbelt starting profile and the empty-environment launcher (allowlisted env only, `HOME=<step>/home`, proxy vars); verify the fake CLI runs under it and every added Mach service has a recorded reason. `#8` — blocked by: #5, #6, #7

## 2. Sandbox experiments (fake CLI)

- [ ] 2.1 Run S1 (reads denied) and S2 (no IPC route: `launchctl`, `open`, `osascript`, `kill`, `ps eww`); write `docs/spike/findings/sandbox-s1-s2.md` with pass/fail evidence. `#9` — blocked by: #8
- [ ] 2.2 Run S3 (network: direct egress, other Step's gateway port, check-Step ports) and S4 (writes, protected paths, restore-Step caches); write `docs/spike/findings/sandbox-s3-s4.md`. `#10` — blocked by: #9
- [ ] 2.3 Run S5 (`dotnet build/test` and `npm` offline under the builder profile) and record the extra Mach services they need; write `docs/spike/findings/sandbox-s5.md`. `#11` — blocked by: #8
- [ ] 2.4 Record S6 (`sandbox-exec` deprecation and behavior on the current macOS, with versions); write `docs/spike/findings/sandbox-s6.md`. `#12` — blocked by: #8
- [ ] 2.5 Run OpenSpec's own archive on fixture changes (S7) and keep the output as reference for the spec adapter fixtures (Q8); write `docs/spike/findings/openspec-archive.md`. `#13` — blocked by: none

## 3. Provider CLIs

Part A = E1–E5; part B = E6–E12 plus a re-run of S1–S5 with that CLI. Each part writes only `docs/spike/findings/<cli>.md` (A creates, B appends) and `spike/<cli>/`.

- [ ] 3.1 claude, part A: Keychain-free credential, refresh, Mach allowlist, proxy compliance, own sandbox off; verify against the plan's pass criteria and record exact commands. `#14` — blocked by: #10, #11
- [ ] 3.2 claude, part B: headless flags and typed output, usage, instruction/settings files (B1), `needs_context` re-issue, no-shell, kill and escape, failure classes, S1–S5 re-run; record the verdict. `#15` — blocked by: #14
- [ ] 3.3 codex, part A (same scope as 3.1). `#16` — blocked by: #10, #11
- [ ] 3.4 codex, part B (same scope as 3.2). `#17` — blocked by: #16
- [ ] 3.5 gemini, part A (same scope as 3.1; effort is `n/a`). `#18` — blocked by: #10, #11
- [ ] 3.6 gemini, part B (same scope as 3.2). `#19` — blocked by: #18

## 4. Findings and review

- [ ] 4.1 Consolidate `docs/spike/findings.md`: verdict per CLI with evidence, versions, flags, env vars, credential mechanism, Mach allowlist, declared files, usage fields, failure patterns, S1–S7 results, and the diversity check (D-10); verify every exit criterion in the plan is addressed. `#20` — blocked by: #12, #13, #15, #17, #19
- [ ] 4.2 Open a PR proposing updates to architecture §4, §5, §19 (Q1–Q5, Q8 closed, narrowed or kept) and any `D-NN proposed` entries; verify no decision is edited silently and links resolve. `#21` — blocked by: #20

## Workflow follow-up

- Owner reviews the findings PR (milestone M1: Spike review); production code may start only after that.
- Archive this change after M1 is accepted.
