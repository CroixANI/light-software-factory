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

## D-73 — Work organization during the build: GitHub tracks, OpenSpec specifies
- Date / round: 2026-11-21, round 10 (owner request, planning the build)
- Question: Q73 — how is the build of the factory split across sequential LLM sessions (Claude Code, Gemini, others), and where do tasks and specifications live?
- Decision (accepted by the owner, 2026-11-21):
  1. **Split of roles.** GitHub holds scheduling and status; OpenSpec holds behavior; `docs/` holds binding design.
     - Milestone = phase (M0…M6 below). Parent issue = one group = one OpenSpec change (D-05, D-21). Sub-issue = one top-level task in `tasks.md`, ordered by native "blocked by" links.
     - Links: the parent issue body says `OpenSpec change: <slug>`; each `tasks.md` task carries `#<issue>`; specs, proposals and issues cite `D-NN`. No status is copied into OpenSpec, no behavior into issues (Q7).
  2. **Milestones.** M0 Spike · M1 Spike review (owner gate) · M2 Foundation (domain, store, board, config, spec adapter) · M3 Station (sandbox, gateway, provider adapters, hostile-worker tests) · M4 Pipeline (GitHub/git, plan, dispatcher, gates, critique, review) · M5 Surface (CLI, API, five screens) · M6 Dogfood (`init`, `doctor`, first real group, calibration of caps). Only the next milestone is specified in detail; later ones stay a list of change slugs until the previous gate passes.
  3. **Session unit.** One sub-issue = one session = one PR (`Closes #n`), in its own worktree. The issue is the session's brief; it names the change, the relevant `D-NN`/architecture sections and the files it may touch. Two sessions run in parallel only if their declared files do not overlap (as D-38).
  4. **Session kinds.** Decision (grill-me → `D-NN proposed`), Spec (`/opsx:explore`, `/opsx:propose`, then parent issue and sub-issues from `tasks.md`), Apply (`/opsx:apply` on one sub-issue), Review (a different provider than the author, D-10 applied by hand), Spike (on the owner's Mac, one provider CLI).
  5. **Handoff.** At the end of a session it leaves one comment on its issue: done, not done, surprises. No progress file in the repository; GitHub is the state.
  6. **Pre-spike rule unchanged.** Until the spike findings are reviewed (M1) only `docs/`, `openspec/` and `spike/` change. OpenSpec changes for pure-domain parts may be written during M0.
  7. **Labels.** `type:spike|spec|impl|docs|decision` and `area:station|core|host|web|process`. No Projects board; milestones and sub-issues are enough.
  8. **One instruction file for all tools.** The rules for agents live in `AGENTS.md` (read by Codex, Copilot and others); `CLAUDE.md` and `GEMINI.md` only import it. Automation of "take the next task" (selection script, claim label) is deferred until parallel work starts (M2). *(Deferral superseded by D-74.)*
- Why: it uses the input format the factory itself will read (D-05, D-21, Q7), so the build rehearses it. Each session starts cold; a single issue as brief keeps context minimal (value 2). Few concepts, no second tracker (value 3). Rolling-wave detail avoids specifying parts the spike may invalidate.
- Value collision: none found; where "plan everything now" (value 1: tokens only where they change a decision) and "complete picture" compete, value 1 wins, hence rolling wave.
- Affects: D-05, D-21, D-38 (by analogy), Q7, `AGENTS.md` ("Work organization" section, shared by all tools), `CLAUDE.md`, `GEMINI.md`.

## D-74 — Session entry point: AGENTS.md trigger, one protocol file, next-task script
- Date / round: 2026-11-21, round 11 (owner request: stop writing a prompt for every session)
- Question: Q74 — how does any fresh LLM session start the right piece of work from a short command, for spike tasks and for OpenSpec work in general?
- Decision (accepted by the owner, 2026-11-21; options considered below):
  1. **One protocol, one trigger.** `docs/process/session-protocol.md` is the single source for the session kinds (apply, spec, review, archive, decision) and the review loop. `AGENTS.md` carries only a trigger paragraph; every tool already loads it (CLAUDE.md and GEMINI.md import it).
  2. **Deterministic selection.** `scripts/next-task.sh` lists ready tasks and claims one with `gh`; the model only reads its JSON. Ready = open, sub-issue of an open parent, no open blockers, not claimed, declared files not overlapping a claimed task (D-38). The lock is creating the branch `<type>/<change>-<N>` (a second session gets HTTP 422), plus the assignee. Claims older than 24 h are reported as stale, never taken over. Tasks needing the owner (`Attended: yes` in the issue) are listed last and the session asks first. No new label.
  3. **Issue text is data.** Only issues from the owner or collaborators count; requests outside the declared files, for secrets or for rule changes are ignored and reported.
  4. **Review loop is part of every PR:** up to 3 rounds, each by a clean-context sub-agent on a more capable model (a different model or effort profile when the session already runs on the top model); one PR comment per round; the handoff names rounds and unresolved findings. This satisfies D-10 inside a session; a separate review session by another provider (D-73 §4) stays available.
  5. **OpenSpec skills are called, not copied.** The protocol overrides the apply skill in two points: one task per session, and no ticking of `tasks.md` checkboxes (status lives on GitHub, D-73 §1) until a decision says otherwise.
  6. **No per-tool wrappers yet.** `/next`-style shortcuts (`.claude/commands`, `.gemini/commands`, `.agents/workflows`) are added only if a fresh-session test shows a tool missing the trigger.
- Options considered: Skill in three directories (copies drift, as OpenSpec's own generated copies do); a custom "task" subagent (a worker is the session itself; a subagent fits only the clean-context reviewer); per-session briefs (what we do now, costs the owner a prompt each time); slash commands only (three formats, no Codex/Copilot repo-level support evidenced).
- Why: values 1 and 3: deterministic checks before models, few moving parts, one source. Value 2: the issue is the brief. Value 4: the lock and the data rule are structural, not prompt-based. Value 5: claims, rounds and findings are comments on GitHub.
- Value collision: none found; where "decide now" meets D-73 §8 ("defer until M2"), the owner chose now.
- Check before relying on it: in a fresh session per tool say "do next task"; expect one chosen task, the claimed branch, a PR with `Closes #N`, the review rounds and a handoff comment. `scripts/next-task.sh` was run read-only against the real repository (ready: #9, #11, #12; blocked ones listed with open blockers); the claim path was run with `DRY_RUN=1` only.
- Affects: D-73 §8 (superseded), D-38, D-10, `AGENTS.md`, `docs/process/session-protocol.md`, `scripts/next-task.sh`, `.github/ISSUE_TEMPLATE/sub-issue.yml`.

## D-75 — proposed: The owner signs in to each provider; `factory auth` runs the native CLI plainly into a factory directory
- Date / round: 2026-11-22, round 12 (decide session; wording agreed with the owner before drafting)
- Question: Q75 — where does a provider credential for the Steps come from, given that the owner's own Claude and Antigravity (`agy`) logins live in the macOS Keychain and the Codex login file is shared with the owner's Codex app?
- Decision (proposed):
  1. **A human signs in, outside any sandbox.** `factory auth <provider>` only starts the provider's own login command as an ordinary process (no Seatbelt), with that CLI's config location pointed at a dedicated factory directory in the machine-local app-data folder, outside the target repo and every worktree. The credential is the file the CLI writes there (mode 0600). The factory stores only its path in the provider registry (§12, D-15, D-35) and never reads the secret into state, config, board or logs.
  2. **A Step gets the credential read-only**: by default a copy of that file in its folder (§5, Step folder step 1); where a CLI can take it from a file descriptor without placing it in the Step (the route used for Claude in the spike), the adapter may deliver the factory file that way. The delivery mechanism per CLI is adapter data. Any refresh that writes, and so may rotate a refresh token, happens outside the sandbox, in `provider probe` (Q2), never inside a Step.
  3. **Recommendation: a separate Google / provider account for the factory**, so that the credential a Step can read (see Why) is not the owner's main account.
- Options considered:
  - (a) *Copy the owner's existing login into the factory.* Impossible for Claude and `agy`: their logins are only in the Keychain, there is no file to copy (claude.md E1/E2; gemini.md part A, "Baseline"). For Codex the file exists, but it is shared with the owner's Codex app, so a refresh outside the owner's own use may rotate the refresh token and log the owner out (codex.md E2; rotation itself was not measured).
  - (b) *Sign in inside the sandbox.* Done only in the spike, to prove it can be done (`agy acp --login` under the profile, gemini.md part A); it needs special handling of the sign-in URL and code under a deny-by-default profile and is not worth keeping as the product path.
  - (c) *Chosen: sign in outside the sandbox into a factory directory.* One simple step for the human, no sandbox exception, no touching of the owner's own login.
- Why: values 3 and 4. The only part of the sign-in that needs a human is the browser step, and it needs no exception in the sandbox. A Step never holds more than a copy; refresh stays where a rotated token can be handled. A separate account bounds the damage because a shell-capable worker can read the copy in its folder (codex.md E2: the access token; gemini.md S1: the whole token file including the refresh token, read by `cat` and `read_file`) and the refresh token outlives the Step.
- Not verified (confirm when the adapters are built; none of it changes the decision, but it can change what `factory auth` runs):
  - that `agy`, signed in outside the sandbox with its config location in the factory directory, writes the token file and not the Keychain. In the spike the file was used only because `security` was denied (`Failed keyring SaveToken, falling back to file`);
  - the same question for Claude: the spike used a long-lived token from `claude setup-token` handed over by file descriptor, not the CLI's own sign-in; where that sign-in stores its credential with a config directory outside the default was not tested. The native command each adapter runs is adapter data.
- Open (not decided here): a read-only copy that sits under the writable `home/` is not immutable. A path-specific write deny stops in-place writes only; a worker can rename the parent directory inside `home/` and write a new file (codex.md Setup, which asks the owner for a mechanism; the same applies to `agy`'s token file). Delivering the credential outside `home/` (for example by file descriptor, §2) avoids it; otherwise it needs a solution in the adapter.
- Open (owner left it open; not decided here): whether a Step copy of the Codex credential carries a dummy refresh token (codex.md E2, part A proposal) so that a Step can never consume the real one.
- Contradictions found, no decision taken (D-33):
  - D-24 says "one account per provider"; a separate factory account is a second account of the same owner for the same work. D-04 says the providers are "logged in with the owner's subscriptions". The owner must confirm that a factory account is inside D-24 and D-04, or amend them.
  - §13 names the command `provider login <name>`; this entry names `factory auth <provider>`. One of the two names must go.
  - For `agy` the refresh happens in memory inside the Step from a read-only copy that holds the refresh token (gemini.md E2). "Refresh outside the sandbox" therefore applies to `provider probe` and to rotating tokens; for `agy` the Step still holds a refresh token.
  - Claude's spike route (claude.md, "Other findings"): the token sat in a 0600 file outside the Step and was handed over by file descriptor, so a worker could not read it. A plain copy in the Step folder, which §5 and ADR-005 describe, would be a step back for Claude: with a shell (`builder`, and `reviewer-readonly` under D-77) a worker could read it. §2 therefore leaves the delivery open per CLI; the owner may prefer to require the descriptor route wherever a CLI offers one.
  - The provider id of the third slot (`gemini` or `agy`) was left open by the owner (gemini.md, "Scope discrepancy" and final verdict (1)). These entries use `agy` only to name the CLI that was tested; they do not decide the id or D-63's provider list.
  - D-26 / value 4 ("no credentials in workers") is stated for Git and GitHub credentials. A readable provider credential in the Step is not new (§5 step 1 already puts it there); this entry does not widen it.
- Affects: architecture §2 (Provider entity: credential file/token location), §5 (Step folder step 1, credential), §12 (provider registry: path only; the factory auth directory), §13 (`provider login`), §19 Q1 and Q2, ADR-004 (`Probe()` refreshes credentials outside any Step), ADR-005 (credential paragraph), D-04, D-15, D-24, D-56, D-63; the spike findings' "needs the owner's decision" items on credentials.

## D-76 — proposed: `com.apple.system.opendirectoryd.libinfo` is in the Mach allowlist for Codex only, together with a mandatory `CODEX_CA_CERTIFICATE`
- Date / round: 2026-11-22, round 12 (decide session; wording agreed with the owner before drafting)
- Question: Q76 — may the Mach allowlist of one provider contain a service the others do not need, and which?
- Decision (proposed):
  1. The Codex adapter's Mach allowlist is exactly `com.apple.system.opendirectoryd.libinfo`. Claude (empty list) and `agy` (`com.apple.trustd.agent` only) do not get it. The allowlist stays per provider (§5), so the rule applies to every process in a Codex Step, including the shell tool's children.
  2. The Codex adapter always sets `CODEX_CA_CERTIFICATE=/private/etc/ssl/cert.pem` (with a read rule for that file). It is mandatory, not an optimisation: without it Codex needs the Keychain daemon (`com.apple.SecurityServer`) for TLS trust, and the Keychain stays excluded (§5).
- Options considered: (a) add `libinfo` for every provider, rejected, because Claude and `agy` do not need it; (b) allow `SecurityServer` instead of supplying the CA bundle, rejected, because it is the Keychain daemon that §5 excludes; (c) mark Codex `unsupported` (D-63), rejected, because the cost below is small.
- Why:
  - **It is required.** With no Mach rule Codex exits at start (`failed to load configuration: Failed to synchronize managed preferences`); `libinfo` alone fixes it (codex.md E3, logs `e3-none`, `e1`). Why `libinfo` is needed (a user-directory lookup during the managed-preferences load) is inferred from the error text, not traced. The CA variable is shown necessary by `e3-noca` and `e3-trust`, which fail without it.
  - **Apple's own profile allows it.** `/System/Library/Sandbox/Profiles/system.sb` lists `com.apple.system.opendirectoryd.libinfo` in its `mach-lookup` allow list for sandboxed processes (checked on the spike Mac, macOS 27.2.1).
  - **Cost.** A worker in a Codex Step can query the user and group directory (spike/harness/sandbox/MACH-SERVICES.md). The owner's assessment is that this does not expose password hashes; that was not measured here. Because of the cost, no other provider gets it.
- Also needed in the Codex profile, not Mach (codex.md E3): a read rule for `/etc/codex/requirements.toml` (the CLI reads this admin policy at start; under the profile an `EPERM` there aborts the start). The `/bin/sh` trampoline message (`Error opening /private/var/select/sh`) is harmless: the command still runs.
- Not verified: whether `libinfo` lets a worker resolve host names (codex.md E4, limits). `cfprefsd.daemon` must stay out: adding it breaks the Codex start (`e3-cfd`, cause not investigated).
- Value collision: none found with D-56, D-63 or ADR-005; `libinfo` is not on the services §5 excludes (launchd job submission, LaunchServices, Apple Events, Keychain/security, pasteboard).
- Follow-up outside this PR: `spike/harness/sandbox/MACH-SERVICES.md` still lists `libinfo` as "candidate, not added, not needed for any worker"; it describes the harness, not a rule, and is not edited by a decision session.
- Affects: architecture §4 (Codex column: env allowlist), §5 (Mach allowlist per provider, env allowlist, read rules), §19 Q1 and Q3, ADR-005 (Mach list), the Codex adapter and its `doctor` check.

## D-77 — proposed: `reviewer-readonly` gets a shell under a no-write profile with a narrow `process-exec` list
- Date / round: 2026-11-22, round 12 (decide session; wording agreed with the owner before drafting)
- Question: Q77 — how does a read-only role read the repo copy when two of the three CLIs cannot do it without a shell? (Closes the earlier "inline manifest" option from the spike proposals; replaces "no shell" in §5 and ADR-005.)
- Decision (proposed): the preset `reviewer-readonly` (planner, critic, finding verifier) runs a shell under the Step profile. Writes stay `io/out` (plus `home/` and `tmp/`); `repo/` stays read-only; the network stays the provider-only gateway. `process-exec` allows, in addition to the CLI's own binaries and bundled helpers, only `zsh`, `cat`, `rg`, `ls`, `head` and `git`: no interpreters (Python, Node, Perl, Ruby, …) and no network utilities (`curl`, `nc`, `ssh`, …). The `builder` preset is unchanged. The `--disable shell_tool` flag proposed for Codex reviewers is not used.
- Options considered: (a) *no shell, inline manifest* (the spike's proposal): the harness puts the files into the prompt, which contradicts D-53 (critics read a full copy on demand) and D-30 (no repository dump); (b) *the builder's shell and toolchain*: far more exec surface than reading needs; (c) *chosen: a shell with a narrow exec list.*
- Why:
  - **Codex cannot read `repo/` without a shell.** It has no file-read tool; without `shell_tool` the remaining tools write (`apply_patch`) or view images only (codex.md E10).
  - **`agy` cannot list or search.** Its declared tools have `read_file`, no directory listing and no content search; it reads only files it is told about (gemini.md E10).
  - **Claude is unaffected in kind** (it has a Read tool; its search tools were not exercised under the no-shell profile, claude.md E10); the shell is for the other two, and one preset serves all.
  - **"No shell" did not protect the credential for `agy`.** `read_file` returned the Step's credential copy in the builder profile (gemini.md S1; the no-shell reviewer profile was not tested separately, final verdict (2)). The argument for "no shell" therefore holds only where a CLI has no read tool.
  - **The write, network and diff-check rules are what hold value 4 for reviewers** (§5: writes only `io/out`, provider-only gateway, no push credentials, discarded copy). A shell with a narrow exec list does not change them.
- Status of the wording: **accepted by the owner conditional on verification** on real Codex and `agy`. The narrow exec list was not run on either: Codex runs its tool as `/bin/zsh -lc '<cmd>'` (codex.md E3), `agy` needs `/bin/zsh` too (gemini.md part A). Verify before relying on it: that both CLIs complete a review read (list, search, read, `git diff`/`git log`) under exactly this list; which real binaries `/usr/bin/git` resolves to (the Xcode shim) and what read and exec rules that adds; that read-only `git status`/`git diff` work with `repo/` not writable (set `GIT_OPTIONAL_LOCKS=0` if index-lock writes fail); that `rg` (not a macOS system binary: there is no `/usr/bin/rg`) is found under the empty environment, i.e. whether it ships with the CLI or needs an explicit path and a read and exec rule; that the `git` helpers (`git --exec-path`, git-core) fall under the list and the rules; whether real review runs also need `tail`, `find`, `wc`, `sed` or `grep` (if so, that is a correction of the list by a new decision, not a silent extension); and a hostile-worker test that `python3`, `curl`, `nc`, `sh` and a write outside `io/out` are refused.
- Contradictions and costs found, no decision taken (D-33):
  - **Interpreters:** `zsh` is itself a scripting language. The list excludes further interpreters, but zsh builtins read any readable file and can write to `io/out`, and `zmodload zsh/net/tcp` (shipped with macOS zsh) opens TCP connections without any network utility; the protection is the profile (only the Step's gateway port is reachable), not the list. "No interpreters" should be read as "no additional ones".
  - **D-60:** D-60 (as amended by D-66) meters and flags shell-originated provider API traffic "for builder and test-author steps" because read-only roles had no shell. With this entry planner, critic and verifier Steps can also generate such traffic from their shell. The gateway already records every host and byte for every Step (§5, D-66); the scope sentence of D-60 should then read "every worker Step with a shell". Not changed here.
  - **Credential for Codex:** Codex has no read tool, so "no shell" did keep its Step credential copy (the ~10-day access token, codex.md E2) from a reviewer; a shell with `cat` removes that. This is the same exposure the builder already has; D-75's separate account is the mitigation.
  - **`agy` needs more for a shell:** its terminal tool needs the PTY device rule, which matches every pseudo-terminal on the machine, including the owner's own terminals (gemini.md part A, "Other findings"), and the loopback-listen rule (already in every shape). A `reviewer-readonly` `agy` Step would newly carry the PTY rule. The owner should decide whether that is acceptable or whether `agy` reviewers stay out of the plan's profile list for read roles.
  - **Values:** value 4 (smaller exec surface) against values 1 and 2 (on-demand reads, no repository dump). This entry takes values 1 and 2 for this preset because the write and network rules, not the missing shell, are what hold the value 4 test for reviewers.
- Affects: architecture §5 (preset table: "no shell" becomes the narrow list; the D-71 paragraph), ADR-005 (`process-exec` line; Consequences: "Builder and test-author shells can reach provider hosts"), D-60 (scope sentence), §19 Q3 ("working without a shell"), D-17 (the "reviewer: read-only" preset), D-53, D-71, §4 (Codex adapter flags), the example `reviewer-readonly` role front matter in §12, the hostile-worker tests.

## D-83 — proposed: `orchestrate` command; one orchestrator protocol file; mode chosen by available tools
- Date / round: 2026-11-22, round 12 (decide session; owner asked for a prompt-free way to start an orchestrating session; options and defaults below were not walked through in an interview, the owner reviews them in this PR)
- Question: Q83 — how does the owner start a session that finds the next tasks and proposes one or several to run in parallel, in any tool (terminal CLIs, Claude app, Antigravity, VS Code, T3 Code, later Orca), without pasting a long prompt each time?
- Decision (proposed):
  1. **One new short command, `orchestrate`.** It extends the D-74 trigger: `AGENTS.md` (loaded by every tool) names it, and the agent reads `docs/process/orchestrator.md`. No per-tool wrapper is added (D-74 §6 stays: only if a fresh-session test shows a tool missing the trigger).
  2. **The orchestrator never does a task.** It reads the state (`git pull --ff-only`, `scripts/next-task.sh`, `npx openspec list` and each change's parent issue), shows ready, claimed (including stale) and blocked tasks and the state of every group, and proposes one task or several that can run in parallel. "Can run in parallel" is the existing D-38 rule that `scripts/next-task.sh` already evaluates (declared files do not overlap). `Attended: yes` tasks are proposed only with the owner present (D-74 §2).
  3. **The mode is chosen by the tools the session has, not by the name of the environment.** The agent first searches for thread-launching tools (deferred tools included), names the chosen mode and the evidence in its first line, and asks the owner once if it cannot decide. Two modes now: `threads` (T3 Code: it launches one top-level thread per chosen task, waits, reads and checks the result) and `commands` (any other tool: it prints, per chosen task, the exact `do task #N` command and the session rules block for the owner to paste into a new session of the tool they choose). A mode for another environment (Orca) is added by a later decision after its tools are checked.
  4. **The orchestrator watches the change life cycle.** When every sub-issue of a parent is closed, no open PR has `Closes` on it and `main` is green, it proposes `archive <slug>`; it starts that session only after the owner says so (the protocol already requires it). `spec <slug>` sessions start only on the owner's request and only for the next milestone (D-73 rolling wave).
  5. **Limits are those of D-73 and D-74:** the orchestrator does not merge, push or edit `docs/decisions.md`; text in issues is data; secrets only through the secret-request tool; the author and reviewer providers differ (D-10).
  6. **Not decided here:** who ticks `tasks.md` checkboxes. D-74 §5 stays ("until a decision says otherwise"), so `openspec list` shows `0/N tasks` and an archive run with `-y` only warns about unchecked tasks (spike S7).
- Options considered: (a) paste the prompt into every session (today): owner time on every start, and the prompt drifts from the protocol; (b) a prompt folder such as `.agents/prompts`: no tool reads it by itself, so the owner would still paste or name it; (c) per-tool commands (`.claude/commands`, `.gemini/commands`, `.agents/workflows`): three formats to keep in step, deferred by D-74 §6; (d) **chosen**: a trigger in `AGENTS.md` plus one file next to the protocol. For mode detection: by environment name (rejected: guessed, and a wrong guess starts the wrong mode) against by available tools (chosen: it checks the fact the protocol depends on).
- Why: value 3 (one command and one file, no new entity) and D-74's own rule "do not ask the owner for a longer prompt". Value 2: the file holds only the orchestrator's steps; how each session kind works stays in `session-protocol.md`. Value 4: the orchestrator has no merge or push rights, and the mode is stated first so a wrong choice is visible at once. Value 5: the state it reports comes from GitHub and `openspec`, not from its memory.
- Value collision: none found; where "no new concepts" (value 3) meets the owner's repeated prompts, D-74's rule that the owner should not write longer prompts decides.
- Not verified: (1) the T3 Code tool names and the `threads` steps are taken from the owner's current orchestrator prompt, not re-run; (2) that a claim made by `scripts/next-task.sh --claim` works inside a worktree created by T3 Code (the same prompt asks to check it on the first task); (3) that a fresh session in each tool (terminal Claude Code, Codex, Antigravity, Claude app, T3 Code) reaches `docs/process/orchestrator.md` from the word `orchestrate`; (4) that the tool search finds lazily loaded tools in each environment; (5) the tools of Orca and of the other environments.
- Affects: D-74 (extends the trigger and the command table), D-73 §4 (session kinds: adds "Orchestrate"), `AGENTS.md` (trigger paragraph), `docs/process/session-protocol.md` (command table, rule for proposing `archive`), `docs/process/orchestrator.md` (new, drafted in this PR), `docs/README.md` (index row). The first three of these files are updated only after the owner accepts.
