#!/bin/bash
# Spike 3.6 (follow-up to part A, E5): do permissions.allow/deny rules work in headless mode, with and without --dangerously-skip-permissions? Mock model, no login.
# Each variant: the scripted model calls write_file twice (io/out/a.txt, repo/b.txt), run_command echo, read_file of a file outside the Step; the log shows which calls ran.
# Usage: SP=<new scratch dir> LSF_GEMINI_DIR=... H=... bash part-b-perm.sh
set -u
. "$LSF_GEMINI_DIR/part-b-lib.sh"; trap cleanup EXIT
echo "do the calls" > "$SP/p.txt"; echo "OUTSIDE-FILE-CONTENT" > "$SP/outside.txt"
variant(){ id=$1; settings=$2; shift 2; rm -rf "$SP/dump/$id"; stepnew "$id"; S=$SP/work/$id
  cat > "$SP/sc-$id.json" <<J
[{"calls":[{"name":"write_file","args":{"Path":"$S/io/out/a.txt","Content":"A","Overwrite":true}},{"name":"write_file","args":{"Path":"$S/repo/b.txt","Content":"B","Overwrite":true}},{"name":"run_command","args":{"CommandLine":"echo hello-from-shell","toolSummary":"echo","WaitMsBeforeAsync":2000}},{"name":"read_file","args":{"Path":"$SP/outside.txt"}}]},{"text":"finished"}]
J
  mockstart 8913 "$SP/sc-$id.json" "$SP/dump/$id"
  runa "$id" 8913 40 "$SP/p.txt" --extra-sb "$G/shell.sb" --extra-sb "$G/pty.sb" -- --output-format json --settings "${settings//STEP/$S}" "$@" --model $MODEL
  python3 -I - "$SP/$id.out" "$SP/dump/$id/req-2.bin" "$S" <<'PY'
import json,sys,os
o=json.loads(open(sys.argv[1]).read()); S=sys.argv[3]
res=[]
try:
    d=json.load(open(sys.argv[2]))
    for pt in d['contents'][-1]['parts']:
        r=pt['functionResponse']; t=json.dumps(r['response'])
        res.append((r['name'],'denied' if 'denied' in t.lower() or 'Permission' in t else 'error:'+t[:70] if 'error' in r['response'] else 'ok'))
except Exception as e: res.append(('run ended at the first denied call: no second model request',''))
print('  status=%s denied_actions=%s' % (o.get('status'), [x['action'] for x in o.get('denied_actions',[])]))
print('  tool results:', res)
print('  files: a.txt=%s b.txt=%s' % (os.path.exists(S+'/io/out/a.txt'), os.path.exists(S+'/repo/b.txt')))
PY
  mockstop 8913; sleep 1; }
T='"enableTerminalSandbox":false'
# Rule syntax: `tool(target)`; target is a literal path or command PREFIX (a `*` glob is not a wildcard: V3a/V6a); strings in the binary show command(<prefix>), read_file(<absolute_path>), write_file(<path>).
echo "V1 no flag, no rules";                      variant v1 "{$T}"
echo "V2 no flag, allow write_file(<exact io/out/a.txt>)"; variant v2 "{$T,\"permissions\":{\"allow\":[\"write_file(STEP/io/out/a.txt)\"]}}"
echo "V3a no flag, allow with * globs (write_file(STEP/io/out/*), command(echo *))"; variant v3a "{$T,\"permissions\":{\"allow\":[\"write_file(STEP/io/out/*)\",\"command(echo *)\"]}}"
echo "V3b no flag, allow by directory / prefix (write_file(STEP/io/out), command(echo))"; variant v3b "{$T,\"permissions\":{\"allow\":[\"write_file(STEP/io/out)\",\"command(echo)\"]}}"
echo "V4 no flag, allow dir + deny exact file (deny must win)"; variant v4 "{$T,\"permissions\":{\"allow\":[\"write_file(STEP/io/out)\"],\"deny\":[\"write_file(STEP/io/out/a.txt)\"]}}"
echo "V5 --mode accept-edits, no rules";         variant v5 "{$T}" --mode accept-edits
echo "V6a --dangerously-skip-permissions, deny with * globs"; variant v6a "{$T,\"permissions\":{\"deny\":[\"write_file(STEP/repo/*)\",\"command(echo *)\"]}}" --dangerously-skip-permissions
echo "V6b --dangerously-skip-permissions, deny by directory / prefix (write_file(STEP/repo), command(echo))"; variant v6b "{$T,\"permissions\":{\"deny\":[\"write_file(STEP/repo)\",\"command(echo)\"]}}" --dangerously-skip-permissions
echo "V7 --dangerously-skip-permissions, no rules"; variant v7 "{$T}" --dangerously-skip-permissions
