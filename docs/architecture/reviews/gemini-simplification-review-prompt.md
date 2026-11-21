# Gemini prompt — independent simplification review

**How to run it.** *Gemini app:* pick the strongest reasoning mode it offers (e.g. a "Deep Think" or top "Pro / thinking" model, whatever the current name is), attach the files listed in the prompt from `docs/software-factory/` (if the app caps the number of attachments, attach the "required" ones first and leave out the reviews), then paste the block below. *Gemini CLI:* `cd docs/software-factory`, start `gemini` with the strongest model available to you, and paste the same block; it reads the files from the current folder.
Paste Gemini's whole answer back for triage. The answer is meant to be in English; discuss it in Russian afterwards if you like.

---

```text
# Task: independent simplification review of a software-factory design

You are a senior software architect doing an independent review with ONE goal: find what can be
simplified (removed, merged, deferred to v2, or replaced by something simpler) without breaking
what the owner actually needs. Use your strongest reasoning mode and take your time. Do not
search the web; work only from the files.

## Context (short)
- A local, single-user "software factory" running on the owner's Mac. It takes a GitHub parent
  issue with pre-split sub-issues, plans a run the owner confirms, and drives each item through
  planning, test-first, build, deterministic gate and adversarial review to one PR per item.
  A human merges. v1 stops before deployment and targets the owner's own greenfield repos.
- Built in .NET (CLI + ASP.NET Core minimal API) + React web UI + SQLite.
- Model work runs through provider CLIs (Claude, Codex, Gemini) as sandboxed headless child
  processes under the owner's own subscriptions; only the orchestrator talks to GitHub.
- The design went through three review rounds by another model. Those rounds mostly ADDED
  mechanisms to close safety gaps. This review is the opposite pass: what can go.

## Files to read (in this order)
In the Gemini app these are the attached files; in Gemini CLI read them from the current folder.
1. README.md — one-page summary of v1.
2. values.md — the owner's values in priority order (binding).
3. how-it-works.md — explainer for newcomers; the quickest way to see the whole system.
4. requirements.md — R* (stated by the owner) and P* (proposed, with status) and non-goals.
5. decisions.md — D-01…D-62 with rationale.
6. architecture/architecture.md — revision 3 (entity model, sandbox, state machine, budgets, CLI, UI).
7. architecture/adr/*.md — ADR-001…007.
Optional: glossary.md (vocabulary, if a term is unclear); architecture/review.md,
review-round2.md, review-round3.md and triage.md. The reviews are optional because they argue
for adding mechanisms; read them only to understand WHY a mechanism exists before proposing to
remove it, and do not treat their findings as requirements.

## Ground rules
1. The values in values.md are binding, in this order: (1) verified outcome per token,
   (2) minimal worker context, (3) simple, (4) safe by structure, (5) observable.
   Simplicity is value 3. A simplification may NOT silently weaken safety (value 4). If a
   proposal trades safety for simplicity, say so explicitly and label it a trade-off for the
   owner to decide.
2. Classify every finding:
   (a) simplification that keeps every agreed requirement and decision;
   (b) simplification that requires changing or dropping a specific decision — name each D-NN;
   (c) defer to v2 — name what v1 loses meanwhile.
3. Question the decisions too, not only the architecture. Examples of where to look (these are
   not conclusions, and you must find your own targets): the multi-provider council, holdout
   scenarios, the plan critique, risk tiers, the ratchet, the circuit breaker, the board and
   journal, budgets with six dimensions, the sandbox and isolation design, the item state
   machine, the number of CLI commands and UI screens.
4. Every finding must cite evidence (file + section, or decision id) and estimate its effect:
   what goes away (entities, states, mechanisms, config keys, ADRs, approximate lines of design)
   and the risk it introduces.
5. Prefer a few large, well-argued cuts over many cosmetic ones. Do not propose renames or
   wording edits.
6. No flattery, no rewrite of the documents, no code.

## Minimum viable factory
Also describe the smallest v1 that still delivers the core loop safely for one developer on
greenfield repos:
issue → plan → test-first (red) → build → deterministic gate → adversarial review → PR → human merge.
Say what it keeps, what it drops or defers, and which safety properties it still guarantees.

## Output format (exactly this, in English, Markdown)
First line: `Files read: <list>` — only the files you actually read.
Second line: `Findings: N total — a: x, b: y, c: z; trade-offs that weaken safety: t`
Then:

### 1. Ranked findings
A table, ranked by (size of simplification × confidence), columns:
| ID | Title | Cat (a/b/c) | Removed or merged | Decisions affected | Value impact (1–5, +/−) | Risk | Confidence (H/M/L) |
IDs are G1, G2, …

### 2. Findings in detail
For each G-ID, at most ~8 lines:
- **Evidence:** file § / D-NN.
- **Proposal:** what to remove, merge, defer or replace, and with what.
- **Effect:** what goes away (counts where possible).
- **What breaks if this is wrong:** the concrete failure and how it would be noticed.

### 3. Minimum viable factory (≤ 25 lines)
Components, item states, roles, model calls per item, human touchpoints, safety guarantees kept.

### 4. Keep — do not simplify (≤ 5 items)
Mechanisms you considered cutting but that earn their cost, each with a one-line reason.

### 5. Questions for the owner (≤ 5)
Only questions whose answer would change a finding's category or ranking.
```
