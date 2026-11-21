# Working rules for coding agents

This repository holds the design (and, later, the code) of a local software factory. Read these rules before any change.

## Before you start
- Read [docs/values.md](docs/values.md) first. The values are in priority order and decide every trade-off (D-33).
- Then read [docs/how-it-works.md](docs/how-it-works.md) and the parts of
  [docs/architecture/architecture.md](docs/architecture/architecture.md) your task touches.

## Binding rules
- Decisions in [docs/decisions.md](docs/decisions.md) are binding. Only the owner changes them.
- All documentation, code comments and commit messages are in English (D-07).
- The entity model must fit on one page (architecture §2, D-33). A new concept replaces or merges with an existing one
  before it is added.
- **No production code before the spike findings are reviewed.** Until then, only `docs/` and throwaway work in `spike/`
  (see [docs/spike/plan.md](docs/spike/plan.md)).
- Keep Mermaid diagrams valid and relative links working when you move or rename files.

## Proposing a design change
- Never change a decision, requirement or architecture rule silently.
- Add a new entry at the end of `docs/decisions.md` (next free `D-` number, title marked "proposed") in the existing format:
  question, decision you recommend (with the options considered), why, and what it affects. The owner accepts or rejects it.
- Only after acceptance, update the affected documents and cite the decision id. Superseded entries stay, marked as superseded.
- If two values collide, name the collision in one line in the decision or PR (D-33).

## OpenSpec & GitHub Issues
- OpenSpec is installed repo-locally (`npm install`, then `npx openspec` / `npm run openspec`) and configured in [openspec/config.yaml](openspec/config.yaml) for Claude Code, Gemini CLI, Antigravity, and Codex.
- Follow D-05, D-21, and architecture Q7: one OpenSpec change = one GitHub Parent Issue (`OpenSpec change: <change-name>` in the body); atomic items in `tasks.md` map 1:1 to GitHub Sub-Issues ordered by native `blocked by` dependencies and stamped with `#<issue>`.

## Hygiene
- No local paths, credentials, tokens or private material in the repository; the repository is public.
- Local factory state never goes into the repository.
