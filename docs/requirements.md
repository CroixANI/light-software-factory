# Requirements

Status values: `stated` — said by the owner; `proposed` — suggested by Claude, not agreed; `agreed` — confirmed in the interview; `rejected`.
`Q*` refers to [grilling-log.md](grilling-log.md), `D-*` to [decisions.md](decisions.md).

## Stated by the owner (R)

### R1. Architectural constraints — `agreed` (D-22)
- The factory lets the owner set architectural constraints at a basic level, in an open format, so another stack can be proposed.
- Default stack example:
  - UI: React, no pinned versions; concrete choices (version, bundler, libraries) may be made by the factory during analysis (R3).
  - Backend: ASP.NET Core, minimal API.
  - Storage: the cheapest option wherever possible — Azure Table Storage, Azure Blob Storage.
- Constraints = a constitution-style file + enforceable rules; concrete options within them are proposed in the item plan, checked by the plan critique and recorded as ADRs (council in v2, D-64); changing constraints needs a human (D-22).

### R2. Start signal and observation — `agreed` (D-05, D-16, D-28, D-42)
- A UI connected to a GitHub repository starts the factory and shows what it is doing.
- Optional: limit a run to one group of items (one feature). Group = parent issue or milestone (D-05).
- The factory runs locally on the owner's Mac in v1 (D-04). The UI is a local web app served by the orchestrator: config editor, start / stop / kill switch, live board, escalation inbox, cost (D-16).

### R3. Skeptical analysis of every item — `agreed` (D-06, D-12); v1: plan critique only, council in v2 (D-51, D-64)
- For every item the factory runs an analysis, critiques it and changes it if needed.
- Mechanism: a council of an odd number of agents; a decision passes by majority (e.g. 2 of 3).
- The council votes on discrete options for design and plan decisions; code is not voted on (D-06).
- Without a majority within the round cap the question goes to a human; the judge never breaks ties (D-12).

### R4. Specifications at the core — `agreed` (D-21)
- Work is driven by specifications. Candidate: OpenSpec (Fission-AI/openspec) or an alternative Claude proposes.

### R5. Code quality and paid components — `agreed` (D-23)
- Quality tooling is needed: linters, SonarQube Cloud or equivalents that work with GitHub.
- Not everything is free, so on the first run the factory offers the owner a choice of what to adopt.
- The same applies to anything that costs money or needs a separate cloud deployment (e.g. a database).

### R6. Asking a human — `agreed` (D-20)
- It must be clear how the factory reaches a human when a question cannot be settled without one.

### R7. Limits on repetition and spend — `agreed` (D-19)
- Limits are configurable. Example: voting or multi-model review on the same question runs at most 3 times, to cap token spend.

### R8. Input — `agreed` (D-05)
- Input is a list of GitHub issues that were split beforehand: a parent issue with sub-issues, ordered by GitHub issue dependencies (D-05).

### R9. Configurable agent roles and providers — `agreed` (D-09, D-10, D-15)
- In the UI the owner connects LLM providers (e.g. Claude, Gemini, OpenAI; possibly only Claude).
- For each role (e.g. reviewer) the owner sets which models and effort levels may be used and how many agents take part:
  an odd number — 1, 3, 5 or 7; default 1.
- With a single provider, diversity comes from different models and effort levels (e.g. three Claude agents with different models/efforts).
- Configurability of this kind is wanted in many places, not only for review.
- Each provider runs as its own process in a terminal (CLI), logged in with the owner's subscription (D-04).

### R10. Communication between agents — `agreed` (D-11)
- Sessions of different agents from different providers can exchange messages.
- The messagebus.ai product will **not** be used (D-08); only its ideas are taken: a task is addressed to a role, not to a
  specific agent, and any agent holding that role picks it up; budget caps (in v1 per item and per run, D-66); an audit log;
  threads; failed-delivery tracking; human approval of steps; limits on what a run may reach or push.
- Agents communicate only through an orchestrator-owned, append-only board (D-11).

### R11. Adversarial code review — `agreed` (D-13, D-14)
- Code review follows the Adversarial Code Review pattern (asdlc.io) and adopts the best of Anthropic's
  "Solving code review at Anthropic" practices. Pipeline: D-13; approval rules: D-14.

### R12. CLI library — `agreed` (D-43)
- Spectre.Console with Spectre.Console.Cli; RazorConsole not used in v1 (D-43).

### R13. End-to-end tests as a mandatory step where they make sense — `agreed` (D-44–D-47)
- Every plan declares `e2e: required` or `not-applicable` with a reason (D-44); required E2E tests are written in the red step, one per acceptance scenario (D-45); xUnit + WebApplicationFactory + Azurite and Playwright Test by default (D-46); Azurite via npm, flaky tests visible (D-47).

## Proposed by Claude (P)

| ID | Proposal | Source of the idea | Status |
|---|---|---|---|
| P1 | **Holdout scenarios.** Acceptance scenarios (WHEN/THEN) are stored where the builder cannot see them; a separate agent or run checks them | StrongDM | `deferred` to v2 (D-67) |
| P2 | **Constraints as code, not only text.** R1 has two layers: principles in Markdown for agents + enforceable rules (architecture tests, ESLint boundaries, Roslyn analyzers) that fail a gate | Fitness functions | `agreed` (D-22) |
| P3 | **Ratchet + journal.** Quality metrics never rise (baseline in the repo); each run writes a row of facts; "not measured" ≠ 0 | Prior art | `agreed` (D-23) |
| P4 | **Builder ≠ critic.** The critic never uses the same agent profile as the builder; prefer a different provider | Swarm, adversarial review | `agreed` (D-10) |
| P5 | **Persistent state machine.** Each item's state is stored, runs can stop and resume, steps are idempotent | dw `plan.md` phase | `agreed` (D-48) |
| P6 | **Kill switch, dry run, parallelism cap.** Stop everything with one command; run without writing to GitHub; at most N stations at once | Safety | `agreed` (D-38) |
| P7 | **Quota dispatcher.** Before starting an item, check remaining subscription limits; wait or switch profile when short | Prior art | `agreed` (D-19) |
| P8 | **Cloud only via IaC with preview.** Anything that costs money (Azure resources) is created via Bicep/Terraform with what-if and human confirmation; agents hold no production secrets | R5 | `deferred` to v2 (D-48) |
| P9 | **Lessons become rules.** After a group: a retrospective proposes edits to CLAUDE.md / REVIEW.md / constraints as a separate PR approved by a human | Prior art, Anthropic | `agreed` (D-37) |
| P10 | **Parallel-work conflicts.** Plans declare files; the dispatcher does not start overlapping items; merging goes through a queue | Swarm | `agreed` (D-38) |
| P11 | **Evals for the factory itself.** Reference tasks prove a change to the factory did not make it worse; escaped bugs and reverts become new cases | dw evals, Anthropic | `deferred` to v2 (D-69) |
| P12 | **Cost: estimate vs actual.** Tokens/$ and time per item and group, compared with the complexity estimate | dw `/dw:usage` | `agreed` (D-48) |
| P13 | **Circuit breaker.** When reverts, escaped bugs or review noise rise, autonomy tightens automatically (more critics, more human approvals, dark mode off) | Gap named by Anthropic | `deferred` to v2 (D-69) |
| P14 | **Review noise is measured.** Every finding is classified by the outcome: fixed, wrong, intentional, doesn't matter; plus runs on known-clean PRs to count false alarms | Anthropic | `agreed` as telemetry (D-39, D-69) |
| P15 | **Role = purpose + instructions + capability profile.** Each role has a one-line purpose, an instructions file, a model allowlist with a default, and capability switches: edit files (own worktree only), run commands, run only the repo's tests, push branches (never protected, never merge), web access (allowlist). Presets such as "reviewer: read-only". The station enforces them, not the prompt | Reference UI | `agreed` (D-17) |
| P16 | **"Needs a look" panel.** Grouped failure reasons per role, providers close to their usage limit, items stuck or waiting on a human | Reference UI | `agreed` (D-42) |
| P17 | **Slots.** Each machine has N slots (parallel stations); the UI shows busy / free and the busiest time | Reference UI | `agreed` (D-38, D-42) |
| P18 | **Routes into roles.** Besides a manual start, events can trigger a role: GitHub events, a schedule (e.g. a nightly review agent over existing code) | Reference UI, Anthropic | `agreed` for v2 (D-40) |
| P19 | **Test a role.** Run a role on a sample task before enabling it or after changing its model or instructions | Reference UI, P11 | `deferred` to v2 (D-48) |
| P20 | **Run dashboard.** Tasks and failure rate, spend per day and per role, tasks per day | Reference UI | `agreed` (D-42) |

## Non-goals for v1 (agreed)
- Dark auto-merge by default — merging to main always needs a human; dark routes are opt-in only (D-03).
- Deployment to Azure or any production environment (D-49).
- The company product with SLAs, Azure DevOps and GitHub Enterprise — a later stage as an adapter (D-02).
- A cloud runner — v1 runs on the owner's Mac (D-04).
- Schedules and event-triggered runs (D-40), testing a role (P19), cloud resources via IaC (P8) — v2.
- Council voting (D-64), holdout scenarios (D-67), dark routes, circuit breaker and eval harness (D-69) — v2.
- A terminal UI — the web UI is the interactive surface (D-43).
