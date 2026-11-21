# Grilling log

Method: a design tree; each round asks the whole **frontier** — every question whose prerequisites are settled.
Each question is worded so that "yes" accepts the recommendation (➡️). Answers may be given by number.
Claude looks up facts ([research-notes.md](research-notes.md)); decisions belong to the owner.

## Round 1 — root decisions (2026-11-20)

| Q | Topic | Answer | Decision |
|---|---|---|---|
| Q1 | Separate orchestrator using dw as a station | Yes | D-01 |
| Q2 | v1 for the owner's greenfield projects | Yes | D-02 |
| Q3 | Light mode by default, human merges to main | Yes | D-03 |
| Q4 | Runs locally on the Mac | Yes, amended: providers and per-role agents (model, effort, odd count 1/3/5/7, default 1) configured in a UI; configurability in many places; inter-agent messaging; each provider as a terminal process | D-04, R9, R10 |
| Q5 | Parent issue + sub-issues, GitHub dependencies | Yes | D-05 |
| Q6 | Councils vote on discrete options, not on code | Yes, extended: adversarial code review + Anthropic practices | D-06, R11 |
| Q7 | Requirements in Russian, specs in English | No: all requirements and docs in English | D-07 |
| — | messagebus.ai | Not used; take its ideas only | D-08 |

## Round 2 — roles, review, board, configuration (2026-11-20)

All recommendations accepted.

| Q | Topic | Decision |
|---|---|---|
| Q8 | Fixed role catalog; odd count only for voting roles | D-09 |
| Q9 | Distinct agent profiles; critic ≠ builder profile | D-10 |
| Q10 | Orchestrator-owned append-only board | D-11 |
| Q11 | No majority → human; judge never breaks ties | D-12 |
| Q12 | Review pipeline: critic lanes → verifier vote → moderator → fix Important; cap 3 | D-13 |
| Q13 | Approval rules: tier by change, agent ≠ human approval, approval per SHA | D-14 |
| Q14 | Machine-local provider registry + per-repo config file | D-15 |
| Q15 | Local web UI on localhost | D-16 |

## Round 3 — roles as data, budgets, escalation, specs, constraints, quality tooling (2026-11-20)

All recommendations accepted.

| Q | Topic | Decision |
|---|---|---|
| Q16 | Role = purpose + instructions + capability profile | D-17 |
| Q17 | Roles stored as data | D-18 |
| Q18 | Nested budgets, visible overrun states | D-19 |
| Q19 | UI inbox mirrored to GitHub issue + label | D-20 |
| Q20 | OpenSpec at group level behind an adapter | D-21 |
| Q21 | Constitution file + enforceable rules + ADRs | D-22 |
| Q22 | First-run wizard: free set on, paid off | D-23 |
| Q23 | Personal-use boundary for providers | D-24 |

Owner's follow-up: review afactory for ideas; propose removing dw parts if that makes the factory simpler or better —
the goal is a software factory, not reuse of dw.

## Round 4 — station, enforcement, afactory ideas, simplification (2026-11-20)

All recommendations accepted.

| Q | Topic | Decision |
|---|---|---|
| Q24 | Own provider-agnostic station; dw is a source of ideas | D-25 (supersedes D-01) |
| Q25 | Structural enforcement | D-26 |
| Q26 | Configuration read from a commit | D-27 |
| Q27 | Plan before spend | D-28 |
| Q28 | Deterministic gate first; incomplete ≠ clean | D-29 |
| Q29 | Minimal context per worker | D-30 |
| Q30 | CLI first, UI as client | D-31 |
| Q31 | dw parts not carried into v1 | D-32 |
| Q32 | Values and simplicity rule | D-33, [values.md](values.md) |

## Round 5 — factory stack, state, holdout scenarios, delivery, parallelism, health (2026-11-20)

All recommendations accepted.

| Q | Topic | Decision |
|---|---|---|
| Q33 | Factory built on the R1 stack (.NET, React, SQLite) | D-34 |
| Q34 | Machine state outside the target repo | D-35 |
| Q35 | Holdout scenarios | D-36 |
| Q36 | Delivery and definition of done | D-37 |
| Q37 | Slots, declared files, kill switch, dry run | D-38 |
| Q38 | Circuit breaker and noise tracking | D-39 |
| Q39 | Manual start in v1 | D-40 |
| Q40 | Private repos by default | D-41 |
| Q41 | Five UI screens | D-42 |

Owner's additions: R12 (CLI library: Spectre.Console or RazorConsole), R13 (mandatory E2E step where it makes sense).

## Round 6 — CLI library, end-to-end tests, remaining proposals, v1 scope (2026-11-20)

All recommendations accepted.

| Q | Topic | Decision |
|---|---|---|
| Q42 | Spectre.Console + Spectre.Console.Cli | D-43 |
| Q43 | Explicit E2E decision per item | D-44 |
| Q44 | E2E tests in the red step | D-45 |
| Q45 | Default E2E tooling | D-46 |
| Q46 | E2E without Docker; flakiness visible | D-47 |
| Q47 | P5, P11, P12 in v1; P8, P19 in v2 | D-48 |
| Q48 | v1 stops before deployment | D-49 |

## Frontier empty (2026-11-20)
No open questions remain. The owner confirmed shared understanding on 2026-11-20 and asked to move to architecture.

## Round 7 — owner decisions from the architecture review (2026-11-20)

Context: [architecture/architecture.md](architecture/architecture.md) was written by an architect agent and reviewed by a separate
critic agent ([architecture/reviews/review.md](architecture/reviews/review.md)); triage in [architecture/reviews/triage.md](architecture/reviews/triage.md).
All recommendations accepted.

| Q | Topic | Decision |
|---|---|---|
| Q49 | Safe GitHub Actions settings; diff approval for `.github/**` | D-50 |
| Q50 | Critique every plan | D-51 |
| Q51 | E2E decision checked before red | D-52 |
| Q52 | What a worker may read | D-53 |
| Q53 | Rationales: judge yes, voters no | D-54 |
| Q54 | Holdout adds new behavior | D-55 |
| Q55 | Same-user read-deny sandbox first | D-56 |
| Q56 | Provider CLIs run headless | D-57 |
| Q57 | Profile switches within the confirmed plan | D-58 |

Owner's follow-up question: why a CLI and not a TUI? → Q58: CLI + web UI, live terminal views via Spectre, TUI later as another client — accepted (D-59).

## Round 8 — owner decisions from the architecture re-review (2026-11-21)

Context: [architecture/reviews/review-round2.md](architecture/reviews/review-round2.md), triage in [architecture/reviews/triage.md](architecture/reviews/triage.md) (round 2).
All recommendations accepted.

| Q | Topic | Decision |
|---|---|---|
| Q59 | Direct provider API use from shells metered, not blocked | D-60 |
| Q60 | Isolation fallback explicit, never silent | D-61 |
| Q61 | New dependencies declared in the plan; allowlist in constitution | D-62 |

Owner's follow-up (2026-11-21): no local macOS users at all → Q63 accepted → D-63 (supersedes D-61). Architecture §5, ADR-005 and how-it-works.md updated (architecture §21 "Revision 3a").

## Round 9 — simplification (Gemini review, triaged) (2026-11-21)

Context: [architecture/reviews/gemini-simplification-review.md](architecture/reviews/gemini-simplification-review.md) (Gemini, G1–G12) triaged by an
independent analyst in [architecture/reviews/gemini-review-triage.md](architecture/reviews/gemini-review-triage.md). Questions Q64–Q71 are the analyst's;
Q70 is split in two by the orchestrating session because its config part conflicts with the owner's stated wish (R9: configure roles in a UI) → Q72.

| Q | Topic | Answer | Decision |
|---|---|---|---|
| Q64 | Council out of v1 (design options in the plan; disagreement → Inbox) | Out of v1, deferred to v2 | D-64 |
| Q65 | Dependencies without the planning loop (closes A7) | Yes | D-65 |
| Q66 | Budgets as caps, not reservations (closes C1) | Yes | D-66 |
| Q67 | Holdout scenarios to v2; visible boundary/negative-path tests instead | Yes | D-67 |
| Q68 | Review: no moderator; verifier only on Important findings | Yes | D-68 |
| Q69 | Dark routes, circuit breaker, eval harness to v2 | Yes | D-69 |
| Q70 | Escalation answers only in the local UI/CLI; GitHub mirror is notification-only | Yes | D-70 |
| Q71 | Test author uses the builder toolchain; late "E2E needed" → escalation instead of `reviewing → red` | Yes | D-71 |
| Q72 | Repo config (roles, budgets) editing in the UI: keep (opens a PR) or IDE-only | No — keep UI editing (opens a PR) | D-72 |

## Branches for later rounds
- After round 9: architect revision 4 (D-64…D-72 + C2 and minor items from Q62) → consistency check → how-it-works.md update → implementation spike.
- Possibly: deployment to Azure (out of v1 so far), company-product adapter (D-02), cloud runner (D-04).
- P10 parallelism and conflicts; P8 Azure resources and money; P1 who writes holdout scenarios.
