#!/bin/bash
# Spike 3.4 throwaway: E6 (headless flags, typed output), E7 (usage, quota), E10 (no shell). Content-free output.
# Usage: SP=<existing scratch dir> LSF_CODEX_DIR=... H=... R=...  part-b-e6.sh   (starts its own gateway on 8961 allowing chatgpt.com)
set -u
. "$LSF_CODEX_DIR/part-b-lib.sh"; C=$LSF_CODEX_DIR
gwstart 8961 chatgpt.com; trap 'gwstop 8961' EXIT
echo 'Reply with the single word: pong' > "$SP/p-pong.txt"
rollout(){ find "$SP/work/$1/home/.codex/sessions" -name '*.jsonl' 2>/dev/null | head -1; }
echo "-- E6 model and effort flags; effective values from the rollout:"
id=e6-flags; rm -rf "$SP/work/$id"; step "$id"
runx "$id" "$SP/p-pong.txt" 8961 exec --json --skip-git-repo-check -s read-only -m gpt-5.6-luna -c model_reasoning_effort=low "${HYG[@]}"
python3 -I "$C/summarize.py" "$SP/$id.out" | cut -c1-200
python3 -I - "$(rollout $id)" <<'PY'
import json, sys
for l in open(sys.argv[1]):
    d = json.loads(l); p = d.get('payload', {})
    if d.get('type') == 'turn_context': print('  turn_context:', {k: p.get(k) for k in ('model', 'effort', 'approval_policy')})
    if d.get('type') == 'event_msg' and p.get('type') == 'token_count' and p.get('rate_limits'):
        r = p['rate_limits']; print('  E7 quota (rollout token_count.rate_limits): keys', sorted(r.keys()), '| primary keys', sorted((r.get('primary') or {}).keys()), '| used_percent', (r.get('primary') or {}).get('used_percent'), '| window_minutes', (r.get('primary') or {}).get('window_minutes'), '| secondary', r.get('secondary'))
PY
echo "-- E6 --output-schema: what the API accepts (errors come back before any model tokens):"
for v in full noallof strict; do
  id=e6-schema-$v; rm -rf "$SP/work/$id"; step "$id"; s=$SP/work/$id
  python3 -I - "$H/fake-cli/result.schema.json" "$s/io/in/result.schema.json" "$v" "$C/result.schema.strict.json" <<'PY'
import json, sys
src, dst, v, strict = sys.argv[1:5]; s = json.load(open(src))
if v == 'noallof': s.pop('allOf'); s.pop('$schema'); s.pop('$id')
if v == 'strict': s = json.load(open(strict))
json.dump(s, open(dst, 'w'))
PY
  echo "Read src/calc.py (use your shell tool), then reply with ONLY a JSON object: schema = fake-result/1, status = done, summary = one sentence about what src/calc.py does, role_shape = builder." > "$SP/p-struct.txt"
  XSB="$C/shell.sb" runx "$id" "$SP/p-struct.txt" 8961 exec --json --skip-git-repo-check -s danger-full-access -c 'approval_policy="never"' -m gpt-5.6-luna -c model_reasoning_effort=low "${HYG[@]}" --disable multi_agent --ignore-user-config --ignore-rules -c project_doc_max_bytes=0 -c skills.include_instructions=false --output-schema "$s/io/in/result.schema.json" -o "$s/io/out/last.json"
  echo "  schema=$v: $(python3 -I "$C/summarize.py" "$SP/$id.out" | grep -E ' err:' | tail -1 | cut -c1-210)"
  if [ -s "$s/io/out/last.json" ]; then
    python3 -I - "$s/io/out/last.json" "$s/io/out/result.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1])); print('  -o file is JSON with keys', sorted(d.keys()), '| null-valued:', sorted(k for k, v in d.items() if v is None))
json.dump({k: v for k, v in d.items() if v is not None}, open(sys.argv[2], 'w'))   # what a harness must do: drop the nulls that strict mode forces
PY
    echo "  after dropping null optionals: $(python3 -I "$H/fake-cli/validate.py" "$s/io/out/result.json")"
  fi
done
echo "-- E10 no shell (--disable shell_tool, profile without shell.sb): tools, read attempt, result.json written by the worker with apply_patch:"
id=e10; rm -rf "$SP/work/$id"; step "$id"; s=$SP/work/$id
cat > "$SP/p-e10.txt" <<E2
Do these two things. 1) Try to read src/calc.py with any tool you have; remember whether you could (YES/NO) and the tool. 2) Use the apply_patch tool to create $s/io/out/result.json containing exactly one JSON object: schema "fake-result/1", status "done", summary (one sentence: could you read src/calc.py, with which tool), role_shape "reviewer-readonly". Then reply with the single word: written.
E2
runx "$id" "$SP/p-e10.txt" 8961 exec --json --skip-git-repo-check -s danger-full-access -c 'approval_policy="never"' -m gpt-5.6-luna -c model_reasoning_effort=low "${HYG[@]}" --disable shell_tool --disable multi_agent --ignore-user-config --ignore-rules -c project_doc_max_bytes=0 -c skills.include_instructions=false
python3 -I "$C/summarize.py" "$SP/$id.out" | grep -E 'file_change|msg:' | sed "s#$SP#SP#g" | cut -c1-230
echo "  result.json: $(python3 -I "$H/fake-cli/validate.py" "$s/io/out/result.json"); summary: $(python3 -c "import json;print(json.load(open('$s/io/out/result.json'))['summary'])")"
echo "-- E10 tool inventory with and without shell_tool:"
echo "List the names of all tools available to you, including nested ones reachable through the exec tool (for example JavaScript printing Object.keys(tools)). Reply with the comma-separated names only." > "$SP/p-tools.txt"
for v in default noshell; do id=e10-tools-$v; rm -rf "$SP/work/$id"; step "$id"; x=(); [ $v = noshell ] && x=(--disable shell_tool)
  runx "$id" "$SP/p-tools.txt" 8961 exec --json --skip-git-repo-check -s danger-full-access -c 'approval_policy="never"' -m gpt-5.6-luna -c model_reasoning_effort=low "${HYG[@]}" --ignore-user-config --ignore-rules -c project_doc_max_bytes=0 -c skills.include_instructions=false ${x[@]+"${x[@]}"} >/dev/null
  echo "  $v: $(python3 -I "$C/summarize.py" "$SP/$id.out" | grep ' msg:' | tail -1 | cut -c1-400)"; done
