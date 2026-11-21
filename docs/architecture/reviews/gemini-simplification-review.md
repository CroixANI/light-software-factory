Files read: README.md, values.md, how-it-works.md, requirements.md, decisions.md, glossary.md, architecture/architecture.md, architecture/adr/ADR-001-single-process-cli-as-api-client.md, architecture/adr/ADR-002-sqlite-state-tables-plus-append-only-board.md, architecture/adr/ADR-003-entity-merges-for-one-page-model.md, architecture/adr/ADR-004-provider-adapter-file-based-typed-io.md, architecture/adr/ADR-005-station-isolation-on-macos.md, architecture/adr/ADR-006-yaml-for-repo-config-and-roles.md, architecture/adr/ADR-007-github-via-gh-cli-with-polling.md, architecture/triage.md
Findings: 12 total — a: 3, b: 5, c: 4; trade-offs that weaken safety: 3

### 1. Ranked findings

| ID | Title | Cat (a/b/c) | Removed or merged | Decisions affected | Value impact (1–5, +/−) | Risk | Confidence (H/M/L) |
|---|---|---|---|---|---|---|---|
| G1 | Defer Holdout Scenarios and the `scenarios` group phase to v2 | c | `scenarios` group state, similarity checker, isolated `holdout/` store, hidden test runner, closing PR test promotion | D-36, D-55 (defer) | V1+, V2+, V3++ | Medium: builder may overfit to visible OpenSpec acceptance tests | H |
| G2 | Drop Finding Verifier and Moderator from review; deduplicate deterministically | b | `finding-verifier` role, `Checklist` object, `verify` Question kind, 2–4 model calls per review round | D-09, D-13 | V1++, V3+ | Medium: false-positive critic findings reach builder directly (mitigated by builder `disputed` mechanism) | H |
| G3 | Replace multi-round Council + Judge with Plan Critique or direct human escalation | b | `deciding` item state, `council-voter` and `judge` roles, multi-round tallying, auto-ADR rendering (3 roles → 4 total) | D-06, D-09, D-12, D-22, D-54 | V1++, V3++ | Low: open architectural choices go straight to the owner in Inbox instead of being debated by 3–7 agents | H |
| G4 | Collapse 6-dimension, 4-scope nested reservation budgets into 3 simple counters | b | `Budget` entity/table, two-level transactional reservation math, `usd`/`tokens`/`provider_usage_threshold` pre-checks | D-19, D-28 | V3++, V5= | Low: parallel slots could slightly overshoot a run token target before draining; CLI token reporting is unverified anyway (Q5) | H |
| G5 | Defer Circuit Breaker, Dark Routes, and Review Noise classification to v2 | c | `breaker.*` board entries, `dark_routes` config, `finding reclassify` CLI/API, revert/escaped-label polling, autonomy tightening | D-03 (dark part), D-39 | V3++, V4= | None in v1: `dark_routes` is empty by default and v1 is single-user light-mode on greenfield repos | H |
| G6 | Defer GitHub two-way comment answering to v2; keep Inbox UI/CLI as sole answer path | b | GitHub comment polling, factory comment ID tracking, Markdown block-quoting rules, `answer q-<id>` parser (ADR-007 §A4) | D-14, D-20 | V3+, V4+ | Low: owner cannot answer escalations via GitHub mobile app; must use local web UI or CLI | H |
| G7 | Collapse `/run-tests` HTTP shim and `tester` exec-allowlist into offline `builder` preset + diff check | b | `tester` Seatbelt `process-exec` allowlist, `factory-run-tests` binary shim, `POST /run-tests` gateway endpoint | D-17 (trade-off: weakens V4) | V3++, V4− | **Trade-off (weakens V4):** test author could invoke non-test build tools during `red`, though diff check still restricts writes to test files and network is blocked | H |
| G8 | Defer Factory Evaluation Harness (`evals/`, local GitHub mock, `eval capture`) to v2 | c | `evals/` project, `Run.kind = eval`, local GitHub adapter implementation, seeded-defect & delta-archive harness, 2 CLI commands | D-48 (P11) | V3++ | Low: factory changes are tested by unit/integration/hostile-worker tests (`Factory.*.Tests`) rather than full end-to-end agent evals | H |
| G9 | Drop pre-declared dependencies (`D-62`) and `building → planning` loop; restore in `checking` | b | `declared_dependencies` in plan, constitution dependency allowlist, `blocked: dependency` transition, item package overlay (`B3`) | D-62 (trade-off: weakens V4) | V1+, V3++, V4− | **Trade-off (weakens V4):** an agent could add an unapproved package to `.csproj`/`package.json` during `building` and trigger `restore --ignore-scripts` in `checking` before human diff approval at `pr_open` | M |
| G10 | Remove dead dedicated-user fallback (`D-61`) and `_afworker` references across architecture | a | Fallback paragraphs in Arch §5, §6 (`_afworker`), §13 (`doctor` sudoers wizard), §18 (`Q1`, `Q4`), and `ADR-005` | None (aligns with D-63) | V3+, V4+ | None: D-63 already superseded D-61, but architecture.md and ADR-005 still carry the dead design | H |
| G11 | Merge 5 web UI screens into 2 (`Runs & Inbox`, `Health & Cost`) and make Config read-only in UI | b | 3 React screens, UI-driven PR generator (`POST /config/proposals`, `factory config propose`), YAML-to-PR serializer | D-15, D-16, D-42 | V3++ | Low: owner edits `.factory/**` in their editor/git instead of a browser form that opens a PR | H |
| G12 | Simplify E2E downgrade state machine: remove `reviewing → red` re-red base-commit dance | a | `reviewing → red` transition, base-commit + new-tests checkout dance in `red` (Arch §6 A9), spec-critic E2E re-verification | None (keeps D-44, D-45, D-52) | V1+, V3+ | Low: if an E2E decision was approved before `red` (by plan critique + owner per D-52), critics don't second-guess it after build | H |

---

### 2. Findings in detail

#### G1 — Defer Holdout Scenarios and the `scenarios` group phase to v2 (Category c)
- **Evidence:** `decisions.md` D-36, D-55; `architecture.md` §5 (Holdout guard), §6 (`checking`), §7 (`scenarios`, `closing`), §15 (step 9), §18 (Q8).
- **Proposal:** Defer hidden holdout scenarios to v2. Rely on visible OpenSpec WHEN/THEN acceptance scenarios written in the `red` step by the separate `test-author` role (D-45) and locked by the red-test lock (§5 rule 4).
- **Effect:** Removes the `scenarios` group state, 2 group-start model calls + 1 mandatory human approval blocking dispatch, the deterministic text-similarity overlap checker, the out-of-repo `groups/<n>/holdout/` test harness, requirement-reference scoping logic, and test promotion in the closing PR (~120 lines of design). v1 loses defense against a builder overfitting specifically to visible test assertions when the spec itself has gaps.
- **What breaks if this is wrong:** A builder passes the `test-author`'s visible unit/E2E tests with narrow logic that violates an unstated variation. Noticed by the `spec-correctness` critic lane in `reviewing` or the human reviewing the PR.

#### G2 — Drop Finding Verifier and Moderator from review; deduplicate deterministically (Category b)
- **Evidence:** `decisions.md` D-09, D-13; `architecture.md` §2 (`Role`, `Question`), §8 (Review pipeline steps 3–4).
- **Proposal:** Amend D-09 and D-13. Run the 3 read-only critic lanes (`spec-correctness`, `security`, `architecture`), deduplicate findings deterministically by file/line, and pass `Important` findings directly to the builder. Keep the builder's existing ability to mark a finding `disputed [{finding_id, reason}]` (§4); if a critic disagrees on the next round, escalate to the human after round 2.
- **Effect:** Removes 1 role (`finding-verifier`), the moderator function of `judge`, the `verify` Question kind, `Checklist` value object, and 2 to 8 model calls per review round (1–7 verifiers + 1 moderator).
- **What breaks if this is wrong:** Critics produce false positives that force the builder to waste a round fixing non-issues or disputing them. Noticed as a higher average review round count per item on the board.

#### G3 — Replace multi-round Council + Judge with Plan Critique or direct human escalation (Category b)
- **Evidence:** `decisions.md` D-06, D-09, D-12, D-22, D-54; `architecture.md` §6 (`deciding`), §8 (Council vote).
- **Proposal:** Change D-06, D-09, D-12. When the planner raises a genuinely open design question not settled by the constitution or OpenSpec, either (1) let the `plan` critic (D-51) validate the planner's recommended option, or (2) ask the owner directly via an Inbox Question (`addressee = human`), since the owner is a single local developer on their own greenfield repo.
- **Effect:** Removes the `deciding` item state, 2 roles (`council-voter`, `judge`), the `design` council voting loop, rationale filtering (D-54), and automatic `docs/adr/q-*.md` rendering. Coupled with G2, the role catalog drops from 7 roles to 4 (`planner`, `test-author`, `builder`, `critic`).
- **What breaks if this is wrong:** The owner receives 1–2 extra Inbox questions per group for open architectural choices instead of having 3–7 LLM calls vote on them. Noticed immediately as higher Inbox volume during `planning`.

#### G4 — Collapse 6-dimension, 4-scope nested reservation budgets into 3 simple counters (Category b)
- **Evidence:** `decisions.md` D-19, D-28; `architecture.md` §2 (`Budget`), §9, §10, §18 (Q5).
- **Proposal:** Simplify D-19 and D-28. Drop the `Budget` table and two-level transactional reservation (`reserved` vs `spent` across `run → group → item → question`). As Q5 admits, subscriptions don't reliably expose token/USD quotas. Enforce 3 always-measurable hard caps directly on `Item` and `Run`: `max_steps_per_item` (default 40), `max_rounds_per_stage` (default 3), and `max_wall_time_per_item` (2h), plus an optional `max_steps_per_run` counter. Reactive `rate_limited` cooling (§4) handles provider quota.
- **Effect:** Removes 1 entity/table (`Budget`), 4 board entry types (`budget.reserved/charged/released/refused`), two-level reservation math, unmeasured-usage estimation accounting, and the 80% `provider_usage_threshold` heuristic.
- **What breaks if this is wrong:** Two parallel slots might both start an item when the run is near a soft token target, or a single step with a massive prompt could spend more tokens than average while staying under `max_steps`. Noticed on the Cost screen from recorded `step.finished` usage.

#### G5 — Defer Circuit Breaker, Dark Routes, and Review Noise classification to v2 (Category c)
- **Evidence:** `decisions.md` D-03, D-39; `requirements.md` P13, P14; `architecture.md` §8 (Outcomes, Dark routes), §11 (Circuit breaker), §13 (`breaker`, `finding reclassify`).
- **Proposal:** Defer D-39 and the dark-route merge machinery of D-03 to v2. In v1, `dark_routes` is empty by default and every PR is merged by the human owner.
- **Effect:** Removes `Group.autonomy`, finding outcome classification (`fixed/wrong/intentional/doesn't-matter`), `factory finding reclassify`, `factory breaker status|reset`, GitHub polling for revert commits and `factory:escaped` labels, and dynamic mid-run profile/verifier count mutation. v1 loses automatic autonomy tightening when a group has many bad findings or a reverted PR.
- **What breaks if this is wrong:** If a prompt change causes high critic false-alarm rates or a merged PR is reverted, the factory will not automatically add +2 verifiers; the owner must notice the revert (which they just performed) and stop or reconfigure the run.

#### G6 — Defer GitHub two-way comment answering to v2; keep Inbox UI/CLI as sole answer path (Category b)
- **Evidence:** `decisions.md` D-14, D-20; `architecture.md` §8, §11; `ADR-007` (A4).
- **Proposal:** Amend D-20. Still mirror escalation notifications to GitHub issues (or use the optional macOS notification) so the owner gets a ping on their phone, but require answers to be submitted via the local Web UI Inbox or `factory inbox answer`.
- **Effect:** Removes GitHub comment polling, tracking factory-created comment IDs in SQLite to prevent self-answering loops (A4), mandatory blockquote escaping of all agent text on GitHub, and strict regex parsing of `answer q-<id>` comments (~50 lines of security-critical logic).
- **What breaks if this is wrong:** The owner cannot type `answer q-17 2` in the GitHub mobile app while away from their Mac; they must answer from the Mac running `factory serve`.

#### G7 — Collapse `/run-tests` HTTP shim and `tester` exec-allowlist into offline `builder` preset + diff check (Category b — trade-off: weakens safety Value 4)
- **Evidence:** `decisions.md` D-17; `architecture.md` §5 (Capability presets, A16), `ADR-005` §3–4.
- **Proposal:** Relax D-17's "run only the repo's tests" switch. Run `test-author` under the same offline Seatbelt execution rules as `builder` (full local toolchain, no network except provider API via gateway) and rely on the existing orchestrator diff check (§5 rule 2: `test-author` may modify only test globs) plus the orchestrator's independent `red` check Step.
- **Effect:** Removes the `tester` Seatbelt `process-exec` binary allowlist, the `factory-run-tests` CLI shim binary, the `POST /run-tests` worker gateway endpoint, and the nested check-Step snapshot spawning during a worker Step.
- **What breaks if this is wrong:** **Trade-off (weakens Value 4 for Value 3):** During `red`, the `test-author` process can execute arbitrary local build commands (`dotnet`, `node`, scripts) inside its disposable step copy, just like `builder` already does in `building`. Because the step copy is discarded except for diff-checked test files and the orchestrator re-runs the `red` check independently in a clean check Step, no poisoned artifact or non-test edit can survive.

#### G8 — Defer Factory Evaluation Harness (`evals/`, local GitHub mock, `eval capture`) to v2 (Category c)
- **Evidence:** `decisions.md` D-48 (P11); `architecture.md` §3 (`evals/`), §13 (`eval run`, `eval capture`), §16; `ADR-007` (`local` adapter).
- **Proposal:** Defer P11 (`factory eval run` and `factory eval capture`) to v2. Keep `Factory.Core.Tests`, `Factory.Station.Tests` (with deterministic hostile-worker tests), and `Factory.Host.Tests`.
- **Effect:** Removes the `evals/` benchmark suite, `Run.kind = eval`, `actor_kind = harness`, the `local` mock GitHub adapter implementation, seeded-defect/bad-plan fixture scoring, and 2 CLI commands. v1 loses automated multi-provider benchmark regression testing of prompts before the factory has run on real projects.
- **What breaks if this is wrong:** A regression in role prompt instructions is not caught offline before a real run; noticed during real group runs via gate failures or review findings.

#### G9 — Drop pre-declared dependencies (`D-62`) and `building → planning` loop; restore in `checking` (Category b — trade-off: weakens safety Value 4)
- **Evidence:** `decisions.md` D-62; `architecture.md` §4, §5 (Builds and dependencies, A7, B3), §6 (`building → planning`), §18 (Q6).
- **Proposal:** Drop D-62. Keep the builder offline with the read-only shared cache, and keep `.csproj`/`package.json` as `sensitive` paths (requiring human approval before push/merge). When a builder adds a `PackageReference` or npm package, let `checking`'s existing `restore` check Step (`dotnet restore`, `npm ci --ignore-scripts` into the item overlay) fetch it and run the gate, and require human approval of the dependency diff at `pr_open` before pushing to GitHub.
- **Effect:** Removes `declared_dependencies` from `ItemPlan`, the constitution dependency allowlist, the `blocked: dependency` failure class, and the `building → planning → critique → approval → restore → red → building` backward loop (flagged in Q6 as a major friction point).
- **What breaks if this is wrong:** **Trade-off (weakens Value 4 for Values 1 & 3):** If an agent hallucinates or is prompt-injected into adding a malicious package name, `restore` in `checking` will download the package tarball (`--ignore-scripts`) and `dotnet build` / `dotnet test` will execute it inside the local Seatbelt check-Step sandbox (which has no credentials, no owner files, and no internet egress) *before* a human approves the package name.

#### G10 — Remove dead dedicated-user fallback (`D-61`) and `_afworker` references across architecture (Category a)
- **Evidence:** `decisions.md` D-61 (`superseded by D-63`), D-63; `architecture.md` §5 (Fallback), §6 (Resume after crash step 1: `_afworker`), §13 (`doctor`), §17 (Traceability D-61), §18 (Q1, Q4); `ADR-005` (Fallback paragraph), `how-it-works.md` §2, §4.
- **Proposal:** Delete the dedicated macOS worker-user fallback, sudoers setup wizard in `doctor`, and `_afworker` kill logic from `architecture.md`, `ADR-005`, and `how-it-works.md` to match D-63 ("No local macOS users... there is no dedicated-user fallback").
- **Effect:** Removes an entire parallel OS isolation design, sudoers privilege-escalation surface, and contradictory instructions across 3 documents with zero loss of agreed functionality.
- **What breaks if this is wrong:** Nothing; D-63 is already binding.

#### G11 — Merge 5 web UI screens into 2 (`Runs & Inbox`, `Health & Cost`) and make Config read-only in UI (Category b)
- **Evidence:** `decisions.md` D-15, D-16, D-42; `architecture.md` §13 (`config propose`), §14 (Local web UI), `ADR-006`.
- **Proposal:** Amend D-15 and D-42. Drop the browser-based Config editor that serializes YAML and opens GitHub PRs (`POST /config/proposals`, `factory config propose`); the owner is a developer working locally on the target repo and can edit `.factory/factory.yaml` in their IDE with JSON Schema validation (`factory config validate`). Combine the remaining views into 2 screens: **Dashboard** (Runs + live Board + Inbox escalations) and **Telemetry** (Health + Cost + read-only active config snapshot).
- **Effect:** Removes 3 of 5 React screens, the YAML-rewriting PR generator (which ADR-006 notes strips YAML comments), and 1 CLI command (`config propose`).
- **What breaks if this is wrong:** The owner cannot edit role prompts or budgets from a web form to open a PR; they must edit `.factory/**` files in git and run `factory config validate`.

#### G12 — Simplify E2E downgrade state machine: remove `reviewing → red` re-red base-commit dance (Category a)
- **Evidence:** `decisions.md` D-44, D-45, D-52; `architecture.md` §6 (`red` re-red logic, `reviewing → red`, A9), §8 (Review pipeline step 1), §15.
- **Proposal:** Keep D-44, D-45, and D-52's pre-`red` enforcement (planner proposes `e2e`, plan critique checks every `not-applicable`, and any downgrade from `required` to `not-applicable` requires human owner confirmation before `red`). Drop only the late `reviewing → red` backward transition and its complex "re-red check against base commit + new tests only" workflow (A9). If a critic in `reviewing` still thinks tests are missing, it reports an ordinary `Important` finding or escalates to the human.
- **Effect:** Removes the `reviewing → red` and `red → checking` transitions, the dual-head git checkout dance in `red` (testing against `base_sha + new_tests` vs `head_sha`), and one stateful edge case in the state machine while keeping all of D-44/D-45/D-52 intact.
- **What breaks if this is wrong:** If the heuristic was initially `not-applicable` (e.g., an issue mislabeled `internal`), the planner kept `not-applicable`, and the `plan` critic missed that the plan touches public behavior, a late review finding will park the item for human decision instead of automatically cycling back through `red`.

---

### 3. Minimum viable factory (≤ 25 lines)

The smallest v1 that safely delivers the core loop on a single developer's Mac:
- **Components (3 projects + thin UI):** `Factory.Station` (Seatbelt `deny default` sandbox, per-step disposable APFS copy, localhost CONNECT gateway, tree-hash diff checker, 3 CLI adapters), `Factory.Core` (state machine, SQLite store + append-only `board`, `gh` CLI poller, deterministic gate runner), `Factory.Host` (CLI + local minimal API + 2-screen React UI).
- **Entities (8, down from 10):** `Provider`, `Role`, `Run`, `Group`, `Item`, `Step`, `Question` (human escalations/approvals only), `Board entry` (drops `Budget` table and `Finding` table—findings live as typed JSON inside `Step` / `Board entry`).
- **Item states (9, down from 12):** `queued → planning → red → building → checking → reviewing → pr_open → main_gate → done` (plus `parked` and `dropped`; drops `deciding` and the `reviewing → red` loop).
- **Roles (4, down from 7):** `planner` (1), `test-author` (1), `builder` (1), `critic` (1 per lens: `plan`, `spec-correctness`, `security`, `architecture`, distinct profile from builder). Drops `judge/moderator`, `council-voter`, `finding-verifier`.
- **Model calls per clean item (7 calls):** 1 `planner` + 1 `critic(plan)` → 1 `test-author` (`red`) → 1 `builder` (`building`) → [deterministic gate: build, format, lint, unit/integration/constraint/E2E tests, red-ID check, ratchet] → 3 parallel `critic` lanes (`reviewing`).
- **Human touchpoints (2–4):** (1) Confirm token-free run plan (`factory run confirm`); (2) Approve plan/diff in local Inbox *only* if high-risk, rule-path, unallowlisted dependency, or open design question; (3) Review and merge each item PR on GitHub; (4) Merge group closing PR (OpenSpec archive + ratchet baseline).
- **Deferred to v2:** Holdout scenarios (G1), verifier/moderator voting (G2), multi-agent design councils (G3), 6D nested budget reservations (G4), circuit breaker & dark auto-merge (G5), GitHub comment answer parser (G6), factory self-eval harness (G8), UI config PR generator (G11).
- **Safety guarantees kept (100% of Value 4):** Same-user deny-by-default Seatbelt (no access to `~/.ssh`, Keychain, other steps, or orchestrator IPC); per-step disposable copies excluding `.git`, `.factory/**`, and `CLAUDE.md`/`AGENTS.md`; zero credentials in workers; localhost gateway egress allowlist closed on step exit; config snapshot read from base commit; orchestrator diff enforcement (protected paths, role paths, declared-file locks, red-test file + test-ID locks, SHA-bound human approval for `.github/**` and rule paths); `doctor` verification of D-50 GitHub Actions settings before push; human merge.

---

### 4. Keep — do not simplify (≤ 5 items)

1. **Deny-by-default Seatbelt + per-step disposable APFS copy + localhost gateway (`ADR-005`):** With headless CLIs running as the owner user (`D-56`, `D-63`), this is the only barrier preventing a prompt-injected agent from reading `~/.ssh`/Keychain, poisoning `CLAUDE.md`, or exfiltrating code.
2. **Orchestrator-enforced diff rules, red-test lock, and rule-path SHA approvals (`Arch §5`, `D-26`, `D-50`):** Prevents the builder from passing gates by deleting failing tests, adding `#pragma warning disable`, weakening linters, or smuggling malicious `.github/workflows` onto a pushed branch.
3. **Separate `test-author` (`red`) step before `builder` (`D-45`):** Enforces executable specifications and ensures tests actually fail before implementation and cannot be altered by the builder.
4. **Declared-file locking from `red` to `done`/`dropped` (`D-38`, `P10`):** Eliminates merge conflicts across the 2 parallel slots by construction without needing an agent-driven rebase/conflict-resolution loop.
5. **Single-writer SQLite state tables + transactional append-only `board` (`ADR-001`, `ADR-002`):** Gives crash recovery (`P5`) and end-to-end auditability (Value 5) in ~200 lines of C# without event-sourcing replay complexity.

---

### 5. Questions for the owner (≤ 5)

1. **Design Councils (G3):** On your own greenfield repos where you already write the OpenSpec change and constitution before starting a run, would you rather have open design questions escalated straight to your Inbox for a 10-second decision, or spend 4–10 LLM calls per question on a Judge + multi-provider Council vote?
2. **Verifier & Moderator layer (G2):** Are you willing to drop the `finding-verifier` vote and `moderator` merge step in v1—letting the builder either fix critic findings or flag them as `disputed` (escalating only if round 2 still disagrees)—to cut review model calls in half?
3. **Holdout Scenarios in v1 (G1):** Since v1 already enforces a separate `test-author` role writing locked unit + E2E tests for every OpenSpec acceptance scenario in `red` (and a separate critic checking the diff), can the hidden holdout test suite wait for v2 when you introduce dark auto-merge?
4. **Answering from GitHub comments (G6):** Do you actually need to answer escalations by typing `answer q-17 2` in GitHub issue comments in v1, or is answering in the local Web UI / CLI sufficient (letting you cut comment polling and self-comment spoofing defenses)?
5. **Dependency declarations (G9 — safety vs friction trade-off):** When a builder discovers it needs a NuGet/npm package mid-build, do you prefer the strict `D-62` loop (`building → planning → critique → owner approval → restore`) or letting `checking` restore the package offline with `--ignore-scripts` and requiring your approval on the PR diff before push?
