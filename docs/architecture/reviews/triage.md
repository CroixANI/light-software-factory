# Review triage — architecture v1, round 1

Reviewer: separate agent with fresh context (inputs: requirements, decisions, values, glossary, facts, architecture, ADRs).
Triage: orchestrating session, 2026-11-20. Each Important finding was checked at its cited lines.
Outcomes: `fix` (real defect, local edit) · `owner` (needs an owner decision — see grilling-log, round 7) · `disagree` (with evidence) · `decline` (out of scope, follow-up).

## Important

| ID | Finding (short) | Outcome | Note |
|---|---|---|---|
| A1 | Shared writable provider state folder → planted instructions/hooks, transcript leaks | fix | Per-step session state; credentials read-only; hostile-worker tests |
| A2 | Seatbelt limits only writes/network; reads open across steps, owner home, credentials | fix | Read-deny-by-default profile; 0700 per-step folders; no credentials/API hosts for check steps; token via file |
| A3 | Push runs agent-written code in GitHub Actions with secrets before a human sees it | owner (Q49) + fix | Diff approval for `.github/**`; `doctor` checks repo settings |
| A4 | GitHub "answer" comments indistinguishable from the factory's own comments | fix | Track own comment ids; strict first-line format with question id; quote agent text |
| A5 | Builder can weaken the gate (build props, lint configs, scripts) and skip red tests | fix | Built-in gate-defining protected paths; red test IDs must execute and pass |
| A6 | Kill/timeout/clean-up don't work across the worker-user boundary | fix, or moot if Q55 drops the separate user | |
| A7 | Workers and gates cannot build/test (no caches, no registry egress, nested Seatbelt) | fix | Shared read-only caches; restore step with egress; disable inner CLI sandboxes |
| A8 | Most item plans are never critiqued (R3, D-06) | owner (Q50) | |
| A9 | E2E decision checked too late; human never sees the planner's version | owner (Q51) + fix | Check before `red`; add re-red path |
| A10 | Paths into `red` skip re-planning, overlap check and high-risk approval | fix | `deciding → planning`; atomic overlap+lock on every entry to `red`; fixed order |
| A11 | Orchestrator-written files (ratchet, ADR numbers) conflict across parallel PRs | fix | Tighten ratchet in closing PR; ADRs named by question id |
| A12 | Config drifts mid-run as items branch from newer main (D-27) | fix | Constitution/roles only via manifest from snapshot; `.factory/**` change on main → drain/re-plan |
| A13 | Budget holes: no item reservation, killed work uncharged, direct API use unmetered | fix | Reserve at item start; charge abandoned at reservation; block provider hosts for commands |
| A14 | Every worker gets the whole repo; reads not logged (D-30) | owner (Q52) | |
| A15 | Voters and judge see other workers' rationales (D-30) | owner (Q53) | |
| A16 | "Run only the repo's tests" left to the CLI layer | fix | No shell + `run_tests` request executed by the orchestrator as a check step |
| A17 | Holdout scenarios may just restate visible OpenSpec scenarios | owner (Q54) | |

## Nit

| ID | Finding (short) | Outcome |
|---|---|---|
| A18 | Board `delivery` column vs no-UPDATE trigger | fix — delivery as new entries |
| A19 | Diff-check scope undefined (copy's `.git`, build output, `needs_context` partial edits) | fix |
| A20 | Protected `openspec/**` vs planner-step archive fallback | fix — archive deterministically in the spec adapter |
| A21 | More states than needed | fix — merge `gating`+`holdout` into `checking`; fold `publishing` into `pr_open` entry; drop run states `confirmed`, `expired` |
| A22 | Retries/re-issues without new information; two context mechanisms | fix — retry `crashed` only after a probe; one context mechanism (`needs_context`) in v1 |
| A23 | Isolation stack heavier than D-26 needs | owner (Q55) — spike decides |
| A24 | Dependabot (D-23) missing | fix |
| A25 | Owner API CSRF / HTML injection unspecified | fix |

## Reviewer's owner questions mapped
1 → Q56 · 2 → Q50, Q51 · 3 → Q54 · 4 → Q52, Q53 · 5 → Q57 · 6 → Q49

## Next
After the owner answers Q49–Q57: the architect revises (`fix` items + owner decisions), then a diff-only re-review (max 3 rounds, D-13).

---

# Review triage — round 2

Re-review: [review-round2.md](review-round2.md) — 20 resolved, 5 partly resolved, 0 still open, 4 new Important (B1–B4), 5 new Nit (B5–B9).

| ID | Finding (short) | Outcome | Note |
|---|---|---|---|
| A5 (partly) | Inline suppressions (`#pragma warning disable`, `eslint-disable`, `@ts-ignore`), `tsconfig` strictness, analyzer settings unprotected | fix | Suppression count as a ratchet metric that cannot rise; add `tsconfig*.json`, analyzer settings to gate-defining paths |
| A7 (partly) | Builder cannot add a dependency (restore discards edits, loops) | owner (Q61) + fix | Dependencies declared in the plan; restore after approval, before building |
| A9 (partly) | Late return to `red` cannot pass its own red check | fix | Re-red: new tests must fail on the item's base commit and pass on the head |
| A13 (partly) | Direct provider API use from the builder's shell flagged, not blocked | owner (Q59) | The sandbox cannot separate the CLI's own connections from its shell's |
| A16 (partly) | No-shell tester cannot reach the `run-tests` shim | fix | Reviewer's option 1: allow a shell, keep Seatbelt `process-exec` allowlist to {shell, shim, read-only helpers} |
| B1 | Repo agent-instruction files (`CLAUDE.md`, `AGENTS.md`, `GEMINI.md`, `.claude/`, `.codex/`, `.gemini/`) reach workers outside the manifest | fix | Gate-defining/protected paths; excluded from copies; CLIs told to ignore project instruction files where a flag exists |
| B2 | Same-user Seatbelt profile leaves IPC routes to unsandboxed owner code (launchd, LaunchServices, Apple Events, signals) | fix + owner (Q60) | Deny-by-default `mach-lookup`, no Apple Events, no signals to other processes, exec allowlist; hostile tests; fallback rule in Q60 |
| B3 | Restore runs agent-controlled build logic while writing shared caches | fix | Shared caches filled only from main by the orchestrator; item restores write an item-local overlay; npm `--ignore-scripts` |
| B4 | Ratchet tightened only at group close lets metrics regress within a group | fix | Gate compares with the stricter of the baseline file and the best value measured on main during the group (kept in state); file updated in the closing PR |
| B5 | Factory's own closing/retro PRs drain the run | fix | Factory-authored `.factory/**` changes do not drain; define that `draining` lets items finish their current step only |
| B6 | UI-only capabilities vs CLI parity claim | fix | Add `config propose`, `machine set`, `finding reclassify` |
| B7 | D-50 checked only in `doctor`; `init` pushes `.github/**` without diff approval | fix | Re-check at `plan` and before every push; `init` shows its diff for owner approval bound to SHA |
| B8 | Check steps reach any localhost port | fix | Seatbelt network rule limited to the step's own service ports; gateway per step |
| B9 | Role has workspace + preset; fallback isolation fully specified | fix | Derive workspace from preset; fallback shrunk to one paragraph in ADR-005 |

Next: owner answers Q59–Q61 → architect revision 3 → final diff-only re-review (round 3 of max 3, D-13).
