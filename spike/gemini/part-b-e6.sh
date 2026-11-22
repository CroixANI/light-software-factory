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
echo "(note, checked by hand, output not kept: -p takes the prompt as its VALUE: '-p' followed by a flag gives '-p took --output-format as its prompt' (rc 2), '-p' last gives 'flag needs an argument: -p' (rc 2); the prompt goes on stdin WITHOUT -p; -p \"\" gave 'empty prompt', rc 1: manual; e12-empty is a different case, an empty stdin WITHOUT -p)"
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
one e6-eff-unsup sc-text.json --output-format json --effort low --model $MODEL; echo "  $(python3 -I -c "import json,sys;print(json.load(open(sys.argv[1]))['error'][:200])" "$SP/e6-eff-unsup.out")"
one e6-eff-bad sc-text.json --output-format json --effort ultra --model $MODEL; echo "  $(python3 -I -c "import json,sys;print(json.load(open(sys.argv[1]))['error'][:200])" "$SP/e6-eff-bad.out")"
echo "--- d2: real model ids served by the mock (the CLI believes it talks to a known model family): the tools declared to the model, and what --model/--effort do to the request"
for combo in "gemini-3.8-flash-low|" "gemini-3.8-flash|" "gemini-3.8-flash|--effort high" "gemini-3.8-flash|--effort low" "gemini-3.8-flash-low|--effort high"; do
  M=${combo%%|*}; EFF=${combo#*|}; MODEL=$M; id=e6-m-$(echo "$M$EFF" | tr -c 'a-z0-9\n' -); rm -rf "$SP/dump/$id"; stepnew "$id"; mockstart 8913 "$SP/sc-text.json" "$SP/dump/$id"
  runa "$id" 8913 40 "$SP/p.txt" -- --output-format json $EFF --model $M; mockstop 8913; sleep 1
  if [ -f "$SP/dump/$id/req-1.bin" ]; then T=$(python3 -I "$G/bodyinfo.py" "$SP/dump/$id/req-1.bin" --tools | head -1); echo "  [$M $EFF] $(python3 -I "$G/bodyinfo.py" "$SP/dump/$id/req-1.bin" --cfg | head -1 | sed 's/generationConfig: //'); declared tools: $(( $(echo "$T" | wc -w) - 1 )); list/search tool among them: $(echo "$T" | grep -cE 'list_dir|grep_search|find_by_name')"
  else echo "  [$M $EFF] no request: $(python3 -I -c "import json,sys;print(json.load(open(sys.argv[1]))['error'][:160])" "$SP/$id.out")"; fi
done; MODEL=mock-model
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
echo "--- exit codes: see the rc= lines of this script and of part-b-e12.sh (the summary in the findings is written from them; the empty -p prompt rc 1 is the manual run above)"
