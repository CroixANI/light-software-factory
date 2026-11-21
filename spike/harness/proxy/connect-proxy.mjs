#!/usr/bin/env node
// Throwaway spike tool (task 1.2): minimal localhost HTTP CONNECT proxy, one port per Step.
// Logs one JSON line per event: host, port, connection number, bytes. Never payloads, headers or credentials.
import http from "node:http";
import net from "node:net";
import { parseArgs } from "node:util";

const { values } = parseArgs({
  options: {
    port: { type: "string", default: "0" },   // 0 = pick a free port
    step: { type: "string", default: "step" }, // label only, goes into the log
    allow: { type: "string", default: "" },   // comma list: exact host or "*.suffix"; empty = allow all
  },
});
const allow = values.allow.split(",").map((s) => s.trim().toLowerCase()).filter(Boolean);
const permitted = (h) =>
  allow.length === 0 ||
  allow.some((a) => (a.startsWith("*.") ? h.endsWith(a.slice(1)) : h === a));

const log = (o) => console.log(JSON.stringify({ t: new Date().toISOString(), step: values.step, ...o }));
let n = 0;
const perHost = new Map();

const server = http.createServer((req, res) => {
  // Only CONNECT is supported; plain HTTP requests are refused (the CLIs use HTTPS).
  log({ ev: "refused", reason: "not-connect" });
  res.writeHead(405, { Allow: "CONNECT" }).end();
});

server.on("connect", (req, client, head) => {
  const id = ++n;
  const m = /^(\[[^\]]+\]|[^:]+):(\d+)$/.exec(req.url || "");
  const okPort = m && Number(m[2]) >= 1 && Number(m[2]) <= 65535;
  if (!okPort) { client.end("HTTP/1.1 400 Bad Request\r\n\r\n"); log({ ev: "refused", id, reason: "bad-target" }); return; }
  const host = m[1].replace(/^\[|\]$/g, "").toLowerCase();
  const port = Number(m[2]);
  if (!permitted(host)) {
    client.end("HTTP/1.1 403 Forbidden\r\n\r\n");
    log({ ev: "denied", id, host, port });
    return;
  }
  perHost.set(host, (perHost.get(host) || 0) + 1);
  let up = head.length, down = 0, done = false, established = false;
  const upstream = net.connect(port, host, () => {
    established = true;
    client.write("HTTP/1.1 200 Connection Established\r\n\r\n");
    if (head.length) upstream.write(head);
    client.on("data", (d) => (up += d.length));
    upstream.pipe(client); client.pipe(upstream);
    log({ ev: "open", id, host, port, connections_to_host: perHost.get(host) });
  });
  upstream.on("data", (d) => (down += d.length));
  const close = (reason, graceful = false) => {
    if (done) return; done = true;
    if (graceful) client.end(); else client.destroy(); // end() flushes a pending 502 before closing
    upstream.destroy();
    log({ ev: "close", id, host, port, bytes_up: up, bytes_down: down, reason });
  };
  upstream.on("error", (e) => { 
    const pre = !done && !established;
    if (pre) client.write("HTTP/1.1 502 Bad Gateway\r\n\r\n");
    close(e.code || "error", pre);
  });
  client.on("error", (e) => close(e.code || "error"));
  upstream.on("close", () => close("upstream-closed"));
  client.on("close", () => close("client-closed"));
});

server.listen(Number(values.port), "127.0.0.1", () => {
  log({ ev: "listening", port: server.address().port, allow: allow.length ? allow : "all" });
});
const bye = () => {
  log({ ev: "summary", connections: n, per_host: Object.fromEntries(perHost) });
  process.exit(0);
};
process.on("SIGINT", bye); process.on("SIGTERM", bye);
