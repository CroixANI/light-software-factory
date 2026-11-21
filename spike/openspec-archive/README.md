# S7: OpenSpec archive fixtures (throwaway spike, issue #13)

Reference for the future spec adapter's unit fixtures (architecture §3, §7, Q8). Findings: [docs/spike/findings/openspec-archive.md](../../docs/spike/findings/openspec-archive.md).

- `base/openspec/`: the starting project structure (two capabilities, `inventory` with four requirements and `billing` with one).
- `cases/<id>/changes/<id>/`: one fixture change per case (`proposal.md`, `tasks.md`, `.openspec.yaml`, `specs/<capability>/spec.md` deltas).
  `cases/<id>/case.md` says what the case tests, `flags` holds the CLI flags, optional `pre/` is overlaid on the project before the run (`@DATE@` in a path is replaced by today's date).
  `h*` = expected to merge, `e*` = error and edge cases.
- `results/<id>/`: what the CLI did. `cli-output.txt` (stdout+stderr merged; the CLI writes everything to stdout), `exit-code.txt`, `before-tree.txt`, `after-tree.txt`, `specs.diff` (main specs before vs after),
  `after/specs/` (main specs after), `after/archived-change/` (the moved change folder; in h18, where archive fails, it is the pre-created fixture folder), `validate-after.txt` (`openspec validate --specs --strict` on the result).
- `run.sh`: reruns every case (or the ids given) in a copy under a temp dir, with the repo-local CLI (`node_modules/.bin/openspec`, version in the findings). It never touches the repository's own `openspec/`. Dates and temp paths in the results are normalised to `<DATE>` / `<project>`.
- `gen-cases.py`: regenerates `cases/` (`python3 -I gen-cases.py .` from this folder). The `cases/` files are the source of truth; the script is kept only to make the fixture set easy to extend.
