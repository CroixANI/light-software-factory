# Proposal

## Why

The archived spike `spike-sandbox-and-providers` ended with all three provider CLIs `supported (conditional)` and exit criterion 4 of [docs/spike/plan.md](../../../docs/spike/plan.md) **open**: S1–S5 were not completed with every CLI, and the S2 leak (`KERN_PROCARGS2`) was never re-tested with a real CLI ([findings §8](../../../docs/spike/findings.md#8-exit-criteria-of-the-plan)). The four research notes behind the owner's decisions (isolation, two on credentials, the open-inspect review) also left a list of checks that decide what `docs/architecture/architecture.md` §4/§5 and the proposed D-75, D-76, D-78..D-83 can say as facts rather than guesses ([findings §6, §9](../../../docs/spike/findings.md#9-for-the-owner)). The owner decided to continue the spike inside M0 before any production code.

## What Changes

This change is a list of checks and one write-up; it adds no requirement. Each check ends with a measurement recorded under `docs/spike/findings/` and throwaway material under `spike/followup/`.

- **A. Isolation (fake CLI, then real CLIs driven by a scripted mock model, no provider credential):** the start-of-run probe set and its timing for `doctor`; a `sandbox_init` launcher as a fallback for `sandbox-exec`; the `base.sb` process-info fix (S2) with the real CLIs; the remaining parts of exit criterion 4 (S1 factory state, S3 check-Step ports, S4 protected paths and restore-Step cache write, `dotnet` and offline builds); the in-process `dotnet test` runner probe (D-80 §3 (i)), the loopback-for-check-Steps probe (D-80 §3 (ii), only if (i) fails) and the builder exec-list extension (`cat ls head tail grep sort git`).
- **B. Credentials without any provider sign-in (Attended: no):** which flags and variables exist in the installed CLI versions (codex `app-server`, hygiene flags, claude variables); credential re-read and fd inheritance measured against a mock server with a dummy `CODEX_HOME`; GitHub push-protection coverage of token patterns (documentation reading).
- **C. Credentials with the owner's sign-in (Attended: yes):** `agy` (fresh access token with a dummy refresh token, token file versus Keychain, a standard way to get a fresh token), codex (`app-server` with `ephemeral` credential under Seatbelt, compared with a copy of `auth.json`), claude (E8 with exclusion, S2 with the candidate rule, E11 again). The sign-in is done by the owner into a separate factory directory; secrets are asked only through the secret-request tool and never stored or printed.
- **D. Write-up:** a "follow-up" section appended to `docs/spike/findings.md` (the existing text is not edited) and the input list for future `D-NN` entries. The entries themselves are written by a separate `decide` session.

Where a result decides between options, the result is recorded in the findings and **the choice stays with the owner**. This change decides nothing.

Phase: **pre-spike** (only `docs/`, `openspec/`, `spike/`). No production code.

## Capabilities

### New Capabilities
None. These are measurements, not behavior.

### Modified Capabilities
None. The change sets `skip_specs: true` (`openspec/specs/` is empty; the spike plan states it adds no requirements). Each task carries a "done when" instead of requirement scenarios.

## Impact

- New: `spike/followup/**` (throwaway), `docs/spike/findings/followup-*.md`, and an appended section in `docs/spike/findings.md` (task 4.1 only).
- Not changed: `docs/decisions.md`, `docs/architecture/**`, `docs/spike/plan.md`, `spike/harness/**` and every earlier `spike/<cli>/` directory. A profile that needs a change is copied into the task's own directory as a candidate.
- Binding decisions touched as inputs only: D-56, D-57, D-63; the proposed D-75, D-76, D-77, D-78, D-79, D-80, D-81, D-82, D-83 (status per the owner: D-75, D-76, D-78, D-79, D-82 accepted, with D-82's adapter calling a pinned `openspec archive`; D-83 accepted; D-81 "the worker writes `result.json`" accepted; D-80 §3 order: in-process runner first, then loopback for the check Step only with serialization; builder exec list extended by `cat ls head tail grep sort git`).
- Values: 4 (safe by structure) drives every check; value 1 caps spend, so model calls are tiny fixed prompts and most tool-shell checks use a scripted mock model with no quota. Value collision: none found.
- Risk to the owner's machine: attended tasks use a dedicated factory directory and a separate account where possible; no check enumerates, reads or writes the owner's Keychain.

## GitHub Group

Change slug: `spike-followups-sandbox-auth`. The Parent Issue body must contain `OpenSpec change: spike-followups-sandbox-auth`; milestone M0 Spike. Issues and "blocked by" links are created only after the owner approves these artifacts.
