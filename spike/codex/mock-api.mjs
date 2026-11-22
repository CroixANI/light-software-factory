// Spike 3.4 E12 throwaway: a fake Responses API on one localhost port that answers every request with a fixed error, to force failure classes.
// Usage: node mock-api.mjs <port> <status> [kind]   kind: usage (ChatGPT-style usage_limit_reached 429 body), rate (rate_limit_exceeded), sse-fail (HTTP 200 + a `response.failed` event), sse-bad (HTTP 200 + a stream that stops without response.completed), plain
import http from 'node:http';
const [port, status, kind = 'plain'] = [Number(process.argv[2]), Number(process.argv[3]), process.argv[4]];
let n = 0;
http.createServer((req, res) => {
  n++; console.log(JSON.stringify({ n, method: req.method, url: req.url.split('?')[0], status, kind }));
  req.resume();
  if (kind === 'sse-fail' || kind === 'sse-bad') {
    res.writeHead(200, { 'content-type': 'text/event-stream' });
    if (kind === 'sse-fail') res.write('event: response.failed\ndata: ' + JSON.stringify({ type: 'response.failed', response: { id: 'r1', error: { code: 'server_error', message: 'mock stream failure' } } }) + '\n\n');
    else res.write('event: response.created\ndata: ' + JSON.stringify({ type: 'response.created', response: { id: 'r1' } }) + '\n\n');
    return res.end();
  }
  let body;
  if (kind === 'usage') body = { error: { type: 'usage_limit_reached', message: 'The usage limit has been reached', plan_type: 'plus', resets_at: Math.floor(Date.now() / 1000) + 3600, resets_in_seconds: 3600 } };
  else if (kind === 'rate') body = { error: { code: 'rate_limit_exceeded', type: 'rate_limit_exceeded', message: 'Rate limit reached for mock' } };
  else body = { error: { type: 'api_error', message: `mock ${status}` } };
  res.writeHead(status, { 'content-type': 'application/json', 'x-request-id': 'req_mock' });
  res.end(JSON.stringify(body));
}).listen(port, '127.0.0.1', () => console.log(JSON.stringify({ listening: port, status, kind })));
