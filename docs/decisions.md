# Decisions

One decision per entry. Decisions are never deleted; replaced ones are marked `superseded by D-NN`.

```
## D-NN — <title>
- Date / round:
- Question: Q-NN
- Decision:
- Why: (one or two lines)
- Affects: R*, P*
```

## D-01 — The factory is a separate orchestrator that uses dw as its station — `superseded by D-25`
- Date / round: 2026-11-20, round 1
- Question: Q1
- Decision: the factory is its own orchestrator and calls dw for each item. dw stays the single-item harness; it gains only a "policy gates" mode in place of interactive `ask` prompts.
- Why: dw already enforces plan approval, test locks and review triage; in `-p`/`dontAsk` mode an `ask` cannot prompt, so the factory needs policy decisions, not new commands.
- Affects: all

## D-02 — v1 targets the owner's own greenfield projects
- Date / round: 2026-11-20, round 1
- Question: Q2
- Decision: v1 is built for the owner's own new projects on a personal GitHub account with the R1 stack. The company product (Azure DevOps, GitHub Enterprise, SLAs) is a later stage, added as an adapter. Risk tiers are modelled from day one.
- Why: mistakes are cheap and metrics are clean on greenfield; risk tiers now avoid a rewrite later.
- Affects: R1, R2, R8

## D-03 — Light mode by default
- Date / round: 2026-11-20, round 1
- Question: Q3
- Decision: the factory takes an item all the way to a PR; merging to main always needs a human. Dark auto-merge is opt-in, only for listed task types or paths.
- Why: autonomy widens on evidence (accepted PRs, reverts, review findings), not by default.
- Affects: R11, P13

## D-04 — v1 runs locally; providers run as terminal processes; roles are configurable — "in a terminal" amended by D-57
- Date / round: 2026-11-20, round 1 (amended by the owner)
- Question: Q4
- Decision: v1 runs on the owner's Mac as a long-running process with a git worktree per item. Each provider runs as its own CLI process in a terminal, logged in with the owner's subscriptions. A cloud runner comes later as an adapter. Amendment: providers and per-role agent settings (models, effort, odd count 1/3/5/7, default 1) are configured in the factory UI, and this kind of configurability applies in many places.
- Why: local is cheapest and easiest to watch; with a Claude plan login, `claude -p` and the Agent SDK draw from subscription limits (research-notes). Configurable roles let one provider still give diversity through models and effort.
- Affects: R2, R3, R9, R10

## D-05 — Groups are parent issues; order comes from GitHub dependencies
- Date / round: 2026-11-20, round 1
- Question: Q5
- Decision: a group is a parent issue with sub-issues; order uses GitHub's native "blocked by" dependencies; a run can be limited to one parent issue or milestone.
- Why: GitHub already stores hierarchy and dependencies and shows them without our UI.
- Affects: R2, R8

## D-06 — Councils vote on discrete options; code goes through adversarial review
- Date / round: 2026-11-20, round 1 (extended by the owner)
- Question: Q6
- Decision: councils vote on discrete options (a judge formulates A/B/C; a vote is an option id plus rationale) for design and plan decisions, not on code. Code goes through adversarial code review (asdlc.io pattern) combined with the best of Anthropic's code review practices.
- Why: "2 of 3" only works when answers are comparable; for code, checks and verified findings work better than votes.
- Affects: R3, R11

## D-07 — Requirements and documentation are written in English
- Date / round: 2026-11-20, round 1 (owner's answer: no)
- Question: Q7
- Decision: all requirements and documentation are in English. The current interview may be held in Russian.
- Why: the factory will be shown to colleagues from several countries; English is the shared language.
- Affects: all documents

## D-08 — messagebus.ai is not used; only its ideas are taken
- Date / round: 2026-11-20, round 1 (owner's follow-up)
- Question: — (owner's instruction)
- Decision: do not depend on messagebus.ai. Take its ideas: tasks addressed to roles, budget caps per project and role, audit log, threads, failed-delivery tracking, human approval of steps, limits on what a run may reach or push.
- Why: owner's decision.
- Affects: R10, Q10

## D-09 — Fixed role catalog in v1
- Date / round: 2026-11-20, round 2
- Question: Q8
- Decision: v1 roles are planner, council voter, judge/moderator, builder, critic, finding verifier, test author. Only voting roles (council voter, finding verifier) take an odd count 1/3/5/7 (default 1). Critics are configured as a list of lenses. Builder, judge and test author always run as one agent.
- Why: a fixed catalog keeps the UI and budgets predictable; an odd count only matters where there is a vote.
- Affects: R3, R9, R11

## D-10 — Diversity rule for multi-agent roles
- Date / round: 2026-11-20, round 2
- Question: Q9
- Decision: with more than one agent in a role, each gets a distinct agent profile (provider, model, effort). A critic or verifier never uses the builder's exact profile; a different provider is preferred when connected. If there are fewer distinct profiles than the count, the UI rejects the configuration.
- Why: identical agents voting is one opinion counted several times.
- Affects: R9, P4

## D-11 — Orchestrator-owned board
- Date / round: 2026-11-20, round 2
- Question: Q10
- Decision: the orchestrator owns a local, append-only board per run: threads per item and question, messages addressed to roles, an audit log and delivery status. Agents never message each other directly; provider CLIs read and write only through the orchestrator (e.g. a local MCP server it exposes).
- Why: one ordered record is easy to replay, audit and budget; takes messagebus.ai's ideas without the dependency (D-08).
- Affects: R10, R2

## D-12 — No majority escalates to a human
- Date / round: 2026-11-20, round 2
- Question: Q11
- Decision: if a council has no majority within the round cap (default 3), the question goes to a human with options, tallies and rationales. The judge never breaks ties.
- Why: a tie means the question is genuinely open.
- Affects: R3, R6, R7

## D-13 — Review pipeline v1
- Date / round: 2026-11-20, round 2
- Question: Q12
- Decision: builder → critic lanes in a fresh context (default lenses: spec and correctness, security, architecture constraints), read-only, favoring false positives → finding verifiers vote on each finding; only majority-confirmed findings survive → moderator merges them into one checklist tagged Important / Nit / Pre-existing → builder fixes only Important; nits capped; pre-existing findings become follow-up issues. From round 2 the review is diff-only with no repeated findings; after 3 rounds the item is escalated.
- Why: adversarial critics catch more; verifier voting removes their false positives; the round cap stops endless loops.
- Affects: R11, R7

## D-14 — Approval rules
- Date / round: 2026-11-20, round 2
- Question: Q13
- Decision: the risk tier is set by the change (paths plus a classifier), not by the author. Agent approvals never count as human approvals. A human approval is tied to a commit SHA; new commits need re-approval. Sensitive paths and CI workflow files always need a human.
- Why: Anthropic's rules; they make a later move to dark mode safe.
- Affects: R11, D-03

## D-15 — Two-level configuration
- Date / round: 2026-11-20, round 2
- Question: Q14
- Decision: a machine-local provider registry (installed and logged-in CLIs; no secrets copied) and a per-repo factory config file versioned in the target repo (roles, counts, budgets, gates) that the UI edits. Credentials never go into config.
- Why: repo config is reviewable by PR and shareable; provider logins stay personal.
- Affects: R9, R5

## D-16 — Local web UI
- Date / round: 2026-11-20, round 2
- Question: Q15
- Decision: the orchestrator serves a local web app on localhost: configuration editor, start / stop / kill switch, live board, escalation inbox, cost. GitHub stays the source of truth for issues and PRs. No hosted service in v1.
- Why: matches D-04; no hosting or auth; the board gives the UI everything to display.
- Affects: R2

## D-17 — A role is purpose + instructions + capability profile
- Date / round: 2026-11-20, round 3
- Question: Q16
- Decision: a role has a one-line purpose, an instructions file, a model allowlist with a default, and capability switches (edit files in its own worktree, run commands, run only the repo's tests, push branches — never protected, never merge — web access by allowlist) with presets such as "reviewer: read-only". Switches are enforced by the station, not by the prompt. How they are enforced: D-26.
- Why: a prompt can be ignored; enforcement cannot.
- Affects: R9, P15

## D-18 — Roles are stored as data
- Date / round: 2026-11-20, round 3
- Question: Q17
- Decision: one file per role in the repo config, so the fixed v1 catalog (D-09) can later grow custom roles, "copy role" and "test role" without code changes.
- Why: free now; keeps D-09 from being a dead end.
- Affects: R9, P19

## D-19 — Nested budgets with visible overrun states
- Date / round: 2026-11-20, round 3
- Question: Q18
- Decision: budgets nest run → group → item → question. Dimensions: rounds per question (default 3), tokens or $ per item and per run, wall time per item, provider usage threshold (default 80%) above which no new item starts on that provider. Item or question overrun → escalation, never a silent failure. Run overrun → no new items; running ones finish their current step and stop.
- Why: every limit ends in a state a human can act on.
- Affects: R7, P7

## D-20 — Escalation: UI inbox mirrored to GitHub
- Date / round: 2026-11-20, round 3
- Question: Q19
- Decision: the UI inbox is primary; each escalation is mirrored as a comment on the item's issue plus a `factory:needs-human` label. Grill format (options + recommendation + evidence links); answer by option number or free text. The item is parked; independent items continue. macOS notification optional.
- Why: answerable from a phone; one question does not stall the group.
- Affects: R6

## D-21 — OpenSpec at group level, behind an adapter
- Date / round: 2026-11-20, round 3
- Question: Q20
- Decision: a parent issue = one OpenSpec change (proposal, specs with WHEN/THEN, design, tasks); sub-issues map to its tasks; archiving merges deltas into live specs. Item-level specs reference OpenSpec requirements. The spec format sits behind an adapter so Spec Kit can be added later.
- Why: "a group = a change merged into live specs" is OpenSpec's model.
- Affects: R4

## D-22 — Constraints: constitution file + enforceable rules + ADRs
- Date / round: 2026-11-20, round 3
- Question: Q21
- Decision: constraints live in a constitution-style file (stack, principles, allowed and forbidden choices) plus enforceable rules (architecture tests for .NET, dependency rules for React). Within the constraints the council chooses concrete options and records them as ADRs. Changing the constraints is high risk and needs a human.
- Why: text guides agents; rules catch what they miss, especially negative constraints.
- Affects: R1, P2

## D-23 — First-run wizard: free set on, paid options off
- Date / round: 2026-11-20, round 3
- Question: Q22
- Decision: always on: ESLint + Prettier, `dotnet format` + Roslyn analyzers with warnings as errors, Dependabot, ratchet and journal, Azurite for local Table and Blob storage. Offered with cost notes, off by default: SonarQube Cloud, CodeQL and secret scanning, real Azure resources. Choices saved to the repo config.
- Why: free set covers the basics; no cloud bill until something is deployed.
- Affects: R5, P3, P8

## D-24 — Personal-use boundary for providers
- Date / round: 2026-11-20, round 3
- Question: Q23
- Decision: one account per provider, the owner's own work, one machine; never pooled across accounts, never exposed as a shared service. Colleagues run the factory with their own logins.
- Why: matches Claude Code's terms and Google's guidance against pooling accounts.
- Affects: R9, D-04

## D-25 — The factory has its own provider-agnostic station (supersedes D-01)
- Date / round: 2026-11-20, round 4
- Question: Q24
- Decision: the factory has its own station that works the same for every provider. dw stays a separate interactive tool for human-driven work. The factory ports dw's ideas, not its code.
- Why: dw's enforcement runs in Claude Code hooks, which Gemini CLI and Codex do not execute; dw carries interactive features the factory does not need.
- Affects: all

## D-26 — Structural enforcement (refines D-17)
- Date / round: 2026-11-20, round 4
- Question: Q25
- Decision: workers run in a disposable copy of the repo with an empty environment plus an allowlist. Workers hold no Git push or GitHub credentials; only the orchestrator commits, pushes and opens PRs. After each worker step the orchestrator checks the diff against the role's allowed paths (e.g. the builder may not touch red-step tests, protected paths or factory config) and rejects violations. Provider CLIs' own sandbox and approval settings are an extra layer, not the main one.
- Why: holds for any provider and cannot be bypassed by a wrapped shell command.
- Affects: R9, D-17, P15

## D-27 — Configuration is read from a commit
- Date / round: 2026-11-20, round 4
- Question: Q26
- Decision: a run reads the factory config, roles and constraints from the commit it started on, never from the working tree. Changes go through a PR.
- Why: an agent cannot rewrite its own rules mid-run; colleagues run the same pipeline.
- Affects: D-15, D-18, D-22

## D-28 — Plan before spend
- Date / round: 2026-11-20, round 4
- Question: Q27
- Decision: every run starts with a token-free plan (items and order, roles and agent profiles, gates, budgets, spend estimate). The human confirms that exact plan by ID. Budgets are reserved before dispatch; a limit stops new work, not calls already running; the refusing limit is named.
- Why: the human sees what will happen and what it may cost before anything is spent.
- Affects: R2, R7, D-19

## D-29 — Deterministic gate first; incomplete is not clean
- Date / round: 2026-11-20, round 4
- Question: Q28
- Decision: the project's own checks (build, lint, tests, constraint rules) run before any model review. A check that could not run is a failure. A reviewer or verifier that did not answer leaves the round incomplete, never clean.
- Why: models spend tokens only on code that compiles and passes tests; "not measured ≠ 0".
- Affects: R5, R11, D-13

## D-30 — Minimal context per worker
- Date / round: 2026-11-20, round 4
- Question: Q29
- Decision: each worker gets a manifest of exactly what it receives (spec slice, plan, diff, gate results) and never another worker's reasoning or transcript. Extra context is fetched on demand through tools and logged on the board.
- Why: the adversarial "context swap" as a rule; saves tokens.
- Affects: R11, D-11

## D-31 — CLI first
- Date / round: 2026-11-20, round 4
- Question: Q30
- Decision: the orchestrator is a CLI with `--json` output, stable exit codes, `next_action` in state documents and a `doctor` command. The web UI (D-16) is a client of the same API.
- Why: scriptable, testable, drivable by an agent or CI without the UI.
- Affects: R2, D-16

## D-32 — dw parts not carried into v1
- Date / round: 2026-11-20, round 4
- Question: Q31
- Decision: dropped: per-item grill interview, `/dw:start` routing and local items, scope / split / investigate, the worktree-or-branch question, multi-repo items, stacked PRs and pr-sweep, iterations and `history.md`, text-matching shell gates, the hash test lock (replaced by D-26). Changed: the simplifier becomes a read-only critic lens. Kept as ideas: spec → plan → diff → PR, plan approval, test-first red step, fresh reviewer and triage, `Never dismiss`, repo profile commands as the gate, usage accounting, evals.
- Why: each dropped part is upstream of the factory, replaced by a stronger rule, or not needed for one greenfield repo. Table: research-notes, "dw review".
- Affects: D-25

## D-33 — Values in priority order and a simplicity rule
- Date / round: 2026-11-20, round 4
- Question: Q32
- Decision: the factory has a values document in priority order ([values.md](values.md)). The entity model must fit on one page; a new concept must replace or merge with an existing one before it is added.
- Why: keep afactory's ideas without its weight (344 ADR files, 457 schema files).
- Affects: all

## D-34 — The factory is built on the R1 stack
- Date / round: 2026-11-20, round 5
- Question: Q33
- Decision: orchestrator and CLI in .NET; ASP.NET Core minimal API also serves the local web UI; UI in React; local state in SQLite.
- Why: the owner's main stack; one process covers CLI + API + UI; the factory can later build and review itself.
- Affects: R1, D-16, D-31

## D-35 — Machine state stays out of the target repo
- Date / round: 2026-11-20, round 5
- Question: Q34
- Decision: board, journal, run plans, worktrees and logs live in the owner's local application-data folder. The target repo holds only human-reviewed artifacts: factory config, roles, constitution, ratchet baselines, OpenSpec specs, ADRs.
- Why: the repo stays clean; agent output reaches it only through a PR.
- Affects: D-11, D-15, P3

## D-36 — Holdout scenarios — content amended by D-55
- Date / round: 2026-11-20, round 5
- Question: Q35
- Decision: at group start the planner drafts acceptance scenarios (WHEN/THEN) from the OpenSpec change; a human approves them; they live in the local state folder, outside the builder's copy. After the gate a separate check runs them against the built app (with Azurite). On failure the builder gets the scenario name and observed vs expected behavior, not the scenario's code. When the group is done they are committed as ordinary end-to-end tests. Written by the test author (no new role).
- Why: the builder cannot tailor code to tests it cannot see; scenarios become regression tests.
- Affects: P1, R4

## D-37 — Delivery and definition of done
- Date / round: 2026-11-20, round 5
- Question: Q36
- Decision: one PR per item from `factory/<issue>-<slug>`; the PR body carries the plan, gate results, review ledger and cost; a human merges in dependency order; a dependent item starts from main after its prerequisites merge; the gate runs on main after each merge. A group is done when all items are merged, holdout scenarios pass on main, the OpenSpec change is archived and the retrospective PR is open.
- Why: closes the "no check of main after merge" gap; "done" becomes testable.
- Affects: D-03, D-21, P9

## D-38 — Slots, declared files, kill switch, dry run
- Date / round: 2026-11-20, round 5
- Question: Q37
- Decision: N slots per machine (default 2). Items run in parallel only when dependencies allow and their declared files do not overlap; touching undeclared files is rejected. A kill switch stops everything. Dry run plans and runs gates without models or GitHub writes.
- Why: predictable conflicts; learn without fighting subscription limits.
- Affects: P6, P10, P17, D-26

## D-39 — Circuit breaker and review-noise tracking
- Date / round: 2026-11-20, round 5
- Question: Q38
- Decision: per group the factory tracks reverts, escaped defects and review noise (each finding: fixed / wrong / intentional / doesn't matter). Crossing a configurable threshold tightens autonomy automatically (more critics and verifiers, dark routes off) and notifies the human.
- Why: the gap Anthropic names; cheap to build in from day one.
- Affects: P13, P14, D-03

## D-40 — Manual start in v1
- Date / round: 2026-11-20, round 5
- Question: Q39
- Decision: v1 starts only manually from the UI or CLI. Schedules and GitHub-event routes come in v2; the data model already allows them.
- Why: simplicity (value 3).
- Affects: P18

## D-41 — Private repositories by default
- Date / round: 2026-11-20, round 5
- Question: Q40
- Decision: the factory assumes private repositories; the first-run wizard shows CodeQL and secret scanning as paid and SonarQube Cloud with its 50k-LOC free limit.
- Why: safer default; public repos only unlock more free tools.
- Affects: D-23

## D-42 — Five UI screens in v1
- Date / round: 2026-11-20, round 5
- Question: Q41
- Decision: Runs (plan preview and confirm, live board per item), Inbox (escalations), Config (providers, roles, budgets, tools), Health ("needs a look", slots, provider usage), Cost (per run, group, role). Charts and longer history later.
- Why: each screen maps to a decision already made.
- Affects: D-16, P16, P17, P20

## D-43 — Spectre.Console for the CLI
- Date / round: 2026-11-20, round 6
- Question: Q42
- Decision: the CLI uses Spectre.Console with Spectre.Console.Cli. RazorConsole is not used in v1.
- Why: the CLI is commands with `--json` and exit codes; the interactive surface is the web UI; RazorConsole is built on Spectre.Console, so a TUI can come later.
- Affects: R12, D-31

## D-44 — Explicit E2E decision per item
- Date / round: 2026-11-20, round 6
- Question: Q43
- Decision: every item's plan declares `e2e: required` or `e2e: not-applicable` with a reason. Required when the item changes user-visible behavior or a public API contract; not applicable for internal refactoring, docs or config. The planner proposes, the spec critic lens checks every "not applicable" reason, and the human can override in the plan preview.
- Why: "where it makes sense" becomes a reviewable decision, not a silent skip.
- Affects: R13, D-28

## D-45 — E2E tests in the red step
- Date / round: 2026-11-20, round 6
- Question: Q44
- Decision: when E2E is required, the test author writes at least one E2E test per acceptance scenario of the item (traced by OpenSpec scenario ID) in the red step; it fails before the change and passes after; it is part of the item's PR and runs in the gate. Holdout scenarios (D-36) remain a separate hidden layer.
- Why: visible E2E tests are the item's contract; holdout checks what the builder could not tailor to.
- Affects: R13, D-29, D-36

## D-46 — Default E2E tooling
- Date / round: 2026-11-20, round 6
- Question: Q45
- Decision: API level: xUnit + `WebApplicationFactory` with Azurite. UI level: Playwright Test (TypeScript) next to the React app. Recorded in the constitution; projects may change them.
- Why: free, common, well known to agents.
- Affects: R13, D-22

## D-47 — Running E2E without Docker; flakiness visible
- Date / round: 2026-11-20, round 6
- Question: Q46
- Decision: the gate starts Azurite as a local npm process; Docker is not a prerequisite. `doctor` checks Node, Playwright browsers and Azurite. A test that fails and then passes on retry is marked flaky on the board; no automatic quarantine in v1; repeated flakiness escalates.
- Why: fewer prerequisites; flakiness stays visible.
- Affects: R13, D-31

## D-48 — Remaining proposals
- Date / round: 2026-11-20, round 6
- Question: Q47
- Decision: in v1: P5 (persistent, resumable state machine per item), P11 (evals for the factory), P12 (cost estimate vs actual). Deferred to v2: P19 (test a role), P8 (cloud resources via IaC).
- Why: P5, P11, P12 are needed to trust and improve v1; P19 and P8 matter once roles are customized and something is deployed.
- Affects: P5, P8, P11, P12, P19

## D-49 — v1 stops before deployment
- Date / round: 2026-11-20, round 6
- Question: Q48
- Decision: v1 ends at merged PRs with a green gate on main. Deployment to Azure is out of scope for v1.
- Why: deployment brings secrets, costs and SLAs — a separate stage.
- Affects: P8, D-37

## D-50 — Safe GitHub Actions settings are a precondition
- Date / round: 2026-11-20, round 7 (architecture review A3)
- Question: Q49
- Decision: `doctor` refuses a repo unless the default workflow token is read-only, "Allow GitHub Actions to create and approve pull requests" is off, `main` is protected, and secrets are only in environments with protection rules (not available to `factory/*`). A diff touching `.github/**` needs a human approval of that diff, bound to its SHA, before it is pushed.
- Why: the push is the only path by which agent-written code could act with GitHub credentials.
- Affects: D-14, D-26

## D-51 — Every item plan is critiqued
- Date / round: 2026-11-20, round 7 (A8)
- Question: Q50
- Decision: every item plan gets one read-only critique step with a `plan` lens before `red` (accept / revise with findings; one revise round). The council still runs only for design questions.
- Why: R3 promises a critique for every item; a cheap critic call costs less than a wrong plan found after building.
- Affects: R3, D-06

## D-52 — E2E decision checked before red
- Date / round: 2026-11-20, round 7 (A9)
- Question: Q51
- Decision: the plan critique checks every `e2e: not-applicable` before `red`. A planner change from `required` to `not-applicable` parks the item for the owner's confirmation; a change the other way only posts a notice. A late finding can send the item back to `red`.
- Why: only the risky direction needs a human.
- Affects: D-44, D-45

## D-53 — What a worker may read
- Date / round: 2026-11-20, round 7 (A14)
- Question: Q52
- Decision: council voters, the judge and the moderator get no repo copy (manifest only). Critics and verifiers get a read-only full copy; builder and test author a writable full copy; all read on demand. A readable copy is not a "repository dump" under D-30; reads are logged where the CLI or sandbox can report them.
- Why: finding real bugs needs surrounding code; D-30 forbids pasting it into the prompt.
- Affects: D-30

## D-54 — Rationales: judge yes, voters no
- Date / round: 2026-11-20, round 7 (A15)
- Question: Q53
- Decision: the judge may read voters' typed rationales. Voters never see other voters' rationales; round 2 gets only refined options and criteria.
- Why: keeps votes independent (D-10).
- Affects: D-10, D-12, D-30

## D-55 — Holdout scenarios add new behavior
- Date / round: 2026-11-20, round 7 (A17)
- Question: Q54
- Decision: holdout scenarios are variations and edge cases not written in the OpenSpec change (other data, boundaries, negative paths). The approval step flags overlap with OpenSpec scenarios. Holdout text is never written into `openspec/`.
- Why: otherwise holdout hides only test code, not behavior.
- Affects: D-36

## D-56 — Isolation: try same-user read-deny sandbox first — fallback part superseded by D-63
- Date / round: 2026-11-20, round 7 (A23, A6)
- Question: Q55
- Decision: the first spike tries workers running as the owner under a Seatbelt profile that denies reads and writes by default (only the step folder, toolchains, caches and its credential file), with provider credentials passed by file or token. A dedicated worker user is kept only if that fails.
- Why: a separate user brings sudoers, kill and clean-up, and login problems.
- Affects: D-26, ADR-005

## D-57 — Provider CLIs run headless
- Date / round: 2026-11-20, round 7
- Question: Q56
- Decision: provider CLIs run as headless child processes of the orchestrator, observed through `factory board tail` and per-step transcripts, not in separate terminal windows.
- Why: the orchestrator can account for, sandbox and kill them.
- Affects: D-04

## D-58 — Runtime profile switches stay within the confirmed plan
- Date / round: 2026-11-20, round 7
- Question: Q57
- Decision: a confirmed plan allows switching to any profile listed for that role in the plan (e.g. on rate limits), never to one outside it.
- Why: the owner already approved every profile shown in the plan.
- Affects: D-28, P7

## D-59 — CLI + web UI; live terminal views; TUI later
- Date / round: 2026-11-20, round 7 (owner's follow-up)
- Question: Q58
- Decision: the CLI is the base (agents, scripts, CI, tests); the web UI is the interactive human surface. `factory board tail` and `run status --watch` use Spectre.Console live rendering for a live view in the terminal. A full TUI (e.g. RazorConsole, built on Spectre.Console) may come later as another client of the same API.
- Why: the CLI is needed regardless; the web suits long findings, diffs, Markdown, links, forms and charts better than a terminal; a third interface now would add maintenance (value 3).
- Affects: D-16, D-31, D-43

## D-60 — Direct provider API use from shells is metered, not blocked
- Date / round: 2026-11-21, round 8 (A13)
- Question: Q59
- Decision: for builder and test-author steps, provider API use by commands their shell runs is metered, charged to the step's budget, flagged on the board and shown on Health — not blocked. Check steps (gate, red, holdout) have no provider hosts at all.
- Why: the exposure is quota, not safety; macOS sandboxing has no per-process network rules to separate the CLI from its shell.
- Affects: D-19, D-26, A13

## D-61 — Isolation fallback is explicit, never silent — `superseded by D-63`
- Date / round: 2026-11-21, round 8 (B2)
- Question: Q60
- Decision: if the spike shows a CLI's required Mach services cannot be narrowed enough, `doctor` marks same-user mode unsupported for that CLI and guides the owner through the one-time dedicated-user setup (admin password for sudoers). The factory never switches isolation modes silently.
- Why: the fallback needs an admin step; a silent change of the safety model violates value 4.
- Affects: D-56, ADR-005

## D-62 — New dependencies are declared in the plan
- Date / round: 2026-11-21, round 8 (A7)
- Question: Q61
- Decision: new direct dependencies (NuGet, npm) must be declared in the item plan. Packages on an allowlist in the constitution pass with the plan; others need the owner's approval with the plan. Restore runs after approval and before building, into an item-local cache. A builder that needs an undeclared dependency mid-build sends the item back to planning.
- Why: adding a package is a supply-chain decision agents should not make alone; the allowlist keeps routine packages friction-free.
- Affects: D-22, D-28, A7, B3

## D-63 — No local macOS users (supersedes D-61)
- Date / round: 2026-11-21, owner's follow-up
- Question: Q63
- Decision: the factory never requires creating local macOS users. Workers run as the owner under the deny-by-default sandbox; there is no dedicated-user fallback. If the spike or `doctor` shows the sandbox cannot hold for a CLI, that provider is `unsupported` and the factory runs with the remaining providers. Another isolation method (e.g. a container or VM) is a v2 option, only if needed.
- Why: the factory must be simple to set up; the worst case is a provider temporarily unavailable, not a worker with extra rights.
- Affects: D-56, D-61, ADR-005

## D-64 — Council deferred to v2
- Date / round: 2026-11-21, round 9 (Gemini G3)
- Question: Q64
- Decision: the council, the judge role and the `deciding` state are out of v1 and deferred to v2 (not dropped). In v1, design options live in the item plan: the planner recommends one, the plan critique (D-51) checks it, and a disagreement goes to the owner's Inbox. ADR rendering of design decisions stays. R3, D-06, D-09, D-12 and D-54 apply from v2.
- Why: the default council (1 judge + 1 voter) adds a call but no majority; D-51 already gives every plan a second opinion. The owner's multi-provider voting idea returns in v2.
- Affects: R3, D-06, D-09, D-12, D-54

## D-65 — Dependencies without the planning loop (closes A7)
- Date / round: 2026-11-21, round 9 (Gemini G9, counter-proposal)
- Question: Q65
- Decision: "approved before restore" stays (allowlist or owner). A builder that needs a package ends its step `blocked: dependency`; the orchestrator adds the reference and regenerates lock files, restores, and re-issues the builder, asking the owner only for non-allowlisted packages. No return to `planning`.
- Why: keeps D-62's supply-chain guarantee and removes all three A7 gaps.
- Affects: D-62

## D-66 — Budgets are caps, not reservations (closes C1)
- Date / round: 2026-11-21, round 9 (Gemini G4, partial)
- Question: Q66
- Decision: no Budget entity and no reservations; no `usd` or `requests` dimensions; no group or question scopes. Caps on steps, wall time, rounds and tokens (measured or estimated) per item and per run, computed from Steps. Gateway traffic is recorded and flagged, not charged.
- Why: gateway connections cannot measure requests; with 2 slots an overshoot is at most one step per slot.
- Affects: D-19, D-28, D-60

## D-67 — Holdout scenarios deferred to v2
- Date / round: 2026-11-21, round 9 (Gemini G1)
- Question: Q67
- Decision: holdout scenarios (D-36, D-55 and that part of D-37) move to v2 together with dark routes. In v1 the test author must write visible boundary and negative-path tests, checked by the spec lens.
- Why: in light mode the owner reviews every PR; holdout pays off mainly once code merges unread.
- Affects: P1, D-36, D-37, D-55

## D-68 — Review: no moderator; verifier only on Important findings
- Date / round: 2026-11-21, round 9 (Gemini G2, partial)
- Question: Q68
- Decision: the checklist is built deterministically from critic-tagged findings (no moderator call). The verifier runs only when a round has `Important` findings.
- Why: the verifier saves tokens by filtering false positives; the moderator was a formatting call.
- Affects: D-13

## D-69 — Autonomy machinery deferred to v2
- Date / round: 2026-11-21, round 9 (Gemini G5 partial, G8)
- Question: Q69
- Decision: dark routes, the circuit breaker and the eval harness (D-03 dark part, D-39, P11 in D-48) move to v2. Finding outcomes stay as telemetry. OpenSpec archive fixtures become unit tests.
- Why: without dark routes every merge is the owner's; the breaker has nothing to tighten.
- Affects: D-03, D-39, D-48, P11, P13

## D-70 — Escalations answered only in the local UI or CLI
- Date / round: 2026-11-21, round 9 (Gemini G6)
- Question: Q70
- Decision: the GitHub mirror of an escalation is a notification only; answers come only through the local UI or CLI.
- Why: removes the comment-answer parser and its anti-spoofing rules; one human approval path is safer.
- Affects: D-20, D-14

## D-71 — Test author uses the builder toolchain; late E2E → escalation
- Date / round: 2026-11-21, round 9 (Gemini G7, G12)
- Question: Q71
- Decision: the test author uses the builder's offline toolchain (no `tester` preset, shim or `/run-tests`). A late "E2E needed" finding becomes an escalation with a follow-up-issue option instead of `reviewing → red`.
- Why: the value-4 test still holds (diff check, discarded copy, independent red check); each removes a special case.
- Affects: D-17, P15, D-52

## D-72 — Repo config stays editable in the UI
- Date / round: 2026-11-21, round 9
- Question: Q72
- Decision: roles (models, effort, counts), budgets and tools remain editable in the web UI; the UI opens a PR to the target repo (D-27 unchanged). Providers and `machine.yaml` are edited in the UI directly.
- Why: the owner explicitly wants role configuration in a UI (R9).
- Affects: R9, D-15, D-16
