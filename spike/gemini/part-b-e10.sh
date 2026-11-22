#!/bin/bash
# Spike 3.6 E10: no shell (reviewer-readonly: base.sb + agy.sb + hosts.sb + lsbind.sb + the one Mach service, no shell.sb/pty.sb/kill.sb). Mock model; the scripted worker tries every tool class under --dangerously-skip-permissions so that only the PROFILE decides.
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
 {"name":"run_workflow","args":{"Script":"import subprocess\nopen(\"$S/io/out/wf-inside.txt\",\"w\").write(\"x\")\ntry:\n    open(\"/private/tmp/lsf-wf-outside.txt\",\"w\").write(\"x\")\nexcept Exception as e:\n    open(\"$S/io/out/wf-outside-error.txt\",\"w\").write(type(e).__name__)\ntry:\n    subprocess.run([\"/bin/echo\",\"x\"],check=True)\nexcept Exception as e:\n    open(\"$S/io/out/wf-exec-error.txt\",\"w\").write(type(e).__name__)","Description":"d","WaitMsBeforeAsync":8000}}]},{"text":"finished"}]
J
mockstart 8913 "$SP/sc-$id.json" "$SP/dump/$id"
runa $id 8913 60 "$SP/p.txt" -- --output-format json --dangerously-skip-permissions --settings '{"enableTerminalSandbox":false}' --model $MODEL
python3 -I - "$SP/dump/$id" <<'PY'
import json,sys,glob
reqs=[json.load(open(f)) for f in sorted(glob.glob(sys.argv[1]+"/req-*.bin"))]
print("  model requests made: %d (one per scripted turn; invoke_subagent adds its own)" % len(reqs))
d=[r for r in reqs if any("functionResponse" in p for p in r["contents"][-1]["parts"])][0]
names=['run_command echo','read_file calc.py','read_file dir src','write_file io/out','write_file repo/','edit_file repo','search_web','invoke_subagent','run_workflow']
for n,p in zip(names,d['contents'][-1]['parts']):
    r=p['functionResponse']['response']; import re
    red=lambda t: re.sub(r'file://\S+','file://<path>',re.sub(r'/[^ ]*/work/e10/','<step>/',t))
    print('  %-20s %s' % (n, ('ERROR '+red(r['error'])[-130:].replace('\n',' ')) if 'error' in r else 'ok: '+red(str(r.get('output','')))[60:260].replace('\n',' ')))
PY
echo "repo/src/calc.py unchanged: $(cmp -s "$S/repo/src/calc.py" "$H/sample-repo/src/calc.py" && echo yes || echo NO)"; echo "io/out: $(ls "$S/io/out" | tr '\n' ' ')"
echo "run_workflow (model-supplied Python script run by the CLI; reviewer-readonly profile): wrote inside io/out: $([ -f "$S/io/out/wf-inside.txt" ] && echo yes || echo no); write outside the Step: $([ -f /private/tmp/lsf-wf-outside.txt ] && echo CREATED || echo not created) ($(cat "$S/io/out/wf-outside-error.txt" 2>/dev/null)); exec of /bin/echo from the script: $(cat "$S/io/out/wf-exec-error.txt" 2>/dev/null || echo "no error recorded")"; rm -f /private/tmp/lsf-wf-outside.txt
echo "tools declared to the model (request 1): $(python3 -I "$G/bodyinfo.py" "$SP/dump/$id/req-1.bin" --tools | head -1)"
mockstop 8913
# the CLI lists more tool names in stream-json init than it declares to the model: which ones
stepnew e10-init; echo '[{"text":"x"}]' > "$SP/sc-e10i.json"; mockstart 8913 "$SP/sc-e10i.json" "$SP/dump/e10-init"; runa e10-init 8913 40 "$SP/p.txt" -- --output-format stream-json --model $MODEL; mockstop 8913
python3 -I - "$SP/e10-init.out" "$SP/dump/e10-init/req-1.bin" <<'PY'
import json,sys
ev=json.loads(open(sys.argv[1]).readline()); init=ev["init"]["tools"]; d=json.load(open(sys.argv[2])); decl=[f["name"] for t in d["tools"] for f in t["functionDeclarations"]]
print("stream-json init lists %d tool names, the model request declares %d; init-only names: %s" % (len(init), len(decl), " ".join(n for n in init if n not in decl)))
print("declared to the model but NOT in init.tools (init is not a superset): %s" % " ".join(n for n in decl if n not in init))
PY

