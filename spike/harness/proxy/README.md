# Localhost CONNECT proxy (spike task 1.2)

Throwaway. One process = one Step's gateway on one `127.0.0.1` port (architecture §5 layer 3). Node >= 22, no dependencies.

```bash
node spike/harness/proxy/connect-proxy.mjs --port 8901 --step demo --allow "example.com,*.anthropic.com"
```

- `--port` (default `0` = free port; the chosen port is in the `listening` log line), `--step` (label in the log),
  `--allow` (optional comma list of exact hosts or `*.suffix`; empty = allow all, denied hosts get `403`).
- Only `CONNECT` is supported (HTTPS). Plain HTTP requests get `405`.
- Use it: `HTTPS_PROXY=http://127.0.0.1:8901 curl https://example.com`.
- Log: JSON lines on stdout, events `listening`, `open`, `close` (`bytes_up`, `bytes_down`), `denied`, `refused`, and a
  `summary` (connections per host) on SIGINT/SIGTERM. Never logs payloads, headers or credentials. Redirect stdout to a file to keep it.
- Closing the port = stop the process (E11).
