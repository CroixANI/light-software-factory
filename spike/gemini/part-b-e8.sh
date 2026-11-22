#!/bin/bash
# Spike 3.6 E8 (B1): which instruction / settings / skill / hook / MCP files does agy read? Mock model (no login). Method: the request body the CLI sends to the model is dumped by the mock;
# every CANARY-* string in it was read into the model's context. Effects that never reach the context (settings allow rule, hook, MCP server) are shown by a marker file or by a tool run.
# Usage: SP=<new scratch dir> LSF_GEMINI_DIR=... H=... bash part-b-e8.sh
set -u
. "$LSF_GEMINI_DIR/part-b-lib.sh"; trap cleanup EXIT
w(){ mkdir -p "$(dirname "$1")"; printf '%s\n' "$2" > "$1"; }
skill(){ w "$1/foo/SKILL.md" "---
name: foo-$2
description: $2 skill description
---
$2 skill body"; }
plant(){ S=$1; Hm=$S/home/.gemini; Rp=$S/repo
  w $Hm/GEMINI.md "CANARY-HOME-GEMINI-MD"; w $Hm/AGENTS.md "CANARY-HOME-AGENTS-MD"
  w $Hm/settings.json '{"permissions":{"deny":["command(echo home-denied)"]},"canary":"CANARY-HOME-SETTINGS"}'
  w $Hm/antigravity-cli/settings.json '{"permissions":{"deny":["command(echo cli-denied)"]},"canary":"CANARY-HOME-CLI-SETTINGS"}'
  w $Hm/config/mcp_config.json "{\"mcpServers\":{\"home-mcp\":{\"command\":\"/bin/sh\",\"args\":[\"-c\",\"touch $S/tmp/mcp-home-ran\"]}}}"
  w $Hm/config/hooks.json "{\"hooks\":{\"PreToolUse\":[{\"matcher\":\".*\",\"hooks\":[{\"type\":\"command\",\"command\":\"touch $S/tmp/hook-home-ran\"}]}]}}"
  skill $Hm/config/skills CANARY-HOME-CFG-SKILL; skill $Hm/skills CANARY-HOME-SKILL
  w $Hm/config/workflows/w.md "---
description: CANARY-HOME-WORKFLOW
---
step one"
  w $Rp/src/GEMINI.md "CANARY-NESTED-GEMINI-MD"; w $Rp/src/AGENTS.md "CANARY-NESTED-AGENTS-MD"
  w $Rp/.agents/rules/r.md "---
trigger: always_on
---
CANARY-REPO-AGENTS-RULE"; skill $Rp/.agents/skills CANARY-REPO-AGENTS-SKILL; skill $Rp/.gemini/skills CANARY-REPO-GEMINI-SKILL
  w $Rp/.agents/workflows/w.md "---
description: CANARY-REPO-WORKFLOW
---
step one"
  w $Rp/.agents/hooks.json "{\"hooks\":{\"PreToolUse\":[{\"matcher\":\".*\",\"hooks\":[{\"type\":\"command\",\"command\":\"touch $S/tmp/hook-repo-ran\"}]}]}}"
  w $Rp/.agents/mcp_config.json "{\"mcpServers\":{\"repo-mcp\":{\"command\":\"/bin/sh\",\"args\":[\"-c\",\"touch $S/tmp/mcp-repo-ran\"]}}}"
  w $Rp/.gemini/commands/c.toml 'description = "CANARY-REPO-COMMAND"
prompt = "x"'
  w $Rp/.gemini/settings.json '{"canary":"CANARY-REPO-GEMINI-SETTINGS","permissions":{"deny":["command(echo repo-denied)"]}}'
  w $Rp/.mcp.json "{\"mcpServers\":{\"dot-mcp\":{\"command\":\"/bin/sh\",\"args\":[\"-c\",\"touch $S/tmp/mcp-dot-ran\"]}}}"; }
# scripted model: turn 1 reads src/calc.py (nested instruction file may load lazily) and runs echo for each allow rule, turn 2 finishes
mkscript(){ S=$1; cat > "$2" <<J
[{"calls":[{"name":"read_file","args":{"Path":"$S/repo/src/calc.py"}},{"name":"run_command","args":{"CommandLine":"echo home-denied","toolSummary":"e","WaitMsBeforeAsync":2000}},{"name":"run_command","args":{"CommandLine":"echo cli-denied","toolSummary":"e","WaitMsBeforeAsync":2000}},{"name":"run_command","args":{"CommandLine":"echo repo-denied","toolSummary":"e","WaitMsBeforeAsync":2000}},{"name":"run_command","args":{"CommandLine":"echo plain","toolSummary":"e","WaitMsBeforeAsync":2000}}]},{"text":"finished"}]
J
}
echo "list your instructions" > "$SP/p.txt"
variant(){ id=$1; mode=$2; shift 2; rm -rf "$SP/dump/$id"; stepnew "$id"; S=$SP/work/$id
  [ "$mode" = excluded ] && { rm -rf "$S/repo/.git/../.claude" "$S/repo/.codex" "$S/repo/.gemini" "$S/repo/.mcp.json" "$S/repo/AGENTS.md" "$S/repo/GEMINI.md" "$S/repo/CLAUDE.md" "$S/repo/CLAUDE.local.md"; }
  plant "$S"
  [ "$mode" = excluded ] && { rm -rf "$S/repo/.agents" "$S/repo/.gemini" "$S/repo/src/GEMINI.md" "$S/repo/src/AGENTS.md" "$S/repo/.mcp.json" "$S/home/.gemini"; mkdir -p "$S/home/.gemini"; }
  mkscript "$S" "$SP/sc-$id.json"; mockstart 8913 "$SP/sc-$id.json" "$SP/dump/$id"
  runa "$id" 8913 60 "$SP/p.txt" --extra-sb "$G/shell.sb" --extra-sb "$G/pty.sb" --extra-sb "$G/kill.sb" -- --output-format json --dangerously-skip-permissions --settings "{\"enableTerminalSandbox\":false${SETX:-}}" "$@" --model $MODEL
  [ -f "$SP/dump/$id/req-1.bin" ] || { echo "  no model request made; stderr: $(head -c 160 "$SP/$id.err")"; mockstop 8913; sleep 1; return; }
  echo "  first request: $(python3 -I "$G/bodyinfo.py" "$SP/dump/$id/req-1.bin" --canaries | head -1)"
  [ -f "$SP/dump/$id/req-2.bin" ] && echo "  second request (after read_file src/calc.py): $(python3 -I "$G/bodyinfo.py" "$SP/dump/$id/req-2.bin" --canaries | head -1)"
  echo "  tool results: $(python3 -I - "$SP/dump/$id/req-2.bin" <<'PY' 2>&1
import json,sys
try:
  d=json.load(open(sys.argv[1])); print([(p['functionResponse']['name'], 'denied-by-rule' if 'deny rule' in json.dumps(p['functionResponse']['response']) else 'error' if 'error' in p['functionResponse']['response'] else 'ok') for p in d['contents'][-1]['parts'] if 'functionResponse' in p])
except Exception as e: print('no second request')
PY
)"
  echo "  marker files in tmp/: $(ls "$S/tmp" 2>/dev/null | grep -E '^(hook|mcp)-' | tr '\n' ' ')"
  python3 -I - "$SP/$id.out" <<'PY'
import json,sys
o=json.loads(open(sys.argv[1]).read()); print('  status=%s denied=%s' % (o.get('status'), [x['action'] for x in o.get('denied_actions',[])]))
PY
  mockstop 8913; sleep 1; pkill -f "/tmp/mcp-.*-ran" 2>/dev/null; true; }
echo "V0 default flags, planted files in home/ and repo/"; variant e8-v0 planted
echo "V1 --disable-slash-commands"; variant e8-v1 planted --disable-slash-commands
echo "V2 excluded from the copy (home/.gemini emptied; repo has none of the listed files), default flags"; variant e8-v2 excluded
echo "V3 settings workspaceTrust:true (a key name seen in the binary; --settings rejects it)"; SETX=',"workspaceTrust":true' variant e8-v3 planted
echo "V4 settings workspaceTrust:false"; SETX=',"workspaceTrust":false' variant e8-v4 planted
