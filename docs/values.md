# Values

Binding for every design and change of the factory. In priority order: when two collide, the earlier one wins,
and the collision is worth one line in the decision or PR that resolved it (D-33).

## 1. Verified outcome per token
Spend tokens only where the result can change a decision or produce a required artifact. Measure tokens per *verified* outcome, not per call.
Deterministic checks before models (D-29); no two agents asked the same question without a distinct reason (D-10); retries only with new information.
- Test: every model call names the decision or artifact it advances; every run reports spend against its budget (D-19, D-28).

## 2. Minimal worker context
A worker gets the smallest sufficient, role-specific input — never the parent session, another worker's reasoning or a repository dump (D-30).
- Test: every worker call has an input manifest; extra context is fetched by a tool and logged on the board.

## 3. Simple
Few entities, each with one job. Removing an entity beats adding a knob. Defaults work with an empty config.
- Test: the entity model fits on one page; a new concept replaces or merges with an existing one before it is added (D-33).

## 4. Safe by structure
Safety comes from how the system is built, not from instructions: disposable copies, empty environments, no credentials in workers,
diff checks against allowed paths, configuration read from a commit, human merge (D-03, D-26, D-27).
- Test: a misbehaving worker of any provider cannot push, merge, change the rules or touch protected paths.

## 5. Observable
Every decision, vote, finding, refusal and cost is recorded on the board with its reason. "Not measured" is shown as no data, never as zero (D-29).
- Test: a person can trace one item end to end from the board without reading code; every refusal names the rule or budget that refused.
