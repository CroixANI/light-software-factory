# Software Factory — documentation

← Back to the [repository README](../README.md).

**Status:** requirements confirmed (D-01…D-74). Architecture v1 revision 4.1 — reviewed in 3 rounds, simplified after an independent Gemini review, consistency-checked; ready for the implementation spike. New readers start with [how-it-works.md](how-it-works.md).
**Purpose of this folder:** agree on *what* we build before deciding *how*. Architecture, ADRs and specs come after the requirements reach `agreed`.

## What it is

A local software factory: an orchestrator that takes pre-split GitHub issues, plans a run you confirm, runs isolated
stations in parallel with agents from several providers, checks every plan with a critic (council votes come in v2), reviews code
adversarially, enforces budgets, escalates to a human when needed, and opens one PR per item for a human to merge.
It has its own provider-agnostic station; the dw plugin is a source of ideas, not a dependency (D-25).

## v1 on one page

**Input.** A parent GitHub issue with pre-split sub-issues, ordered by GitHub dependencies (D-05). Specs: one OpenSpec change per group (D-21).
Constraints: a constitution file + enforceable rules (D-22).

**Start.** Manual, from the CLI or local web UI (D-40). A token-free plan shows items, order, roles, gates, caps and estimated spend;
the owner confirms it by ID (D-28). Configuration is read from the commit the run starts on (D-27).

**Per item.** Planner drafts the plan with design options and an explicit E2E decision (D-44, D-64) → a read-only critique of the plan;
disagreement goes to the owner (D-51) → test author writes failing tests, incl. E2E and boundary/negative-path tests (D-45, D-67) →
builder implements in a disposable copy under a deny-by-default sandbox, no credentials (D-26, D-56) → deterministic gate (D-29, D-47) →
adversarial review: read-only critic lenses, verifier vote only on Important findings, max 3 rounds (D-13, D-68) → orchestrator opens one PR;
a human merges (D-03, D-37). New dependencies are approved before restore (D-62, D-65).

**Group done.** All items merged, gate green on main, OpenSpec change archived, retrospective PR open (D-37).

**Agents.** Claude, Gemini, OpenAI as headless local CLI processes under the owner's own subscriptions, no extra macOS users (D-24, D-57, D-63).
Five roles stored as data with capability presets, editable in the UI via PR (D-17, D-18, D-72); critic ≠ builder profile (D-10).
Workers see only a manifest of inputs and talk only through the orchestrator's board (D-11, D-30, D-53).

**Limits and safety.** Caps on tokens, steps, wall time and rounds per item and run (D-66); escalations answered in the local UI/CLI,
mirrored to GitHub as notifications (D-20, D-70); 2 slots, declared files, kill switch, dry run (D-38); approvals by risk tier, bound to a
commit, agents never count as humans; safe GitHub Actions settings required (D-14, D-50).

**Product.** .NET + ASP.NET Core minimal API + React + SQLite (D-34); CLI first with Spectre.Console and live terminal views (D-31, D-43, D-59);
five UI screens (D-42); machine state outside the target repo (D-35); free quality tooling on by default, paid off (D-23, D-41).

**v2.** Council voting across providers (D-64), holdout scenarios (D-67), dark routes, circuit breaker, eval harness (D-69), schedules, TUI,
cloud runner, deployment. **Out of v1:** see [requirements.md](requirements.md#non-goals-for-v1-agreed).

## Files

| File | Contents |
|---|---|
| [how-it-works.md](how-it-works.md) | Explainer for newcomers: identities, roles, constraints, communication, item and group lifecycle (Mermaid diagrams) |
| [requirements.md](requirements.md) | Requirements: stated by the owner (R*) and proposed by Claude (P*), with status |
| [decisions.md](decisions.md) | Decisions with rationale |
| [values.md](values.md) | Values in priority order — binding for design (D-33) |
| [grilling-log.md](grilling-log.md) | Interview rounds: questions, recommendations, answers |
| [research-notes.md](research-notes.md) | Verified facts and sources |
| [glossary.md](glossary.md) | Shared vocabulary |
| [architecture/](architecture/) | Architecture v1 ([`architecture.md`](architecture/architecture.md), [`adr/`](architecture/adr/)); review rounds, triage ledgers and the Gemini review in [`reviews/`](architecture/reviews/) |
| [process/session-protocol.md](process/session-protocol.md) | What an agent does on a short command ("do next task", "spec <slug>", …); D-74 |
| [process/orchestrator.md](process/orchestrator.md) | What the session orchestrator does on `orchestrate`: finds the next tasks, proposes them, launches or prints their sessions; D-83 |
| [spike/plan.md](spike/plan.md) | Implementation-spike plan derived from the architecture's open questions |

## Process

1. A round of questions → answers → decisions in `decisions.md`, statuses in `requirements.md`.
2. Repeat until the question frontier is empty and both sides confirm shared understanding.
3. Only then: architecture, ADRs, specs.

Claude looks up facts; the owner makes decisions. Nothing is implemented before confirmation.
All documents are in English (D-07); the interview itself may be held in Russian.
