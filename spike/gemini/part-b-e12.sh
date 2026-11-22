#!/bin/bash
# Spike 3.6 E12 (failure classes). Mock model endpoint (no login, no quota) forces API failures; agy's own conditions (no credential, bad model/effort/prompt), harness timers and sandbox denials are forced directly.
# Per case: exit code, the typed fields of the JSON result, requests the mock saw, wall time. Runs are in parallel (one Step + one mock port each). Usage: SP=<new scratch dir> LSF_GEMINI_DIR=... H=... bash part-b-e12.sh
set -u
. "$LSF_GEMINI_DIR/part-b-lib.sh"; trap cleanup EXIT
echo "do the task" > "$SP/p.txt"
fields(){ python3 -I - "$SP/$1.out" "$SP/$1.err" <<'PY'
import json,sys
raw=open(sys.argv[1]).read().strip(); err=open(sys.argv[2]).read().strip().replace('\n',' | ')[:170]
try:
    o=json.loads(raw); print('status=%s finished_reason=%s error=%r denied=%s structured=%s turns=%s dur=%.1fs' % (o.get('status'),o.get('finished_reason'),(o.get('error') or '')[:150],[x['action'] for x in o.get('denied_actions',[])],'structured_output' in o,o.get('num_turns'),o.get('duration_seconds',0)))
except Exception: print('stdout not JSON: %r' % raw[:120])
print('  stderr: %s' % err)
PY
}
reqs(){ grep -c '"n"' "$SP/mock$1.log" 2>/dev/null; }
# --- API failures (parallel): fixed status for every request
i=0; for st in 429 500 503 401 400 403; do port=$((8921+i)); i=$((i+1)); (mockstart $port status:$st; stepnew e12-$st; s=$(date +%s); runa e12-$st $port 100 "$SP/p.txt" -- --output-format json --model $MODEL > "$SP/e12-$st.rc"; echo $(( $(date +%s)-s )) > "$SP/e12-$st.wall"; mockstop $port) & done; wait
for st in 429 500 503 401 400 403; do port=$((8921+$(echo "429 500 503 401 400 403" | tr ' ' '\n' | grep -n "^$st$" | cut -d: -f1)-1)); echo "HTTP $st: $(cat "$SP/e12-$st.rc") wall=$(cat "$SP/e12-$st.wall")s mock requests=$(reqs $port)"; fields e12-$st; done
# --- truncated stream (partial answer, no finish reason)
mockstart 8913 <(echo '[{"truncated":true}]') ; stepnew e12-trunc; runa e12-trunc 8913 60 "$SP/p.txt" -- --output-format json --model $MODEL; fields e12-trunc; mockstop 8913
# --- hang: the request is never answered; --print-timeout 6 (agy's own limit) and the harness timer
echo '[{"hang":true}]' > "$SP/sc-hang.json"
mockstart 8913 "$SP/sc-hang.json"; stepnew e12-ptimeout; s=$(date +%s); runa e12-ptimeout 8913 60 "$SP/p.txt" -- --output-format json --print-timeout 6s --model $MODEL; echo "  wall=$(( $(date +%s)-s ))s"; fields e12-ptimeout; mockstop 8913
mockstart 8913 "$SP/sc-hang.json"; stepnew e12-hang; s=$(date +%s); runa e12-hang 8913 8 "$SP/p.txt" -- --output-format json --model $MODEL; echo "  wall=$(( $(date +%s)-s ))s (with-timeout.pl: TERM at 8 s, KILL 10 s later; rc 124 = harness timeout)"; fields e12-hang; mockstop 8913
# --- invalid output: --json-schema and the model never calls finish; missing result.json
echo '[{"text":"no tool call"},{"text":"no tool call"},{"text":"no tool call"},{"text":"no tool call"},{"text":"no tool call"}]' > "$SP/sc-nofinish.json"
mockstart 8913 "$SP/sc-nofinish.json"; stepnew e12-nofinish; cp "$H/fake-cli/result.schema.json" "$SP/work/e12-nofinish/io/in/"; runa e12-nofinish 8913 60 "$SP/p.txt" -- --output-format json --json-schema "$SP/work/e12-nofinish/io/in/result.schema.json" --model $MODEL; fields e12-nofinish; echo "  io/out files: $(ls "$SP/work/e12-nofinish/io/out" | wc -l | tr -d ' ')"; mockstop 8913
# --- agy's own argument errors: unknown model, unsupported effort, empty prompt, no credential at all
stepnew e12-model; echo '[{"text":"x"}]' > "$SP/sc-x.json"; mockstart 8913 "$SP/sc-x.json"; runa e12-model 8913 30 "$SP/p.txt" -- --output-format json --model not-a-model; fields e12-model; echo "  mock requests: $(reqs 8913)"; mockstop 8913
stepnew e12-empty; mockstart 8913 "$SP/sc-x.json"; runa e12-empty 8913 30 - -- --output-format json --model $MODEL; fields e12-empty; mockstop 8913
stepnew e12-nocred; gwstart 8920 "oauth2.googleapis.com"   # no gateway env, no token: what does `agy -p` do when nobody is logged in? (login needs the browser: open is denied; the gateway allows only the OAuth host)
"$G/with-timeout.pl" 40 "$R" --step "$SP/work/e12-nocred" --port 8920 "${X[@]}" -- --output-format json --model gemini-3.8-flash-low < "$SP/p.txt" > "$SP/e12-nocred.out" 2> "$SP/e12-nocred.err"; echo "e12-nocred rc=$?"; fields e12-nocred
echo "  gateway hosts: $(grep -oE '"host":"[^"]*"' "$SP/gw8920.log" | sort | uniq -c | tr '\n' ' ')"; gwstop 8920
# --- a FAKE token file in the flat format of part A (this agy build writes {token:{access_token,...}}): it is NOT recognised at all, same result as no credential; the revoked-credential case with the real format is R5 in part-b-real.sh
stepnew e12-expired; T=$SP/work/e12-expired/home/.gemini/antigravity-cli; mkdir -p "$T"; echo '{"access_token":"fake-access","refresh_token":"fake-refresh","expiry":"2020-01-01T00:00:00Z","expires_in":3599,"auth_method":"oauth","id_token_email":"nobody@example.invalid"}' > "$T/antigravity-oauth-token"; chmod 600 "$T/antigravity-oauth-token"
gwstart 8920 "oauth2.googleapis.com,www.googleapis.com"
"$G/with-timeout.pl" 60 "$R" --step "$SP/work/e12-expired" --port 8920 "${X[@]}" -- --output-format json --model gemini-3.8-flash-low < "$SP/p.txt" > "$SP/e12-expired.out" 2> "$SP/e12-expired.err"; echo "e12-expired rc=$?"; fields e12-expired
echo "  gateway hosts: $(grep -oE '"host":"[^"]*"' "$SP/gw8920.log" | sort | uniq -c | tr '\n' ' ')"; gwstop 8920
# --- sandbox denial: file tool and terminal tool writing outside the Step (flag on so only the profile decides)
echo '[{"calls":[{"name":"write_file","args":{"Path":"/private/tmp/lsf-e12-outside.txt","Content":"x","Overwrite":true}},{"name":"run_command","args":{"CommandLine":"touch /private/tmp/lsf-e12-outside2.txt","toolSummary":"t","WaitMsBeforeAsync":3000}}]},{"text":"finished"}]' > "$SP/sc-deny.json"
mockstart 8913 "$SP/sc-deny.json" "$SP/dump/e12-deny"; stepnew e12-deny; runa e12-deny 8913 60 "$SP/p.txt" --extra-sb "$G/shell.sb" --extra-sb "$G/pty.sb" --extra-sb "$G/kill.sb" -- --output-format json --dangerously-skip-permissions --settings '{"enableTerminalSandbox":false}' --model $MODEL; fields e12-deny
python3 -I - "$SP/dump/e12-deny/req-2.bin" <<'PY'
import json,sys
d=json.load(open(sys.argv[1]))
for p in d['contents'][-1]['parts']:
    r=p['functionResponse']; print('  tool %s -> %s' % (r['name'], json.dumps(r['response'])[-150:]))
PY
echo "  outside files created: $(ls /private/tmp/lsf-e12-outside*.txt 2>/dev/null | wc -l | tr -d ' ')"; mockstop 8913
