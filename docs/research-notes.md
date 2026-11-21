# Research notes (facts)

Facts Claude verified itself. No decisions here. Checked on 2026-11-20.

## dw (source of ideas since D-25)
- dw already provides: an artifact chain spec → plan → diff → PR, gate 1 (plan approval recorded by hash), hash-locked tests,
  a fresh reviewer with triage (fix / disagree / decline), `## Never dismiss` in REVIEW.md, multi-repo items, `/dw:usage`, evals.
- Limitation for the factory: in `-p` / `dontAsk` mode a hook `ask` cannot prompt, so the action does not run
  (dw README, Hooks). The factory therefore needs policy-based gates instead of "ask the human".
- dw talks to GitHub Issues via `gh`; the company stack is Azure DevOps + GitHub Enterprise.

## OpenSpec (candidate for R4)
- A spec-driven development framework for AI assistants, MIT. Cycle: `/opsx:explore` → `/opsx:propose <name>` → `/opsx:apply` → `/opsx:archive`.
- Layout: `openspec/specs/` holds live specs; `openspec/changes/<change>/` holds `proposal.md`, `specs/`, `design.md`, `tasks.md`;
  `openspec/changes/archive/<date>-<change>/` holds completed changes.
- Requirements are Markdown with WHEN/THEN scenarios; deltas are marked, e.g. `## ADDED Requirements`.
- Claims support for 30+ tools (incl. Codex, Copilot, Cursor). Recommends high-reasoning models.
- Source: https://github.com/Fission-AI/openspec
- See the GitHub Spec Kit section for the comparison.

## Subscriptions and non-interactive use (R3, R9, D-04)
- Claude: per the October 7, 2026 update, when signed in with a Claude plan, the Agent SDK and `claude -p` still draw from
  subscription limits; Max, Ultra and Team plans include monthly API credits that cover the API, the Agent SDK and `claude -p`
  when run with an API key from the linked Claude Console organization.
  Source: https://support.claude.com/en/articles/15036540
- Claude Code: preinstalling or running Claude Code in your own products or services (e.g. hosted sandboxes or agent
  infrastructure) requires the Commercial Terms; each end user authenticates with their own credentials.
  Relevant if the factory becomes a product for others. Source: https://code.claude.com/docs/en/legal-and-compliance
- Gemini CLI: signing in with a Google account on Google AI Pro gives 1,500 requests per user per day (Ultra: 2,000);
  Gemini API keys and Vertex AI are billed by tokens. Source: https://geminicli.com/docs/resources/quota-and-pricing
  Google staff answers on the developer forum (about the Antigravity `agy` CLI, not Gemini CLI) say headless runs use the same
  personal quota as interactive ones if the setup is for one person's own work and not shared as a multi-user service, and that
  using several accounts to pool or bypass quota violates the terms. Forum answers, not formal terms — re-check before relying on them.
  Sources: https://discuss.ai.google.dev/t/is-invoking-the-official-antigravity-cli-from-codex-allowed/186952 ,
  https://discuss.ai.google.dev/t/one-person-several-paid-google-ai-pro-accounts-may-a-local-orchestrator-use-them-with-the-official-agy-cli/185460
- OpenAI Codex CLI: included across ChatGPT plans; sign in with a ChatGPT account; usage draws from a shared agentic usage and credit pool
  with limits by plan. Codex supports two sign-ins: ChatGPT (subscription access) or an API key (usage-based).
  Non-interactive mode is `codex exec` (scripts, CI, scheduled jobs; `--json`, schema-structured output, `resume`); by default it reuses the
  credentials the CLI has stored. Sources: https://help.openai.com/en/articles/11369540 , https://developers.openai.com/codex/noninteractive ,
  https://learn.chatgpt.com/codex/auth
- Plan terms changed several times in 2026; re-check before implementation.

## GitHub Spec Kit (candidate for R4)
- Open-source spec-driven development toolkit with a `specify` CLI; works with Copilot, Claude Code, Gemini CLI and others (30 integrations, 90+ community extensions).
- Full path: `/speckit.constitution` → `specify` → `clarify` → `plan` → `checklist` → `tasks` → `analyze` → `implement` → `converge`;
  `clarify`, `checklist` and `analyze` act as quality gates. A `constitution.md` holds the project's governing principles (close to R1).
- Community extensions include GitHub Issues import/sync and an architecture-drift guard.
- Sources: https://github.github.com/spec-kit/ , https://github.github.com/spec-kit/quickstart.html
- Comparison with OpenSpec: OpenSpec centers on change folders with deltas merged into live specs on archive (fits "a group = a change");
  Spec Kit centers on a constitution plus a longer gated pipeline per feature (fits R1 and R3). Both are tool-agnostic.

## Code quality tooling costs (R5)
- SonarQube Cloud Free: private repositories up to 50k lines of code, pull request and main branch analysis, up to 5 users; public code unlimited.
  Paid Team plan starts at $34/month for up to 100k LOC.
  Sources: https://www.sonarsource.com/blog/the-new-sonarqube-free-tier-is-here/ , https://www.sonarsource.com/products/sonarqube/cloud/pricing/
- GitHub code scanning (CodeQL): free on public repositories; on GitHub Free or Pro it works only on public repositories; private repositories
  need GitHub Team or Enterprise with GitHub Code Security. Secret scanning on private repositories needs GitHub Secret Protection.
  Sources: https://docs.github.com/en/code-security/how-tos/scan-code-for-vulnerabilities/troubleshooting/troubleshooting-analysis-errors/cannot-enable-codeql-in-a-private-repository ,
  https://docs.github.com/en/get-started/learning-about-github/about-github-advanced-security
- Free regardless of visibility: ESLint, Prettier, `dotnet format`, Roslyn analyzers, Dependabot version updates, Azurite (local Azure Storage emulator for Blob, Queue, Table).

## CLI libraries (R12)
- **Spectre.Console**: rendering library for .NET console apps — 40+ widgets that adapt to console width (tables, trees, panels,
  multi-task progress, charts), prompts with validation, spinners. Version 0.57, targets .NET Standard 2.0 to .NET 10.
  A separate package, **Spectre.Console.Cli**, is its command-line framework (commands, typed settings, help).
  Source: https://spectreconsole.net/
- **RazorConsole**: builds interactive terminal UIs from Razor components; built on Spectre.Console (its components wrap Spectre.Console
  constructs). Focus on keyboard navigation, focus, buttons, inputs, live updates. No documented argument parsing and nothing on
  piped / non-interactive output. MIT; about 1.7k stars; .NET 8–11. Source: https://github.com/RazorConsole/RazorConsole
- Fit with D-31 (CLI first, `--json`, stable exit codes): the factory's CLI is mostly commands with machine-readable output; the rich
  interactive surface is the web UI (D-16). RazorConsole sits on top of Spectre.Console, so choosing Spectre now does not close the door to a TUI later.
- To confirm during design: Spectre.Console.Testing for output tests; behavior with redirected output (JSON mode should bypass rendering entirely).

## End-to-end test tooling (R13) — candidates, not yet verified in detail
- API level: xUnit + ASP.NET Core `WebApplicationFactory` (in-memory host) with Azurite for Table and Blob storage.
- UI level: Playwright (free, open source); Playwright Test (TypeScript) is the usual choice next to a React app; Playwright for .NET exists too.
- Azurite can run as an npm package or a Docker container; the npm form avoids a Docker dependency.

## Warp Factories — reviewed 2026-11-20 (ideas only)
- Hosted platform for software factories: a factory is `factory.yaml` + agent files in a repo; a coordinating agent (the "foreman")
  routes work to configured workers (Warp agent, Claude Code, Codex, Cursor) through stages; ends with a PR; "merge is always yours".
  Sources: https://www.warp.dev/factories/ , https://docs.warp.dev/factories
- **Blueprint** = stages + transitions + gates, as data. Transitions can skip a stage (no plan needed) or return work for revision;
  if no transition matches, the worker asks for the missing decision instead of silently finishing. A run keeps the Blueprint it started
  with; editing it does not reroute running work (same idea as D-27). Gates guide the workflow but do not enforce permissions —
  branch protection does. Source: https://docs.warp.dev/factories/blueprints/
- **Home / inbox**: "Waiting on you" by default; categories Asked question, Answered question, Spec review, PR review, Blocked, Failed;
  items clear automatically (a PR review clears when the PR is reviewed, merged or closed; a question when answered); "Mark as resolved"
  with Undo; runs grouped Today / This week / All time. Source: https://docs.warp.dev/factories/factory-home/
- **Dashboard metrics**: Autonomy = share of merged PRs that needed no human code push before merge; PR cycle time (median, with
  per-stage medians: kickoff → PR opened → first review → merge); cost per PR (median estimate, split compute / platform / inference),
  drill-down to the most expensive PRs; runs nested under their parent with a timeline. Source: https://docs.warp.dev/factories/factory-dashboard/
- **Measure and improve**: Scorers — an LLM judge classifies completed runs against written criteria (e.g. "ran tests before opening
  the PR"), with a sample rate; check the judge against your own review first. Benchmarks — compare model/runner configs on the same
  fixed tasks. Self-improvement — repeated scorer failures become follow-up PRs to app code or the factory definition, reviewed like
  human PRs. Source: https://docs.warp.dev/factories/measure-and-improve/
- Also: agents attach screenshots or video as evidence before a PR ships; humans can steer or take over a live run.
- Candidate ideas for us (not decided): autonomy and cycle-time metrics on the Cost/Health screens (and as evidence for D-03/D-39);
  Warp's inbox categories and auto-clear rules for our Inbox (D-42); Playwright screenshots/traces attached to the PR (D-45);
  scorers as a light form of P11/P14; "unmatched transition → ask" as a rule of the item state machine.

## afactory (PakhomovAlexander/afactory) — reviewed 2026-11-20
- What it is: `af`, a Rust CLI that runs coding agents as pipelines over a Git repo. `af review` reviews a change; `af task` makes one
  and verifies it. Workers are Claude or Codex agents or plain commands. Apache-2.0, public alpha. Source: https://github.com/PakhomovAlexander/afactory
- Ideas worth taking:
  - **Plan before spend.** `plan` is token-free and shows checks, reviewers, bindings and budgets; `run` executes the exact plan the human confirmed by plan ID.
  - **Deterministic gate first.** The project's own check command (e.g. `make check`) runs before any model reviewer; a check that could not run is not a pass.
  - **Budgets reserved before dispatch.** The tightest limit refuses by name; a limit stops new work, not a call already running; reports show spend per run.
  - **Authority from a commit.** Pipeline config in `.af/` is read only from a commit and pinned by digest, so a run cannot be steered by uncommitted edits — and a team runs the same pipeline.
  - **Sandboxed copies.** Workers work on a copy of the repo; results go to a new branch and worktree; the user's checkout is never written.
  - **Empty environment + allowlist** for every worker process, so shell API keys and variables do not leak in.
  - **Providers = official CLI logins.** A machine-local registry holds IDs and kinds, no credentials; logins happen only at an interactive terminal, never through an agent; a short preflight admits a provider before dispatch.
  - **Minimal worker context** (value #2): each attempt has an input manifest; evaluators see acceptance, the diff and gate results, not the implementer's reasoning.
  - **Incomplete is not clean.** A reviewer that did not answer leaves the round incomplete; findings keep identity across reviewers and rounds.
  - **Agent-drivable CLI.** `--json` everywhere, stable exit codes (0 verified, 3 changes requested, 4 waiting for a person, 5 gate failed, 6 provider failed …), `next_action` in state documents, `doctor` that names the fix.
  - **Implementer and evaluator on distinct models.**
  - **Values in priority order with tests** (1 wise token use, 2 minimal worker context, 3 performance, 4 fast, 5 simple and clear — "removing an entity is preferred to adding a knob", 6 extendable, 7 deterministic, 8 Unix-native).
- Warning signs: the repo has 344 files under `docs/adr` and 457 versioned JSON schema files; its vocabulary (Campaign, Ant, Scenario, Snapshot, Attempt, Ledger …) is large; status is public alpha and releases warn that state from older versions is not read. Supports Claude and Codex only (no Gemini). Strong ideas, heavy implementation — a reason for an explicit simplicity rule in our values.

## dw review: what the factory keeps and what it drops (Claude's analysis, 2026-11-20)
Key fact: dw's enforcement lives in Claude Code hooks (`guard-edit`, `gate-bash`, `gate-mcp`, `subagent-stop`). Gemini CLI and Codex do not run those hooks,
so with mixed providers (R9) hook-based enforcement cannot be the factory's safety layer. dw's own README also lists bypasses of its text-matching shell gates.

| dw part | Factory v1 | Why |
|---|---|---|
| Artifact chain spec → plan → diff → PR | Keep (idea) | Core of traceability |
| Plan approval recorded by hash (gate 1) | Keep as a policy gate | Human or council approves the exact plan |
| Test-first red step | Keep | Proof predates the fix |
| Hash test lock | Replace: protected-path rule on the builder's diff | Simpler, provider-agnostic |
| Fresh reviewer + triage ledger, REVIEW.md `Never dismiss` | Keep, extended by D-13 | Already aligned |
| Repo profile (build / test / lint / format commands, presets) | Keep as the deterministic gate | Same role as afactory's code policy |
| `/dw:usage`, evals | Keep (P11, P12) | Measurement |
| Per-item `/dw:grill` interview | Drop | Grilling moves to group level; per-item questions become council votes or escalations |
| `/dw:start` routing, local items, issue creation (gate 4) | Drop | Input is pre-split issues (R8) |
| `/dw:scope`, `/dw:split`, `/dw:investigate` | Drop from v1 | Upstream of the factory; investigate may return as a role |
| Worktree-or-branch question | Drop | Always an isolated copy |
| Multi-repo items (`bind-repo`) | Drop from v1 | Greenfield, single repo (D-02) |
| Stacked PRs (`gh stack`), `/dw:pr-sweep` | Drop from v1 | One small PR per item; PR comments start a new round later |
| Iterations, `history.md` | Drop | Replaced by the journal |
| Simplifier as an editing agent | Change to a read-only critic lens | Critics stay read-only (D-13) |
| complexity-estimator | Optional telemetry | P12 |
| Text-matching shell gates (`gate-bash`) | Replace | Structural enforcement (sandbox, no credentials, diff checks) |

## Adversarial Code Review (asdlc.io) — R11
- A separate Critic session reviews the Builder's code against the Spec before a human sees it, to break self-validation.
- Builder: throughput-oriented, implements the item. Critics: reasoning-oriented, read-only, never write alternative code.
  Critic lanes run in parallel with lenses such as Architect, SecOps, QA.
- Moderator is required with several critics: deduplicates and prioritizes findings into one checklist; only the moderator synthesizes or writes.
- Context swap: the critic sees only artifacts (spec + diff), not the builder's reasoning.
- Critic checks: spec violations, security, unhandled edge cases, anti-patterns the spec forbids. Each violation comes with
  impact, ordered remediation and test requirements. Critic is told to favor false positives over false negatives.
- Pitfalls: same-session review, weak handling of negative ("DO NOT") constraints — back them with deterministic checks;
  vague specs give vague critiques; large diffs need filtering; miscalibrated critiques need instruction updates.
- The pattern sets no iteration cap; automated builder–critic loops are listed as future work.
- Source: https://asdlc.io/patterns/adversarial-code-review/

## How Anthropic's Claude Code team does code review — R11
- Goal: minimum human review time without more reverts or incidents. The question is "what could go wrong and which check catches it", not "did a human read it".
- Seven layers: pre-PR verification (fresh-context subagent review), AI review on every PR (Quick/Standard/Deep), security review that can block,
  required CI, risk-scaled human approval, merge queue + gradual release behind flags, fast detection and rollback.
- Multi-agent review: parallel bug hunters; a separate group of verifiers votes on each finding, posted only if enough agree;
  style/cleanup findings filtered; findings tagged Important / Nit / Pre-existing; every finding fixed or resolved with a reason.
- Risk tiers set by the change, not the author: low — no human after checks; medium — one; high — two. A second classifier
  asks whether this change needs a human anyway; sensitive paths and CI workflow files always need one.
  Agent approvals never count as human approvals; approvals are tied to a specific commit.
- REVIEW.md per area: what failure looks like, paths to skip, nit cap, file:line evidence, summary starts with a count.
- Incidents and reverts become evals run daily; noise is measured by author response (fixed / wrong / intentional / doesn't matter) and on known-clean PRs.
- Convergence: a round cap — after three rounds the author is asked to reconsider the approach; diff-only re-review after the first passes;
  class-level fixes; no repeated findings; nightly review agents over old code.
- Results reported: pass after one round 65% → 78%; five or more rounds 8.9% → 1.5%; mean reviews to pass 2.08 → 1.32.
- Open gap they name: circuit breakers that tighten approval when reverts or incidents rise.
- Source: https://claude.dev/blog/solving-code-review-at-anthropic/

## messagebus.ai — ideas only, product not used (D-08)
- Hosted service connecting coding agents across machines through an MCP server; a task is sent to a role and an agent holding the role does it.
- Ideas taken: role addressing, budget caps per project and role, audit log, threads, failed-delivery tracking, human approval of steps,
  limits on network access and pushes. Source: https://messagebus.ai/

## Antigravity Swarm (comparison)
- Coordinator (does not write code) + named workers with clean contexts + a shared ordered board (no private messages) +
  a verifier per 2–4 workers, optionally on a different model. Best when work splits into independent pieces.
- Source: https://antigravity.google/docs/swarm/

## Software factories — general sources
- Addy Osmani, Software Factories, Light and Dark: https://addyosmani.com/blog/software-factories/
- StrongDM / Simon Willison (holdout scenarios, digital twins): https://simonwillison.net/2026/Feb/7/software-factory
