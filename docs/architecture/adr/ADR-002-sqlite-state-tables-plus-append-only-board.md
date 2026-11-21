# ADR-002 — SQLite current-state tables plus an append-only board, written in one transaction

- **Status:** Proposed (2026-11-20; revised in revision 2 for A18; revision 4 for D-66)
- **Relates to:** D-11, D-29, D-34, D-35, D-48 (P5), values 3 and 5

## Context
The board must be append-only (D-11) and must let a person trace an item from start to end (value 5). Items must survive a crash and resume (P5). Two common shapes: full event sourcing (the board is the only truth; state is rebuilt by replay), or mutable state tables with a separate audit log. Event sourcing needs replay code, snapshots and versioned events. A separate audit log can drift from the state.

## Decision
- One SQLite database (WAL) in the app-data folder.
- One **current-state table per entity** (`runs, groups, items, steps, questions, findings`; caps are computed from `steps`, D-66): the read model the dispatcher and the UI use.
- One **`board`** table, append-only, with SQLite triggers that reject `UPDATE`/`DELETE`. Nothing on a board row ever changes. Status that evolves, such as delivery, is written as new entries (`task.addressed` → `task.delivered` / `task.failed`), never as a mutable column.
- **One write path**, `Board.Append(entry, change)`: the board entry and the state change are committed in the same transaction. There is no other way to change a state table.
- The journal is the board's `measurement` entries plus a SQL view (no extra table). "Not measured" is `value = null` with `status` and `reason`.

## Consequences
- Board and state cannot disagree; resume reads the tables, the UI timelines read the board.
- No replay engine. State tables are authoritative; the board is complete enough to *audit* and to debug, and could rebuild state later if ever needed.
- The schema has 7 tables, one per persisted entity plus the board, which keeps the one-page entity model honest.
- SQLite writes are serialised (ADR-001 has one writer anyway). Throughput is far above what 2–N slots produce.

## Alternatives considered
- **Full event sourcing:** cleaner in theory, but replay/snapshot/versioning code with no v1 benefit (value 3).
- **State tables + log file (JSONL):** two stores that can drift; no transactional link.
- **Journal as its own table:** one more entity; a view over measurement entries is enough.
- **A mutable `delivery` column with a trigger exception:** it breaks the append-only rule for one field; extra entries cost nothing.
