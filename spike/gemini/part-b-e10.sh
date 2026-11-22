#!/bin/bash
# Spike 3.6 E10: no shell (reviewer-readonly: agy.sb + base.sb only, no shell.sb/pty.sb/kill.sb). Mock model; the scripted worker tries every tool class under --dangerously-skip-permissions so that only the PROFILE decides.
# Prints, per tool call, ok / the first 110 chars of the tool error. Usage: SP=<new scratch dir> LSF_GEMINI_DIR=... H=... bash part-b-e10.sh
set -u
. "$LSF_GEMINI_DIR/part-b-lib.sh"; trap cleanup EXIT
id=e10; rm -rf "$SP/dump/$id"; stepnew $id; S=$SP/work/$id; echo "go" > "$SP/p.txt"
cat > "$SP/sc-$id.json" <<J
[{"calls":[
 {"name":"run_command","args":{"CommandLine":"echo hello","toolSummary":"e","WaitMsBeforeAsync":2000}},
 {"name":"read_file","args":{"Path":"$S/repo/src/calc.py"}},
 {"name":"read_file","args":{"Path":"$S/repo/src"}},
 {"name":"write_file","args":{"Path":"$S/io/out/r.txt","Content":"x","Overwrite":true}},
 {"name":"write_file","args":{"Path":"$S/repo/r.txt","Content":"x","Overwrite":true}},
 {"name":"edit_file","args":{"Path":"$S/repo/src/calc.py","Target":"a + b","Replacement":"a - b"}},
 {"name":"search_web","args":{"query":"x"}},
 {"name":"invoke_subagent","args":{"Prompt":"x","Role":"r"}},
 {"name":"run_workflow","args":{"Script":"print(1)","Description":"d"}}]},{"text":"finished"}]
J
mockstart 8913 "$SP/sc-$id.json" "$SP/dump/$id"; gwstart 8914 ""
runa $id 8913 60 "$SP/p.txt" -- --output-format json --dangerously-skip-permissions --settings '{"enableTerminalSandbox":false}' --model $MODEL
python3 -I - "$SP/dump/$id" <<'PY'
import json,sys,glob
reqs=[json.load(open(f)) for f in sorted(glob.glob(sys.argv[1]+"/req-*.bin"))]
print("  model requests made: %d (one per scripted turn; invoke_subagent adds its own)" % len(reqs))
d=[r for r in reqs if any("functionResponse" in p for p in r["contents"][-1]["parts"])][0]
names=['run_command echo','read_file calc.py','read_file dir src','write_file io/out','write_file repo/','edit_file repo','search_web','invoke_subagent','run_workflow']
for n,p in zip(names,d['contents'][-1]['parts']):
    r=p['functionResponse']['response']; import re
    print('  %-20s %s' % (n, ('ERROR '+r['error'][-130:].replace('\n',' ')) if 'error' in r else 'ok: '+re.sub(r'file://\S+','file://<path>',str(r.get('output',''))[60:260]).replace('\n',' ')))
PY
echo "repo/src/calc.py unchanged: $(cmp -s "$S/repo/src/calc.py" "$H/sample-repo/src/calc.py" && echo yes || echo NO)"; echo "io/out: $(ls "$S/io/out" | tr '\n' ' ')"
mockstop 8913
