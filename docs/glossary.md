# Glossary

| Term | Meaning |
|---|---|
| Loop | One agent repeating one job: gather context → act → check, until a condition is met |
| Station (harness) | The environment around a loop: disposable repo copy, empty environment, tools, "done" gates. The factory's own, provider-agnostic (D-25, D-26) |
| Factory | Many stations in parallel, fed by a queue, passing through review gates; the human owns the outer loop |
| Orchestrator | The factory process that owns the queue, dispatches stations, runs checks and reviews, enforces caps, and alone commits, pushes and opens PRs (D-26). A CLI first, with the web UI as a client (D-31) |
| Item | One task (GitHub issue) handled by one station |
| Group / feature | A parent issue with sub-issues; limits the scope of a factory run (D-05) |
| Light mode | Agents do the work; humans approve expensive decisions and every merge to main (D-03) |
| Dark mode | Merge without a human reading the code, on machine checks only; opt-in per task type or path |
| Role | A job an agent performs. v1: planner, test author, builder, critic, finding verifier (council voter and judge in v2, D-64) |
| Agent profile | A (provider, model, effort) combination assigned to a role |
| Council | v2 (D-64): an odd number (1, 3, 5, 7) of agent profiles voting on a question with discrete options. In v1 design options live in the item plan |
| Judge / moderator | v2 only (D-64, D-68). In v1 the review checklist is built deterministically from critic-tagged findings |
| Builder | Writes the code for an item |
| Critic | Reviews a diff against the spec in a fresh context; read-only; may run in parallel lanes |
| Finding verifier | Votes on whether a reported finding is real before it is shown |
| Board | The ordered record of all messages between agents for a run (see Q10) |
| Gate | Blocks a run or release |
| Ratchet | Keeps a metric from rising; the baseline lives in the repo (a known prior-art pattern) |
| Telemetry | Measured and shown, never blocks |
| Escalation | Handing a question to a human when the factory cannot settle it |
| Budget (cap) | A limit on tokens, steps, wall time or rounds — per item and per run; no reservations (D-66) |
| Holdout scenarios | v2 (D-67): acceptance scenarios that the builder cannot see |
| Risk tier | Low / medium / high, set by the change (not the author); decides checks and approvals |
| Plan (of a run) | Token-free preview of items, order, roles, gates, budgets and estimated spend, confirmed by ID before anything runs (D-28) |
| Input manifest | The exact list of what a worker receives (D-30) |
