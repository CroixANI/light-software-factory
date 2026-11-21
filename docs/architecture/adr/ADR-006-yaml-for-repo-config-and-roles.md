# ADR-006 — YAML for repo configuration; roles as Markdown with YAML front matter

- **Status:** Proposed (2026-11-20; revision 4 for D-72)
- **Relates to:** D-15, D-18, D-27, D-72, value 3

## Context
The per-repo factory config (D-15) and one file per role (D-18) need a format. The brief asks for YAML or TOML, with the reason recorded. Role files combine data (purpose, profiles, switches) with long instructions.

## Decision
- `.factory/factory.yaml` and `machine.yaml` use **YAML 1.2**, validated against a published **JSON Schema** (`config validate`, the UI, and editor support).
- Each role is **one Markdown file**: YAML front matter for data, body for instructions. One file per role satisfies D-18 literally and keeps instructions readable in PRs.
- Strings with special meaning (durations, globs, profile ids) are typed by the schema; implicit typing (e.g. `no` → false) is rejected by validation.
- The UI's Config screen and `config propose` write a canonical file and open a PR (D-27, D-72); `machine.yaml` is edited directly. Comments in `factory.yaml` are not preserved by UI edits; explanations belong in the schema descriptions and role Markdown.

## Consequences
- Same format as the other files the factory touches (GitHub workflows, Dependabot, OpenSpec/Markdown front matter), and familiar to agents and humans.
- Lists of tables (gate checks, profiles) are compact.
- UI saves drop comments; this shows up in the PR diff, so it is visible, not silent.

## Alternatives considered
- **TOML:** less ambiguous, and Tomlyn can keep comments when editing. But arrays of tables (gate checks, lenses, profiles) are clumsy, and front matter in role Markdown would mix two formats.
- **JSON:** no comments, poor for hand edits.
