# Proposal

## Why

Architecture v1 rests on one unproven assumption: each provider CLI (`claude -p`, `codex exec`, Gemini CLI) can run as a headless worker, as the owner's user, inside a true `(deny default)` Seatbelt profile with a Keychain-free read-only credential, behind a per-Step gateway, with its own sandbox off (D-56, D-57, D-63, ADR-004, ADR-005). Open questions Q1–Q5 and Q8 ([architecture §19](../../../docs/architecture/architecture.md#19-open-questions-and-risks-top-10-each-with-a-proposed-default)) cannot be settled by reading; they need experiments. No v1 code may be written before the findings are reviewed (CLAUDE.md, spike plan).

## What Changes

This change carries out [docs/spike/plan.md](../../../docs/spike/plan.md); it adds no requirements.

- A shared throwaway harness in `spike/harness/`: step-folder builder, sample repo with planted instruction files, CONNECT logging proxy, Seatbelt starting profile, empty-environment launcher, fake CLI per role shape.
- Provider-independent sandbox experiments S1–S7 with the fake CLI.
- Per provider CLI (claude, codex, gemini): experiments E1–E12 and a verdict `supported` / `unsupported` with evidence (D-63: no third outcome).
- Findings in `docs/spike/findings/` (one file per provider and one per sandbox experiment group), consolidated into `docs/spike/findings.md`.
- A PR proposing updates to architecture §4, §5, §19 and any new `D-NN proposed` entries, for the owner's review (milestone M1).

Phase: **pre-spike** (only `docs/`, `openspec/`, `spike/`). No production code.

## Capabilities

### New Capabilities
None. A spike measures feasibility; it does not define behavior.

### Modified Capabilities
None. The change sets `skip_specs: true` (no spec-level behavior changes; `openspec/specs/` is empty and the plan states it adds no requirements).

## Impact

- New: `spike/**` (throwaway), `docs/spike/findings.md`, `docs/spike/findings/*.md`.
- Later, by owner-reviewed PR only: architecture §4, §5, §19 and `docs/decisions.md`.
- Runs on the owner's Mac with the owner's own provider logins (D-24). Spike code and logs must contain no credentials, tokens or local paths (public repository).
- Values: 4 (safe by structure) drives the work; value 1 caps spend, so spike prompts are tiny fixed prompts. Value collision: none found.

## GitHub Group

Change slug: `spike-sandbox-and-providers`. The Parent Issue body must contain `OpenSpec change: spike-sandbox-and-providers`; milestone M0 Spike.
