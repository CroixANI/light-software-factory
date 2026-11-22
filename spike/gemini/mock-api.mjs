// Spike 3.6 throwaway: a fake model endpoint on one localhost port for agy's "enterprise model gateway" route
// (AGY_LLM_GATEWAY_URL=http://127.0.0.1:<port>, AGY_LLM_GATEWAY_API_KEY=<fake>, AGY_LLM_GATEWAY_MODELS=<model>). No Google login, no quota.
// Usage: node mock-api.mjs <port> <scenario.json | status:<http code>>
//   status:<n>  every request gets HTTP <n> with a Google-style JSON error body (E12).
//   scenario.json = array of turns, one per model request, in order; after the last turn every request gets a plain text "mock-done":
//     {"text":"..."} | {"call":{"name":"run_command","args":{...}}} | {"calls":[{name,args},...]} | {"status":429} | {"truncated":true} (SSE that stops without a finish reason)
//     {"hang":true} (the request is never answered; E12 timeout)
//     optional "usage":{"promptTokenCount":..,"candidatesTokenCount":..,"cachedContentTokenCount":..,"thoughtsTokenCount":..}
// Env MOCK_DUMP=<dir>: request body n is written to <dir>/req-<n>.bin (mode 0600). The dir is a private scratch dir outside the repository: bodies hold the prompt and any file the worker read.
// Logs one JSON line per request on stdout: n, method, path (no query), alt, body bytes, reply kind. Never bodies or headers.
import http from 'node:http';
import fs from 'node:fs';
const port = Number(process.argv[2]); const spec = process.argv[3] || 'status:500';
const turns = spec.startsWith('status:') ? null : JSON.parse(fs.readFileSync(spec, 'utf8'));
const fixedStatus = spec.startsWith('status:') ? Number(spec.slice(7)) : null;
let n = 0;
const errBody = (s) => ({ error: { code: s, message: `mock ${s}`, status: { 429: 'RESOURCE_EXHAUSTED', 503: 'UNAVAILABLE', 401: 'UNAUTHENTICATED', 400: 'INVALID_ARGUMENT', 403: 'PERMISSION_DENIED' }[s] || 'INTERNAL' } });
http.createServer((req, res) => {
  const chunks = []; req.on('data', (c) => chunks.push(c));
  req.on('end', () => {
    n++; const body = Buffer.concat(chunks);
    if (process.env.MOCK_DUMP) fs.writeFileSync(`${process.env.MOCK_DUMP}/req-${n}.bin`, body, { mode: 0o600 });
    const u = new URL(req.url, 'http://x'); const sse = u.searchParams.get('alt') === 'sse';
    let t = fixedStatus ? { status: fixedStatus } : (turns[n - 1] || { text: 'mock-done' });
    if (t.hang) { console.log(JSON.stringify({ n, method: req.method, url: u.pathname, bytes: body.length, reply: 'hang' })); return; }
    const kind = t.status ? `status:${t.status}` : t.truncated ? 'truncated' : t.call || t.calls ? 'call' : 'text';
    console.log(JSON.stringify({ n, method: req.method, url: u.pathname, alt: u.searchParams.get('alt'), bytes: body.length, reply: kind }));
    if (t.status) { res.writeHead(t.status, { 'content-type': 'application/json' }); return res.end(JSON.stringify(errBody(t.status))); }
    const parts = t.truncated ? [{ text: 'partial answer ' }]
      : t.calls ? t.calls.map((c) => ({ functionCall: c })) : t.call ? [{ functionCall: t.call }] : [{ text: t.text }];
    const chunk = { candidates: [{ content: { role: 'model', parts }, ...(t.truncated ? {} : { finishReason: 'STOP' }), index: 0 }],
      ...(t.truncated ? {} : { usageMetadata: { promptTokenCount: 11, candidatesTokenCount: 3, totalTokenCount: 14, ...(t.usage || {}) } }) };
    if (sse) { res.writeHead(200, { 'content-type': 'text/event-stream' }); res.write('data: ' + JSON.stringify(chunk) + '\r\n\r\n'); return res.end(); }
    res.writeHead(200, { 'content-type': 'application/json' }); res.end(JSON.stringify([chunk]));
  });
}).on('connect', (req, sock) => {   // E11 only: answers a proxy CONNECT with 200 so a surviving worker's probe can tell "gateway open" from "gateway closed" (the mock doubles as the Step gateway port)
  console.log(JSON.stringify({ ev: 'connect', target: req.url })); sock.on('error', () => {});
  sock.write('HTTP/1.1 200 Connection Established\r\n\r\n'); setTimeout(() => sock.destroy(), 3000);
}).listen(port, '127.0.0.1', () => console.log(JSON.stringify({ listening: port, spec })));
