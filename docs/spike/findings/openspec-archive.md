# S7 findings: OpenSpec's own archive on fixture changes

Task 2.5 of `spike-sandbox-and-providers`, experiment S7, question Q8 (architecture §19). Issue #13.
Evidence: [spike/openspec-archive/](../../../spike/openspec-archive/) (53 fixture cases, `run.sh`, one `results/<case>/` folder per case with the CLI output, exit code, before/after trees and a diff of the main specs).
Every statement below cites a case id (`h*` = merges, `e*` = error and edge cases) that you can open under `results/`.

## Setup

- CLI: `@fission-ai/openspec` **1.17.0** from the repo's `node_modules` (`package.json` asks for `^1.2.0`; the lock file installed 1.17.0), Node v24.
- Each case runs in a **copy** of a minimal project (`openspec/config.yaml`, two capabilities `inventory` (4 requirements) and `billing` (1), empty `changes/archive/`) in a temp dir: `openspec archive -y <change>` with stdin from `/dev/null`, `NO_COLOR=1`. The repository's own `openspec/` was never touched.
- After each run `openspec validate --specs --strict` is run on the result (`validate-after.txt`).
- Besides running the CLI, the merge rules were read in the installed package (`dist/core/specs-apply.js`, `parsers/requirement-blocks.js`) to explain the observed results. Things that are only read from the source and not run are marked *(source only)*.
- Version caveat: these semantics are those of 1.17.0. Newer releases added many guards (near-miss detection, idempotent re-apply, retirement), so the adapter must pin a CLI version for its fixture comparison and re-run `run.sh` when bumping it.

## What the CLI does, in order

1. Reads the change folder `openspec/changes/<name>/`. Validates the change's delta specs (`validate` rules: duplicates, cross-section conflicts, RENAMED pairing, scenarios required, unknown `## ... Requirements` headers). A failure prints `Validation errors in change delta specs:` + `Validation failed. Please fix the errors before archiving.` and exits **1** (e06, e07, e11, e13, e17, e19).
2. Checks `tasks.md` (`Task status: ✓ Complete` or `0/1 tasks`). Unchecked tasks only warn when `-y` is given: `Warning: 1 incomplete task(s) found. Continuing due to --yes flag.` and archive continues (h14). Without `-y` it asks interactively *(source only)*.
3. For every capability folder under `changes/<name>/specs/` (alphabetical order in the output: billing, inventory, shipping, h07) builds the **new text of the main spec in memory**. Any error here aborts the whole archive with `Aborted. No files were changed.` and exit 1 (e14: a valid inventory delta is **not** written when the billing delta fails).
4. Validates each rebuilt main spec. A rebuilt spec with errors is not written (h08, e22). Warnings (for example a requirement without SHALL/MUST) do **not** block (e12, e25).
5. Writes the specs, then moves the change folder to `openspec/changes/archive/<YYYY-MM-DD>-<name>/` (h02). The date is the **local** date of the machine (`formatLocalDate`, not UTC). The move is a byte-identical copy of the change folder, including the delta specs and `.openspec.yaml`, and including unchecked tasks (h14). If the target folder already exists (checked early, right after the task status, before any spec is touched): `✖ Error: Archive '<date>-<name>' already exists.`, exit 1, nothing changed (h18).
6. Output ends with `Specs updated successfully.` and `Change '<name>' archived as '<date>-<name>'.` The CLI writes its output, errors included, to stdout (stderr was empty in two error cases checked by hand with separate redirects, e01 and e06; `run.sh` merges the streams, so the results folders cannot show this).

`--skip-specs` (or `skip_specs: true` in the change's `.openspec.yaml`) skips the spec merge (steps 3-4) and only moves the folder (h13, h22). A change with no `specs/` folder at all archives fine with only a warning on the proposal (e23). `--json` prints one JSON object (`archive.change`, `archivedAs`, `path`, `specsUpdated`, `totals{added,modified,removed,renamed}`, `root`) (h19).

## Merge semantics per delta kind

Delta file format: `openspec/changes/<name>/specs/<capability>/spec.md` containing any of the four sections `## ADDED Requirements`, `## MODIFIED Requirements`, `## REMOVED Requirements`, `## RENAMED Requirements` (header match is case-insensitive in the reader *(source only)*; a differently spelled header such as `## ADD Requirements` is an **error**, e19; the same for `## Requirements`, e18). Requirements are `### Requirement: <name>` blocks, scenarios `#### Scenario: <name>`. Names are matched **exactly and case-sensitively** after trimming and removing a closing `###` sequence; case or spacing variants are detected as typos and are errors (e10, e24).

**Apply order in the code is RENAMED, then REMOVED, then MODIFIED, then ADDED** *(source only, `specs-apply.js`)*, whatever the order of sections in the delta file (h06 writes them in the reverse order and still merges as described). All four work on a name-to-block map of the existing spec. What the fixtures can show of the order: the same requirement name cannot appear in two sections (pre-checks reject MODIFIED+REMOVED e26, MODIFIED+ADDED e27, ADDED+REMOVED e07, RENAMED+REMOVED e16, RENAMED TO + ADDED e28, MODIFIED under the old name of a rename e06), so the only observable consequences are: MODIFIED sees the NEW name of a renamed block (h06), and ADDED blocks come last.

| Kind | What it does to the main spec | Case |
|---|---|---|
| **ADDED** | Appends the block verbatim **after the last existing requirement**, in the order the blocks appear in the delta. A target spec that does not exist is created (see "New capability"). | h02, h06, h07 |
| **MODIFIED** | **Replaces the whole block** (requirement text and all scenarios) by the delta's block, at the **same position**. It is not a patch: anything not repeated is gone, and a block with identical text is a no-op. The block is written verbatim (header whitespace of the delta is kept, h15). The delta block must contain every scenario name the current block has; it may add scenarios (h03). | h03, h15, h20 |
| **REMOVED** | Deletes the block. The delta lists the header plus `**Reason**`/`**Migration**` text, which is **not** merged anywhere (the only trace is the archived change folder). A full requirement block is accepted too (e15). Removing from a middle position leaves the others in order. | h04, h09, e15 |
| **RENAMED** | Changes only the header line (`- FROM: \`### Requirement: A\`` then `- TO: \`### Requirement: B\``); body and scenarios stay; the block **keeps its position** (h05, h10: first and last renamed, positions unchanged). | h05, h10 |

Combined (h06): RENAMED `Bravo release` to `Bravo cancellation` + MODIFIED under the **new** name + REMOVED `Charlie` + MODIFIED `Delta` + ADDED `Echo`, `Foxtrot` in one capability and a MODIFIED in a second capability. Result order in the main spec: Alpha, Bravo cancellation, Delta export, Echo, Foxtrot (Charlie gone, new blocks at the end in delta order). Totals line: `Totals: + 2, ~ 3, - 1, → 1`.

Ordering rule for the adapter: **surviving blocks keep their original order; renamed blocks keep their slot; new blocks go at the end.** There is no way for a delta to say "insert after X".

Formatting side effects: the file is rebuilt as `<text before ## Requirements>`, `## Requirements`, blocks joined by exactly one blank line, trailing newline. Runs of blank lines outside code fences are collapsed *(source only)*. A baseline spec that was not already in that shape is therefore reformatted by any non-trivial archive. Anything after the last requirement block (for example a `## Notes` section below the last requirement) belongs to that block's text and is **dropped with it** when the block is removed or replaced; the CLI then warns *(source only, not run)*.

### New capability (target spec does not exist)

- Only ADDED is allowed. MODIFIED or RENAMED: `<cap>: target spec does not exist; only ADDED requirements are allowed for new specs. MODIFIED and RENAMED operations require an existing spec.` (e08).
- REMOVED is ignored with `REMOVED requirement(s) ignored for new spec (nothing to remove).`; if nothing else remains the rebuilt spec has no requirements and the archive aborts with `Spec must have at least one requirement` (e22).
- The new file is `# <cap> Specification`, `## Purpose`, `## Requirements`, blocks. Purpose is the placeholder `TBD - created by archiving change <name>. Update Purpose after archive.` (h01), or the delta's `## Purpose` section if it has one (e21). A delta `## Purpose` for an **existing** spec is ignored with a warning (e20).

### Retiring a capability

Removing the **last** requirement of a spec aborts: `Spec must have at least one requirement` + a hint (h08). With `retire_capabilities: true` in the change's `.openspec.yaml` the spec file is deleted: `Retiring openspec/specs/billing/spec.md: all requirements removed.` (h17).

### Idempotence ("early sync")

OpenSpec has a `sync` flow that merges deltas before archive, so archive tolerates already-applied deltas: ADDED with byte-identical block (after trim and line-ending normalisation), MODIFIED with identical block, RENAMED where FROM is gone and TO exists, and REMOVED of a completely absent requirement are no-ops (`Specs already in sync; no files changed.` h11, h20, h21; REMOVED absent gives a warning, h12). A REMOVED whose name differs from an existing one only in case or spacing is a hard error, not a no-op (e31). Only **differing** content is an error. The factory has no sync step, so the adapter can choose to reject these; but if a human ran `openspec sync` on the branch, the closing PR would hit this case.

## Error cases and exact messages

All exit 1 and print `Aborted. No files were changed.` unless noted. `<cap>` is the capability folder name.

| Situation | Message (prefix) | Case |
|---|---|---|
| MODIFIED header not in spec | `<cap> MODIFIED failed for header "### Requirement: X" - not found` | e01, e24 (case variant is "not found", not a near-miss) |
| MODIFIED drops an existing scenario (also when a scenario is renamed) | `... current spec contains scenario(s) not present in the modified block: "S". The modified block has N scenarios; the current spec has M scenarios. ... Refresh the change spec before archiving to avoid dropping scenarios.` | e03, h16 |
| ADDED name exists, different content | `<cap> ADDED failed for header "### Requirement: X" - already exists` | e02 |
| ADDED name differs only by case/spacing | `... "### Requirement: Alpha reservation" already exists and differs only in case or spacing; use MODIFIED ...` | e10 |
| RENAMED FROM missing (and TO missing) | `<cap> RENAMED failed for header "### Requirement: X" - source not found` | e04 |
| RENAMED TO already exists | `... RENAMED failed for header "### Requirement: <TO>" - target already exists` | e05 |
| MODIFIED uses the old name of a renamed requirement | pre-check: `MODIFIED references old name from RENAMED. Use new header for "<TO>"` | e06 |
| Same name in MODIFIED and REMOVED / MODIFIED and ADDED | pre-check: `Requirement present in both MODIFIED and REMOVED: "X"` / `... MODIFIED and ADDED ...` | e26, e27 |
| RENAMED TO equals an ADDED name | pre-check: `RENAMED TO collides with ADDED for "X"` | e28 |
| Same FROM twice in RENAMED | pre-check: `Duplicate FROM in RENAMED: "X"` | e29 |
| RENAMED FROM differs by case | `RENAMED failed ... - source not found` (no near-miss hint when TO is absent) | e30 |
| REMOVED name differs by case | `REMOVED failed for header "### Requirement: charlie audit log" - not found, but "### Requirement: Charlie audit log" exists; fix the header to match it exactly` | e31 |
| Same name in ADDED and REMOVED | pre-check: `Requirement present in both ADDED and REMOVED: "X"` | e07 |
| Same name in RENAMED(FROM) and REMOVED | pre-check: `Requirement present in both RENAMED and REMOVED: "X"` | e16 |
| Duplicate header inside one section | pre-check: `Duplicate requirement in MODIFIED: "X"` | e11 |
| FROM without TO | pre-check: `RENAMED FROM: "X" has no matching TO: line. ...` (plus two more errors about "no requirement entries parsed" / "no deltas") | e17 |
| Requirement under a non-delta `## ... Requirements` header | pre-check (e19, header `## ADD Requirements`) or, when the file has no delta at all, `<cap> validation failed - requirement "X" (line N) is under "## Requirements", which is not a delta section, so it would not be applied.` (e18) | e18, e19 |
| Delta file with no operation | `Delta parsing found no operations for <cap>. Provide ADDED/MODIFIED/REMOVED/RENAMED sections in change spec.` | e09 |
| MODIFIED/RENAMED on a new capability | see "New capability" | e08 |
| ADDED requirement without a scenario | pre-check: `ADDED "X" must include at least one scenario` | e13 |
| Archive folder exists | `✖ Error: Archive '<date>-<name>' already exists.` | h18 |
| Atomicity | one failing capability stops all; no spec written | e14 |

Not an error, only a later validate warning: a requirement text **without SHALL/MUST** is archived successfully in both ADDED (e12) and MODIFIED (e25); the next `openspec validate --specs --strict` then fails with `should contain SHALL or MUST`. The pre-check that rejects a missing scenario (e13) does exist for ADDED; a MODIFIED block without any scenario was not tried.

## Comparison with the architecture's assumptions

| Assumption (architecture §3, §7, Q8, A20) | Observed |
|---|---|
| "Facts show only `ADDED`", the other kinds are guesses | All four kinds behave as above; MODIFIED-as-full-replace and the strict name conflicts are the things nobody would guess; the apply order itself is only visible through the source. |
| "Delta sections merged into `openspec/specs/`" | True, but MODIFIED is a **full replace** of the block (not a field-level merge) and ADDED always appends at the end. |
| "Change folder moved to `openspec/changes/archive/<date>-<change>/`" | Confirmed. The date is the **local** date `YYYY-MM-DD`; the folder is a byte copy of the change (deltas, `proposal.md`, `tasks.md`, `.openspec.yaml`). |
| Archive is deterministic | Yes for a given CLI version and input, apart from the date. All-or-nothing across capabilities for the spec writes. The folder move happens after the writes; a failure in between is not exercised. |
| (not in the architecture) | Archive also **validates** (change deltas, rebuilt specs) and refuses; creates new capability specs with a placeholder Purpose; can retire a capability via `retire_capabilities`; tolerates already-synced deltas; warns on unchecked tasks only with `-y`. |
| (not in the architecture) | The Purpose of a new capability is a `TBD` placeholder unless the delta carries a `## Purpose`. With the placeholder the archive succeeds but `openspec validate --specs --strict` then **fails** (`results/h01-added-new-capability/validate-after.txt`, exit 1). Every new-capability delta must therefore carry a `## Purpose` (e21 passes), or the closing PR leaves main red under strict validate. |

Consequences for the design, as proposals and not decisions (the factory should never pass `--no-validate`, which the CLI suggests on every validation failure):
- The adapter should reproduce OpenSpec's results exactly rather than "improve" them (the owner can still run `openspec validate` on main). Differences would show up as diffs in the closing PR.
- The factory's own checks should refuse before the closing PR what OpenSpec refuses at archive time (MODIFIED that drops scenarios, MODIFIED of a missing header, rename collisions). A deterministic `spec validate` step in plan critique would turn an archive-time abort (end of the group) into an early error. This is a design suggestion for the owner; no decision is changed here.
- Because the CLI is Node, the adapter has two options: shell out to `openspec archive` (exact semantics, but a Node dependency on the factory's critical path; this conflicts with Q8/A20, which assume re-implementation in the adapter, so it would need its own D- entry) or re-implement in C# against the fixtures below. The fixtures make either testable.

## Cases the spec adapter must reproduce

Use the `results/<id>/` folders as expected output (`specs.diff`, `after/specs/`, `cli-output.txt`). "Result" is `ok` (merge) or `abort` (nothing changed, error).

**Must merge (expected `ok`)**
1. h02 ADDED to existing spec appends at end, multiple in delta order.
2. h01, e21 ADDED to a new capability creates the spec skeleton; Purpose placeholder (h01: result fails strict validate) or delta Purpose (e21: passes).
3. h03 MODIFIED replaces in place; may add scenarios; h15 header whitespace tolerated, block copied verbatim.
4. h04, e15 REMOVED (name form with Reason/Migration, and full block form).
5. h05, h10 RENAMED keeps position, body and scenarios; two renames in one delta.
6. h06 all kinds together, sections out of order in the file, MODIFIED under the new name of a rename, two capabilities.
7. h07 three capabilities, one of them new.
8. h09 ADDED goes after survivors even when the first requirement is REMOVED.
9. h17 retirement with `retire_capabilities: true`.
10. h13, h22 skip specs: no spec writes, folder still moved.
11. h14 unchecked tasks with confirmation skipped: warning, still archives.
12. e20 delta Purpose ignored for existing spec (warning).
13. h11, h20, h21, h12 already-applied deltas (decide: reproduce as no-op or reject).

**Must abort (expected `abort`, no file written)**
14. e01, e24 MODIFIED not found (exact-case match); e30 RENAMED source case variant; e31 REMOVED case variant (hard error).
15. e03, h16 MODIFIED drops or renames a scenario.
16. e02, e10 ADDED collides (exact, and case/space variant).
17. e04, e05 RENAMED source missing, target exists.
18. e06, e07, e16, e26, e27, e28 cross-section conflicts; e29 duplicate FROM; e11 duplicate in a section; e17 unpaired RENAMED.
19. e08 MODIFIED/RENAMED on a new capability; e22 REMOVED-only on a new capability.
20. h08 removing the last requirement without retirement.
21. e09 empty delta; e13 ADDED without scenario; e18, e19 requirement under a non-delta header.
22. e14 atomicity across capabilities.
23. h18 archive folder already exists.

**Judgement calls for the owner/adapter** (CLI accepts, but the factory could choose otherwise): e12/e25 missing SHALL/MUST (archived, later validate fails); e23 change with no deltas and no `skip_specs`.

## Not covered (known gaps)

- CRLF line endings, tabs, `\r` in baselines; fenced code blocks containing `### Requirement:` lines; HTML comments; trailing `###` in headers; unicode names *(source only)*.
- A baseline spec with sections after the last requirement (the "foreign tail" warning).
- A MODIFIED block with no scenarios; very large specs; a crash between writing specs and moving the folder.
- Interactive mode (no `-y`): prompts are not exercised; the factory should always pass `-y` or `--json`.
- Other OpenSpec versions.

## How to reproduce

```bash
npm install                      # repo root, installs the repo-local CLI
spike/openspec-archive/run.sh    # all cases; or: run.sh h06-all-kinds e14-atomicity
git status spike/openspec-archive   # should show no change when the CLI version is unchanged
```
