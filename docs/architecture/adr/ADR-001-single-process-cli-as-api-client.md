# ADR-001 — One orchestrator process; the CLI and the web UI are clients of its API

- **Status:** Proposed (2026-11-20; revised in revision 2 for A25 and D-59; revision 3 for B6; revision 4 for D-70, D-72)
- **Relates to:** D-04, D-16, D-31, D-34, D-43, D-59, D-70, D-72

## Context
D-04 asks for a long-running local process. D-31 asks for a CLI with `--json`, exit codes and `next_action`, and says the web UI is a client of the same API. D-34 asks for one .NET process covering CLI, API and UI. D-59 makes the CLI the base surface (agents, scripts, CI, tests) and the web UI the interactive human surface. Without a single owner of the state, the dispatcher, the CLI and the UI could each write to SQLite, and the kill switch, cap checks and slot counting would race. The owner API is the **only** way a human approval can enter the system (D-70), so it must not be callable from other web pages (A25).

## Decision
- One executable, `factory`. `factory serve` hosts the dispatcher, the ASP.NET Core minimal API on `127.0.0.1`, the embedded React build, and the per-Step **worker gateway** ports (ADR-005).
- Every other command is a thin HTTP client of the API, authenticated by an owner token in the app-data folder (mode 0600). If the server is not running, the command exits 3 with `next_action: factory serve`.
- Exceptions that work without the server: `doctor` and `config validate`.
- Only the serve process writes to SQLite.
- **Live terminal views** (`board tail`, `run status --watch`) are Spectre.Console live renderings of the same SSE stream the UI uses. With `--json` they emit NDJSON instead. A full TUI (e.g. RazorConsole) would be one more API client and is not in v1 (D-59).
- **Browser hardening:**
  - The session cookie is `HttpOnly; SameSite=Strict`.
  - Writes require the `X-Factory-Request: 1` header and a matching `Origin`.
  - `Host` must be `127.0.0.1:<port>` or `localhost:<port>`.
  - Agent-written text is rendered as sanitised Markdown with no raw HTML.

## Consequences
- One writer: cap checks, transitions and the kill switch are serialised in one place, with no cross-process locking.
- The CLI and UI share the same contract tests (`WebApplicationFactory`, incl. CSRF/Origin tests), so they cannot drift apart. The UI has no capability the CLI lacks: every UI write has a command (`config propose`, `machine set`, `inbox answer`, `run …`, `kill`; B6, D-72).
- The owner has to start `serve` once per session. A launchd agent could do this later; it is not part of v1.
- Workers cannot use the API: they cannot read the token, and Seatbelt only lets each Step reach its own gateway port. Other local web pages cannot forge approvals.

## Alternatives considered
- **CLI opens SQLite directly, plus a separate daemon:** two writers, needs locking, and kill/stop semantics get harder.
- **Auto-starting a background daemon from any command:** hidden processes; it can come later without changing the API.
- **Interactive TUI as the main human surface:** the web UI already covers it (D-16, D-42); a TUI can be added as a client later (D-59).
