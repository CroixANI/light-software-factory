# ADR-007 — GitHub access through the owner's `gh` login, with polling, behind repository settings that `doctor` enforces

- **Status:** Proposed (2026-11-20; revised in revisions 2, 3 and 4 — D-69, D-70 removed answer parsing and the local adapter)
- **Relates to:** D-02, D-05, D-14, D-16, D-20, D-23, D-26, D-37, D-50, D-70

## Context
Only the orchestrator may write to GitHub (D-26). The factory runs locally without a hosted endpoint (D-16), so webhooks cannot reach it. It must:
- read sub-issues and "blocked by" dependencies (D-05);
- open PRs and post notification comments and labels (D-20);
- detect merges and new commits on main (D-37).

D-02 expects a later Azure DevOps / GitHub Enterprise adapter. Pushing a `factory/*` branch runs GitHub Actions on agent-written code before a human sees it (A3).

## Decision
- A `GitHub` adapter interface in `Factory.Core`, with two implementations:
  - **`gh`**: the owner's existing login via `gh api` REST/GraphQL; no token stored by the factory;
  - **read-only**: for the dry run; logs "would write".
- **Polling:** every 60 s while items are `pr_open`, `parked` or `main_gate`, otherwise every 10 min. It reads PR states and new commits on main (merges, Dependabot and other foreign commits, `.factory/**` changes).
- **Repository precondition (D-50):** the workflow token is read-only; "Allow GitHub Actions to create and approve pull requests" is off; `main` is protected; secrets exist only in protected environments that `factory/*` cannot use. This is checked by `doctor`, at `plan` (exit 3) and before every push (the item parks). Assumption: workflows on `factory/*` run read-only and without secrets.
- **Rule-path diffs and new suppressions** are pushed only after a human approval of that diff, bound to its head SHA. `init`'s own config PR is approved in the wizard the same way.
- **Notification-only mirror (D-70):** escalations are posted as an issue comment with a hidden marker plus the `factory:needs-human` label. **Nothing on GitHub is read back as an answer**; answers come only through the owner API.
- **Every write is idempotent:** hidden markers and an existing-PR check before creating a PR.
- Push uses the orchestrator's mirror with the owner's git credentials; only `factory/*` branches are pushed.
- A `.factory/**` change on main drains the run unless it comes from the factory's own closing or retrospective PR (`factory/close-*`, `factory/retro-*`).

## Consequences
- No secrets in config (D-15); one login the owner already has; only the owner API can create a human approval.
- Up to about one minute of latency for merges, which is acceptable at human pace. Answers need the Mac.
- Repos with unsafe Actions settings cannot be used until the owner changes them. This is intentional.
- The GraphQL fields for sub-issues, issue dependencies and the D-50 settings must be verified (not in facts.md).

## Alternatives considered
- **Octokit + fine-grained PAT:** a second credential to store and rotate.
- **Webhooks via a tunnel:** a hosted endpoint, contradicting D-16 and value 4.
- **Answering by comment (revisions 1–3):** needed an anti-spoofing parser; removed by D-70.
