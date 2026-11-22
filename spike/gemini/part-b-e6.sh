#!/bin/bash
# Spike 3.6 E6 (headless flags, typed output) and E7 (usage fields), mock model endpoint: no login, no quota. The mock reports fixed token counts so the mapping CLI field <- API field is visible.
# The real-model counterparts (typed output with the real model, quota) are in part-b-real.sh. Usage: SP=<new scratch dir> LSF_GEMINI_DIR=... H=... bash part-b-e6.sh
set -u
. "$LSF_GEMINI_DIR/part-b-lib.sh"; trap cleanup EXIT
echo "say ok" > "$SP/p.txt"; V=$H/fake-cli/validate.py; SCH=$H/fake-cli/result.schema.json
echo '[{"text":"mock says hi","usage":{"promptTokenCount":100,"candidatesTokenCount":7,"cachedContentTokenCount":40,"thoughtsTokenCount":5}}]' > "$SP/sc-text.json"
one(){ id=$1; sc=$2; shift 2; rm -rf "$SP/dump/$id"; stepnew "$id"; cp "$SCH" "$SP/work/$id/io/in/"; mockstart 8913 "$SP/$sc" "$SP/dump/$id"; runa "$id" 8913 40 "$SP/p.txt" -- "$@"; mockstop 8913; sleep 1; }
echo "--- E6/E7 a: prompt on stdin (no -p), --output-format json; mock API usage = prompt 100, candidates 7, cached 40, thoughts 5"
one e6-json sc-text.json --output-format json --model $MODEL; sed 's/"conversation_id":"[^"]*",//' "$SP/e6-json.out"
echo "(note, checked by hand, output not kept: -p takes the prompt as its VALUE: '-p' followed by a flag gives '-p took --output-format as its prompt' (rc 2), '-p' last gives 'flag needs an argument: -p' (rc 2); the prompt goes on stdin WITHOUT -p; -p \"\" is an empty prompt, see e12-empty)"
echo "--- b: default text output"; one e6-text sc-text.json --model $MODEL; echo "stdout: $(cat "$SP/e6-text.out")"
echo "--- c: stream-json: event names and the keys of the last event"
one e6-stream sc-text.json --output-format stream-json --model $MODEL
python3 -I - "$SP/e6-stream.out" <<'PY'
import json,sys
ev=[json.loads(l) for l in open(sys.argv[1]) if l.strip()]
print('  events:', [e['event'] for e in ev]); print('  init keys:', sorted(ev[0]['init'].keys()), 'tools declared in init:', len(ev[0]['init']['tools']))
print('  result keys:', sorted(ev[-1]['result'].keys()), 'usage:', ev[-1]['result']['usage'])
PY
echo "--- d: --effort on a model the CLI does not know / an invalid level (validated by the CLI before any request)"
one e6-eff-unsup sc-text.json --output-format json --effort low --model $MODEL; echo "  rc/err: $(head -c 200 "$SP/e6-eff-unsup.out" | sed 's/.*"error":"//; s/".*//')"
one e6-eff-bad sc-text.json --output-format json --effort ultra --model $MODEL; echo "  rc/err: $(head -c 200 "$SP/e6-eff-bad.out" | sed 's/.*"error":"//; s/".*//')"
echo "--- e: --json-schema with the common envelope (schema file inside the Step): the model calls finish(args)"
OKR='{"schema":"fake-result/1","status":"done","summary":"ok","role_shape":"reviewer-readonly"}'; BADR='{"schema":"fake-result/1","status":"bogus","summary":"x","role_shape":"reviewer-readonly"}'
echo "[{\"call\":{\"name\":\"finish\",\"args\":$OKR}}]" > "$SP/sc-fin-ok.json"
echo "[{\"call\":{\"name\":\"finish\",\"args\":$BADR}},{\"text\":\"gave up\"},{\"text\":\"gave up\"},{\"text\":\"gave up\"}]" > "$SP/sc-fin-bad.json"
echo '[{"text":"prose, no tool call"},{"text":"prose"},{"text":"prose"},{"text":"prose"},{"text":"prose"}]' > "$SP/sc-fin-none.json"
for c in ok bad none; do one e6-schema-$c sc-fin-$c.json --output-format json --json-schema "$SP/work/e6-schema-$c/io/in/result.schema.json" --model $MODEL
  python3 -I - "$SP/e6-schema-$c.out" "$SP/dump/e6-schema-$c/req-1.bin" "$V" "$SCH" "$c" <<'PY'
import json,sys,subprocess
o=json.loads(open(sys.argv[1]).read()); c=sys.argv[5]
print('  finish(%s): status=%s turns=%s structured_output=%s' % (c, o['status'], o['num_turns'], 'present' if 'structured_output' in o else 'ABSENT'))
if 'structured_output' in o:
    json.dump(o['structured_output'], open(sys.argv[1]+'.so','w')); print('  validate.py on structured_output:', subprocess.run(['python3',sys.argv[3],sys.argv[1]+'.so',sys.argv[4]],capture_output=True,text=True).stdout.strip()[:60])
if c=='ok':
    d=json.load(open(sys.argv[2])); f=[x for t in d['tools'] for x in t['functionDeclarations'] if x['name']=='finish'][0]['parameters']
    print('  what the model is shown as the finish() schema: schema=%s additionalProperties=%s allOf=%s status=%s' % (f['properties']['schema'], 'additionalProperties' in f, 'allOf' in f, f['properties']['status']))
PY
done
echo "  tool error the model gets for the invalid finish call: $(python3 -I "$G/bodyinfo.py" "$SP/dump/e6-schema-bad/req-2.bin" --last 1 | head -1 | cut -c1-230)"
echo "--- exit codes seen in E6/E12: success 0; invalid --effort/--model, empty -p prompt, no credential 1; non-retryable API error (400/401/403) and --print-timeout expiry 3; harness TERM/KILL 124 (with-timeout.pl); see part-b-e12.sh"
