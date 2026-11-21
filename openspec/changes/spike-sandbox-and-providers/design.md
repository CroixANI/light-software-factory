# Design

## Context

Scope, experiments and pass criteria are defined in [docs/spike/plan.md](../../../docs/spike/plan.md); this document only fixes how the work is cut into sessions and how evidence is kept. Binding references: D-24, D-56, D-57, D-63, [ADR-004](../../../docs/architecture/adr/ADR-004-provider-adapter-file-based-typed-io.md), [ADR-005](../../../docs/architecture/adr/ADR-005-station-isolation-on-macos.md), architecture [§4](../../../docs/architecture/architecture.md#4-provider-adapter-contract), [§5](../../../docs/architecture/architecture.md#5-station-and-sandbox), §19.

## Goals / Non-Goals

**Goals:**
- Every CLI ends with a verdict and evidence that a later session can re-run (exact command line, flags, env, profile, logs).
- Work is cut into one-session tasks that can run in parallel across providers once the shared harness exists.

**Non-Goals:**
- Orchestrator code, board, UI, GitHub integration; any fallback isolation mode (D-63).
- Polished or reusable code. `spike/` is a reference for `Factory.Station`, not its seed.

## Decisions

1. **Harness first, then providers in parallel.** Group 1 builds the harness and fake CLI; group 2 proves the sandbox without any provider; only then group 3 runs the three CLIs. Rationale: a CLI failing inside a broken profile says nothing about the CLI. Alternative (start with a real CLI) rejected: it burns subscription quota on harness bugs (value 1).
2. **Two sessions per provider.** Part A: E1–E5 (credential, refresh, Mach allowlist, proxy, own sandbox off). Part B: E6–E12 and a re-run of S1–S5 with that CLI. B is blocked by A because it needs a working profile. Alternative (one session per CLI) rejected: twelve experiments exceed one session's useful context.
3. **Findings per file to avoid merge conflicts.** Each task writes only its own `docs/spike/findings/<name>.md` and its own `spike/<name>/`; the consolidation task alone writes `docs/spike/findings.md`. Declared files are therefore disjoint across parallel sessions (D-73, as D-38).
4. **Evidence hygiene (public repo).** `spike/` ignores `work/`, credential copies and raw logs; committed logs are excerpts with hosts, token counts and denials only. No home-directory paths: use `<step>/…` placeholders.
5. **Owner presence.** E1/E2 need the owner's own provider login on the owner's Mac. Those sessions start interactively; the agent never types or stores a password (credential handling stays with the owner).
6. **OpenSpec archive reference (S7)** runs independently of the sandbox work, since it only needs the OpenSpec CLI already in `package.json`.

## Risks / Trade-offs

- Subscription quota consumed by experiments → fixed tiny prompts, one run per cell, record usage (E7).
- `sandbox-exec` deprecated or changed by a macOS update → record the macOS version and S6 result; re-run hostile tests on each update (Q3).
- Evidence leaks secrets into git → decision 4 plus a PR checklist item; review diffs of `spike/` before pushing.
- All three CLIs end `unsupported` → exit criterion 2 of the plan: stop and escalate to the owner before any v1 code.
