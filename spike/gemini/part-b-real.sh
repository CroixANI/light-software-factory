#!/bin/bash
# Spike 3.6 part B, the only REAL-model runs (login token made by login.sh inside a Step; model gemini-3.8-flash-low; 3 model calls + 3 local/auth-only runs):
#  R1 --effort + usage fields, R2 stream-json + --json-schema (typed output with the real model), R3 worker writes io/out/result.json with its own file tool (reviewer-readonly profile, allow rules, no shell),
#  R4 /quota in print mode (a local command, no model call), R5 revoked credential (junk refresh token on a copy of the real token file: OAuth host only, no model call).
# Usage: [SUMMARY_ONLY=1] SP=<scratch dir> LSF_GEMINI_DIR=... H=... LOGIN_HOME=<login Step home> bash part-b-real.sh
set -u
. "$LSF_GEMINI_DIR/part-b-real-lib.sh"; trap cleanup EXIT
V=$H/fake-cli/validate.py; SCH=$H/fake-cli/result.schema.json
[ -z "${SUMMARY_ONLY:-}" ] && { gwstart $RP "$HOSTS"; trap 'cleanup; rm -rf "$RW"' EXIT; }   # a real run deletes its token copies (the Steps under $RW) when it ends
hosts(){ echo "  gateway hosts so far: $(grep -oE '"host":"[^"]*"' "$SP/gw$RP.log" | sort | uniq -c | sed 's/"host"://' | tr '\n' ' ')"; }
Q(){ rstep "$1"; echo "/quota" > "$SP/pq.txt"; runr "$1" 60 "$SP/pq.txt" -- --output-format json --model $RMODEL; }
if [ -z "${SUMMARY_ONLY:-}" ]; then   # SUMMARY_ONLY=1 re-prints the summary of the outputs of an earlier run (no model call); the committed log was made that way from the single real run
echo "== R4a quota before the model calls"; Q r4a
echo "== R1 --effort low + usage"; rstep r1; echo "Reply with exactly: ok" > "$SP/pr1.txt"; runr r1 90 "$SP/pr1.txt" -- --output-format json --effort low --model $RMODEL
echo "== R2 stream-json + --json-schema, real model"; rstep r2; cp "$SCH" "$RW/r2/io/in/"
echo "Return the result for a code review that found nothing wrong: status done, a one-sentence summary, role_shape reviewer-readonly. Deliver it by calling the finish tool." > "$SP/pr2.txt"
runr r2 120 "$SP/pr2.txt" -- --output-format stream-json --json-schema "$RW/r2/io/in/result.schema.json" --model $RMODEL
echo "== R3 worker writes io/out/result.json itself (reviewer-readonly profile, allow rules, no flag)"; rstep r3; S=$RW/r3
echo "Read the file $S/repo/src/calc.py. Then write the JSON file $S/io/out/result.json with exactly these keys: schema = \"fake-result/1\", status = \"done\", summary = one sentence about calc.py, role_shape = \"reviewer-readonly\". No other keys. Do not run commands." > "$SP/pr3.txt"
runr r3 120 "$SP/pr3.txt" -- --output-format json --settings "{\"enableTerminalSandbox\":false,\"permissions\":{\"allow\":[\"read_file($S)\",\"write_file($S/io/out)\"]}}" --model $RMODEL
cp "$RW/r3/io/out/result.json" "$SP/r3-result.json" 2>/dev/null
echo "== R5 revoked credential: copy of the real token with a junk refresh token and an expired expiry"; rstep r5
python3 -I - "$(tokpath r5)" <<'PY'
import json,sys
p=sys.argv[1]; d=json.load(open(p)); d['token']['access_token']='junk-access'; d['token']['refresh_token']='1//junk-refresh'; d['token']['expiry']='2020-01-01T00:00:00Z'
json.dump(d,open(p,'w'))
PY
echo "Reply with exactly: ok" > "$SP/pr5.txt"; runr r5 60 "$SP/pr5.txt" -- --output-format json --model $RMODEL
echo "== R4b quota after the model calls"; Q r4b
fi
# ---- summaries (no secrets: field names, counts, statuses)
python3 -I - "$SP" "$RW" "$V" "$SCH" <<'PY'
import json,sys,subprocess
sp,rw,V,SCH=sys.argv[1:5]
def load(i):
    try: return json.loads(open(f'{sp}/{i}.out').read())
    except Exception: return None
def err(i): return open(f'{sp}/{i}.err').read().strip().replace('\n',' | ')[:200]
r=load('r1'); print('R1 status=%s usage=%s keys=%s response=%r' % (r and r['status'], r and r['usage'], r and sorted(r.keys()), r and r['response'][:40]))
ev=[json.loads(l) for l in open(f'{sp}/r2.out') if l.strip()]
print('R2 stream events:', [e['event'] for e in ev][:20], '... total', len(ev))
fin=[e for e in ev if e['event']=='result'][-1]['result']; print('R2 final result keys:', sorted(fin.keys())); print('R2 status=%s structured_output=%s usage=%s' % (fin.get('status'), fin.get('structured_output'), fin.get('usage')))
if fin.get('structured_output'):
    json.dump(fin['structured_output'], open(f'{sp}/r2-structured.json','w')); print('R2 validate.py:', subprocess.run(['python3',V,f'{sp}/r2-structured.json',SCH],capture_output=True,text=True).stdout.strip()[:80])
r=load('r3'); print('R3 status=%s denied=%s turns=%s usage=%s' % (r and r['status'], r and r.get('denied_actions'), r and r['num_turns'], r and r['usage']))
try: print('R3 result.json:', open(f'{sp}/r3-result.json').read()[:300].replace('\n',' ')); print('R3 validate.py:', subprocess.run(['python3',V,f'{sp}/r3-result.json',SCH],capture_output=True,text=True).stdout.strip()[:100])
except Exception as e: print('R3 no result.json', e)
r=load('r5'); print('R5 status=%s finished_reason=%s error=%r stderr=%s' % (r and r['status'], r and r.get('finished_reason'), r and (r.get('error') or '')[:150], err('r5')))
for i in ('r4a','r4b'):
    r=load(i)
    if r:
        b=[(g['name'], b['id'], round(b['remaining_fraction'],4), b['window'], b['reset_time']) for g in r['command']['data']['groups'] for b in g['buckets']]
        print(i,'quota buckets:', b)
PY
hosts
