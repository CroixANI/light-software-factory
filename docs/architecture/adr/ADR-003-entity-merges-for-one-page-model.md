# ADR-003 — Merge concepts to keep the entity model at nine entities

- **Status:** Proposed (2026-11-20; revised in revisions 2, 3 and 4)
- **Relates to:** D-33 (one-page model, merge before adding), D-11, D-14, D-20, D-28, D-64, D-66, P3

## Context
The requirements name many concepts: plan, run, group, item, station, slot, worker call, gate result, vote, escalation, approval, finding, verification, budget, board, journal, measurement, ADR, ratchet, provider, agent profile, role. Giving each a table would break D-33. Several of them do the same job.

## Decision
| Concept | Becomes | Why the merge holds |
|---|---|---|
| Plan (of a run) | Part of **Run** (`plan`, `plan_id`, state `planned`) | A plan is exactly the run before confirmation |
| Escalation, human approval (plan, dependency, rule-path diff, e2e change), plan disagreement, finding verification | **Question** (`kind = verify/escalation`, `addressee = verifiers/human`) | All are "a decision among discrete options made by majority or a human": one vote/answer mechanism, one inbox |
| Vote, answer, approval record | **Board entry** | Events about a Question |
| Journal, measurement, gate result detail | **Board entry** (`measurement`, `check.result`) + view | Append-only facts |
| Station | **Item** worktree fields + **Step** folder | A runtime environment, not data with a life of its own |
| Worker call, gate check, restore | **Step** (`kind = worker/check`) | Same accounting (duration, outcome, idempotency) |
| Budget, spend | Caps in config + projection over **Step** (D-66) | Spent is a sum; no reservation state to keep |
| Slot | A number in `machine.yaml`; occupancy is derived from item states | Removing an entity beats adding a knob |
| Plan critique result | **Finding** (lens `plan`) + Step output | A plan defect is a finding like a diff defect (D-51) |
| Design decision | Value in the item plan; rendered as an ADR file (D-64) | No council in v1 |
| Agent profile, input manifest, item plan, checklist, workspace level | Value objects / derived from the Role preset | No identity of their own |

## Consequences
- Nine entities (Provider, Role, Run, Group, Item, Step, Question, Finding, Board entry), which fit on one page.
- Question carries a `kind`. A v2 council adds a `design` kind and a voting role without a schema change.
- Any new concept must first be shown not to fit one of these nine (D-33).

## Alternatives considered
- **Separate Escalation and Approval entities:** duplicated inbox and answer logic.
- **Budget entity with reservations (revisions 1–3):** needed reservation bookkeeping and could not measure `requests` (C1); removed by D-66.
- **Finding as a Question:** a finding has its own location, tag and outcome; it stays an entity, and its verification is a Question.
