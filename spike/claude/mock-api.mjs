// Spike 3.2 E12 throwaway: a fake Anthropic API on one localhost port that answers every request with a fixed error, to force failure classes.
// Usage: node mock-api.mjs <port> <status> [retry-after-seconds]   e.g. 429 (rate limit), 529 (overloaded), 401 (auth), 500
import http from 'node:http';
const [port, status, retry] = [Number(process.argv[2]), Number(process.argv[3]), process.argv[4]];
const types = { 429: 'rate_limit_error', 529: 'overloaded_error', 401: 'authentication_error', 500: 'api_error', 400: 'invalid_request_error' };
let n = 0;
http.createServer((req, res) => {
  n++; console.log(JSON.stringify({ n, method: req.method, url: req.url.split('?')[0], status }));
  req.resume();
  const h = { 'content-type': 'application/json', 'request-id': 'req_mock' };
  if (retry) h['retry-after'] = retry;
  res.writeHead(status, h);
  res.end(JSON.stringify({ type: 'error', error: { type: types[status] || 'api_error', message: `mock ${status}` } }));
}).listen(port, '127.0.0.1', () => console.log(JSON.stringify({ listening: port, status })));
