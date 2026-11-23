# Light Software Factory

A local, single-user software factory: GitHub issues go in, reviewed pull requests come out, and a human merges every PR.
An orchestrator plans each run, then drives agents from Claude Code, Antigravity and Codex, each running as a sandboxed headless CLI
under the owner's own subscription, through planning, test-first building, deterministic gates and adversarial review.
It is built with .NET, React and SQLite, runs on the owner's Mac, and v1 stops before deployment.

## Status

- **Design: complete and reviewed.** Requirements are confirmed (decisions D-01…D-74; accepted since: D-75, D-76, D-78, D-79, D-81…D-85; still proposed: D-77, D-80); architecture v1 revision 4.1 went through
  three review rounds, an independent simplification review and a consistency check.
- **Next: the implementation spike** ([plan](docs/spike/plan.md)) to settle the open questions about running provider CLIs
  inside the macOS sandbox.
- **No code yet.**

## Start here

| Read | Why |
|---|---|
| [How it works](docs/how-it-works.md) | Explainer for newcomers, with diagrams |
| [Values](docs/values.md) | The five values, in priority order; binding for every design choice |
| [Requirements](docs/requirements.md) | What v1 must do, and what it deliberately does not |
| [Decisions](docs/decisions.md) | Every owner decision with its rationale (D-01…D-85; D-77 and D-80 are proposed) |
| [Architecture](docs/architecture/architecture.md) | Architecture v1: entity model, components, sandbox, state machines, open questions |
| [ADRs](docs/architecture/adr/) | ADR-001…ADR-007 |
| [Documentation index](docs/README.md) | All documents, including glossary, research notes and review history |

## Repository layout

| Path | Contents | State |
|---|---|---|
| `docs/` | Requirements, decisions, values, glossary, architecture, ADRs, reviews, spike plan | present |
| `spike/` | Throwaway experiments for the implementation spike (Seatbelt profiles, CLI harness) | planned |
| `src/` | .NET solution: `Factory.Station`, `Factory.Core`, `Factory.Host` | planned |
| `web/` | React UI, built into the host | planned |
| `tests/` | Unit, Station hostile-worker and host tests | planned |
| `openspec/` | OpenSpec specs, changes, and project config for this repository | present |

## Roadmap

1. **Implementation spike.** Run each provider CLI headless inside a deny-by-default sandbox with Keychain-free credentials,
   behind a proxy, and mark it supported or unsupported. See [docs/spike/plan.md](docs/spike/plan.md).
2. **OpenSpec** drives the implementation (done: initialized locally via `package.json`, with tool configs for Claude Code,
   Gemini CLI, Antigravity and Codex). One OpenSpec change per group of work; GitHub milestones and issues track it (D-73, proposed).
3. **v1 implementation**, as described in the [architecture](docs/architecture/architecture.md), starting from the spike findings.
4. **v2** (agreed but deferred; see [architecture §17](docs/architecture/architecture.md#17-deferred-to-v2)):
   - council voting across providers, with a judge;
   - holdout scenarios (hidden acceptance checks);
   - dark routes (merge without a human), the circuit breaker, and an eval harness for the factory itself;
   - answering escalations by GitHub comment;
   - schedules and event triggers, testing a role, cloud resources via IaC, and another isolation method only if needed;
   - a full terminal UI, a cloud runner, and deployment.

## Contributing

This is a personal project. Decisions in [docs/decisions.md](docs/decisions.md) are made by the owner; design changes are
proposed as new decision entries. Coding agents follow [AGENTS.md](AGENTS.md).

## License

[MIT](LICENSE).
