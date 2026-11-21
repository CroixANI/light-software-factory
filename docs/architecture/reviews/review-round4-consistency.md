**Leftovers: 0 · Contradictions: 7 · Decisions not honoured: 0 · Safety regressions: 1. Verdict: Needs fixes — K2, K3, K4 and S1. All are local edits, and none of them touches what the implementation spike tests.**

# Consistency check — revision 4

Scope: `architecture.md` (revision 4, 834 lines) and `adr/ADR-001…007`, checked against D-63…D-72 (`decisions.md`) and `gemini-review-triage.md`. This pass checks consistency only; it is not a hunt for new findings.
Notation: `arch:N` = `architecture.md` line N; `ADR-00x:N` = `adr/ADR-00x-*.md` line N.

## 1. Leftovers (removed or deferred mechanisms described as v1) — 0

I searched the v1 body (`arch:1-644`) and all ADRs for council, judge, `deciding`, moderator, holdout/`scenarios`, dark routes, breaker, eval harness, `tester`/shim/`/run-tests`, Budget/reservations/`usd`/`requests`/group and question scopes, GitHub comment answers, dedicated user/sudoers, `reviewing → red` and `building → planning`. Every hit is an explicit "removed / deferred / no … in v1" statement or a v2 hook:
- the glossary note `arch:49`; "no moderator call" `arch:345`; "no eval harness" `arch:641`; "no reservations" `arch:308`, `arch:407`, `ADR-004:18`;
- the ADR alternatives `ADR-003:31`, `ADR-005:59-61`, `ADR-007:35`;
- the v2 hook `ADR-003:26`.

`vote.cast` and `addressee = verifiers` (`arch:43`, `arch:370`) now describe finding-verifier votes, which is correct. `requests/day` (`arch:132`, `arch:420`) is a CLI-reported quota unit, not a cap dimension. Nothing to fix.

## 2. Contradictions — 7

| # | Where | Contradiction | One-line fix |
|---|---|---|---|
| K1 | `arch:235` and the diagram `arch:264-290` | The table lets `queued` go straight to the red entry check when a plan already exists (for example after an overlap refusal, `arch:249`). The diagram has no `queued → red` edge. | Add `queued --> red: plan kept, main unchanged (red entry check)` to the diagram. |
| K2 | `arch:208` and `ADR-005:41` vs `arch:205` and `arch:111` | Rule 3 says a new dependency in a worker's diff "is not applied; it is turned into a dependency request". That implies applying the rest of the diff, which contradicts "the first failing rule refuses the change". It also differs from the `blocked: dependency` flow, where the edits are discarded and the builder is re-issued. | Refuse the whole diff, record the dependency request, run the dependency step, and re-issue the builder: the same path as `blocked: dependency`. |
| K3 | `arch:251` ("orchestrator writes no shared files on item branches"; "two unmerged PRs never touch the same files") vs `arch:198`, `arch:201`, `arch:464`, `arch:241` | The dependency step writes project files and the repo-wide lock files (`packages.lock.json`, `web/package-lock.json`) on the item branch, outside the declared-file lock. That can happen mid-build. Two parallel items adding packages therefore touch the same files. `pr_open` exempts conflicts in orchestrator-written files but says nothing about how to resolve them. | Have the dependency step add the project and lock files to the item's file lock (the item waits if another item holds them), and on a `pr_open` conflict in lock files have the orchestrator regenerate them from the merged references. |
| K4 | `arch:237` (the only red check: "new tests fail on the item head") vs `arch:240` and `arch:243` (re-plan options) and `arch:308` (adoption sends items back to `planning`) | Revision 4 removed the base-commit re-red check together with `reviewing → red`. But re-plan from `parked`, the late-E2E option "re-plan", and run adoption still send items that already contain an implementation through `red`. There the new tests will usually pass on the head, so the red check fails and the item parks. | When `red` is entered on an item that already has non-test commits, run the red check on the base commit plus the new tests (the revision-3 rule), or skip `red` if the red tests are unchanged. |
| K5 | `arch:347` vs `arch:346` | The builder's dispute of a finding is decided by "the next round's verifier". But the verifier runs only when a round has `Important` findings (D-68), so a dispute in a round with no new `Important` findings is never decided. | Count disputed findings as `Important` for the verifier trigger. |
| K6 | `arch:633` | "One fix round: 13 (+ verifier 1, builder 1, critics 3)" adds up to 7 + 5 = **12**. | Change it to 12, or name the extra call (for example a second-round verifier). |
| K7 | `arch:248` | ADRs are rendered "after approval", but many items have no approval Question (`arch:247`), so it is unclear whether their design decisions become ADRs. | Say "after critique `accept` and any required approval". |

ADRs and the architecture agree on the rest:
- entity count 9 (`arch:33`, `ADR-003:25`) and table count 7 (`arch:377`, `ADR-002:19`);
- presets `read/write` (`arch:92`, `arch:184-187`, `ADR-004:15`, `ADR-005:27`);
- the single approval path (`arch:365`, `ADR-001:7`, `ADR-007:21`);
- the board entry types, which are closed at 21 (`arch:381-391`).

Item states are 11 in both the table and the diagram, and group states are 5 (`arch:313`).

## 3. D-63…D-72 honoured in the body — all 10

| Decision | Honoured at |
|---|---|
| D-63 | One mode only; an unholdable CLI is `unsupported` and the others keep running (`arch:146`, `arch:225`, `arch:534`, `arch:740`, `ADR-005:49`). |
| D-64 | Design options and a recommendation live in the plan; the critique runs on a different profile; a disagreement goes to the Inbox; ADRs are rendered (`arch:236`, `arch:328-332`, `arch:248`). |
| D-65 | `blocked: dependency` → orchestrator dependency step (allowlist or owner, reference and lock files, locked restore) → builder re-issued, with no `planning` loop (`arch:111`, `arch:196-201`, `arch:238`). K2 is a consistency issue in this flow. |
| D-66 | No Budget entity; caps of 4 dimensions × item/run computed from Steps; gateway traffic is telemetry (`arch:407-419`, `ADR-003:18`). |
| D-67 | Visible boundary and negative-path tests are written in `red` and checked by the critique and the spec lens (`arch:237`, `arch:337`, `arch:343`, `arch:617`). |
| D-68 | Deterministic checklist; the verifier runs only on `Important` (`arch:345-346`). |
| D-69 | No dark routes, breaker or evals in the body; outcomes are telemetry; OpenSpec fixtures are unit tests (`arch:350`, `arch:641`, `arch:67`). |
| D-70 | Answers come only through the UI or CLI; the mirror is notification-only (`arch:441-442`, `arch:365-366`, `ADR-007:21`). |
| D-71 | The test author uses the `builder` preset limited to test globs; a late E2E finding becomes an escalation (`arch:187-189`, `arch:240`, `arch:348`, `arch:618`). |
| D-72 | **Present:** the UI Config screen edits roles (models, effort, counts), caps and tools and opens a PR; `config propose` does the same; `machine.yaml` is edited directly (`arch:450`, `arch:537`, `arch:588`, `ADR-006:13`). |

## 4. Safety regressions caused by the removals — 1

| # | Where | Regression | One-line fix |
|---|---|---|---|
| S1 | `arch:201`, `arch:238` vs `arch:352-358`, `arch:249` | With D-65 there is no return to `planning`. A mid-build dependency is written by the orchestrator into a project file or `package.json`, which are dependency manifests and sensitive paths in the example config (`arch:504`). The classifier then puts the final diff in the **high** tier (`arch:352`), but high-tier plan approval is checked only at the red entry check, which has already passed. Nothing re-requests it at `pr_open`. | Either state that the dependency approval (allowlist or owner) replaces the high-tier approval for orchestrator-written dependency changes, or have the `pr_open` entry park the item for a high-risk approval when the tier rose after `red`. |

Checked, no regression:
- **C2:** new suppressions are checked per change, against the item diff, with an approval bound to the SHA before push (`arch:219`, `arch:241`, `arch:362`, `arch:603`, `ADR-007:20`). Merges from main bring only suppressions that were approved or written by humans. Dropping the ratchet metric opens no route the tree-wide count used to catch.
- **D-70:** human approvals come only from the owner API, which has CSRF, `Origin` and `Host` checks (`arch:365`, `arch:578-582`). `init`'s approval also goes through that API (ADR-001: only `serve` writes).
- **D-66:** with caps and no reservations, the overshoot is at most one Step per slot (`arch:417`). Abandoned and cancelled Steps without measured usage count at the estimate (`arch:257`, `arch:398`). This concerns value 1, not value 4.
- **D-71:** the test author now has a shell, but writes are still limited to test globs by the diff check, the copy is discarded, there are no credentials, the red check runs independently, and provider egress is flagged (`arch:189`, `ADR-005:53`, `ADR-005:55`).
- **D-63 and D-67:** removing the fallback user and holdout leaves an unsupported provider or visible tests, with every PR reviewed by a human (`arch:749`). No safety property is left unenforced.

## Verdict

**Needs fixes:**
- **K2:** refuse the whole diff when a dependency is undeclared.
- **K3:** lock and regenerate the files written by the dependency step.
- **K4:** use a red check that works on items that already have an implementation.
- **S1:** make the high-tier approval explicit for mid-build dependencies.

K1 and K5–K7 are wording fixes. All are local edits. None of them touches the sandbox, credential, Mach-service or proxy questions the implementation spike is meant to settle, so the spike can start in parallel.
