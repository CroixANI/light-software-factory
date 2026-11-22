#!/bin/bash
# Spike 3.4 E12 throwaway (failure classes). Mock Responses API on one localhost port (mock-api.mjs) for API errors; real calls (gateway 8961 allowing chatgpt.com) for the rest. Content-free output.
# Usage: SP=<existing scratch dir> LSF_CODEX_DIR=... H=... R=...  part-b-e12.sh
set -u
. "$LSF_CODEX_DIR/part-b-lib.sh"; C=$LSF_CODEX_DIR
echo 'Reply with the single word: pong' > "$SP/p-pong.txt"
MPROV=(-c 'model_provider="mock"' -c 'model_providers.mock={name="mock",base_url="http://127.0.0.1:8963/v1",wire_api="responses",supports_websockets=false}')
EX=(exec --json --skip-git-repo-check -s read-only -m gpt-5.6-luna "${HYG[@]}")
types(){ python3 -c "
import json
print([json.loads(l).get('type') for l in open('$1') if l.startswith('{')])"; }
echo "-- API errors forced with mock-api.mjs (profile port = mock port):"
for c in "429 usage" "429 rate" "500 plain" "503 plain" "401 plain" "400 plain" "200 sse-fail" "200 sse-bad"; do read st kd <<< "$c"
  id=e12-$st-$kd; rm -rf "$SP/work/$id"; step "$id"; node "$C/mock-api.mjs" 8963 "$st" "$kd" > "$SP/mock.log" 2>&1 & mp=$!; sleep 1; t0=$(date +%s)
  r=$(runx "$id" "$SP/p-pong.txt" 8963 "${EX[@]}" "${MPROV[@]}"); kill $mp; wait $mp 2>/dev/null
  echo "$r mock=$st/$kd secs=$(( $(date +%s)-t0 )) mock-requests=$(grep -c '"n"' "$SP/mock.log") events=$(types "$SP/$id.out")"
  python3 -I "$C/summarize.py" "$SP/$id.out" | grep ' err:' | tail -1 | cut -c1-170; done
echo "-- unknown model (real backend):"
id=e12-model; rm -rf "$SP/work/$id"; step "$id"; gwstart 8961 chatgpt.com; trap 'gwstop 8961' EXIT
runx "$id" "$SP/p-pong.txt" 8961 exec --json --skip-git-repo-check -s read-only -m no-such-model-xyz "${HYG[@]}"; python3 -I "$C/summarize.py" "$SP/$id.out" | grep ' err:' | tail -1 | cut -c1-200
echo "-- unsupported effort for the model (real backend):"
id=e12-effort; rm -rf "$SP/work/$id"; step "$id"
runx "$id" "$SP/p-pong.txt" 8961 "${EX[@]}" -c model_reasoning_effort=ultra; python3 -I "$C/summarize.py" "$SP/$id.out" | grep -E ' err:| msg:' | tail -1 | cut -c1-200; tail -1 "$SP/$id.err" | cut -c1-200
echo "-- sandbox denial through the shell tool (write outside repo/):"
id=e12-denial; rm -rf "$SP/work/$id"; step "$id"; s=$SP/work/$id
echo "Use your shell tool to run exactly: sh -c 'echo x > ../OUTSIDE-TEST' ; then reply with the exit code." > "$SP/p-denial.txt"
XSB="$C/shell.sb" runx "$id" "$SP/p-denial.txt" 8961 exec --json --skip-git-repo-check -s danger-full-access -c 'approval_policy="never"' -m gpt-5.6-luna -c model_reasoning_effort=low "${HYG[@]}" --disable multi_agent
python3 -I "$C/summarize.py" "$SP/$id.out" | grep ' cmd:' | tail -1 | cut -c1-260
echo "-- sandbox denial through apply_patch (write into repo/ without shell.sb):"
id=e12-den-patch; rm -rf "$SP/work/$id"; step "$id"; s=$SP/work/$id
echo "Use the apply_patch tool to create the file $s/repo/denied-test.txt containing the single line hello. Then reply with exactly what the tool reported, in one line." > "$SP/p-denpatch.txt"
runx "$id" "$SP/p-denpatch.txt" 8961 exec --json --skip-git-repo-check -s danger-full-access -c 'approval_policy="never"' -m gpt-5.6-luna -c model_reasoning_effort=low "${HYG[@]}" --disable shell_tool --disable multi_agent
python3 -I "$C/summarize.py" "$SP/$id.out" | grep -E 'file_change|msg:' | sed "s#$SP#SP#g" | cut -c1-230; echo "  file created: $([ -e "$s/repo/denied-test.txt" ] && echo yes || echo no); stderr: $(grep -c 'Operation not permitted' "$SP/$id.err") line(s) with Operation not permitted"
echo "-- invalid output: the worker is asked for prose, the harness expects JSON in -o:"
id=e12-invalid; rm -rf "$SP/work/$id"; step "$id"; s=$SP/work/$id
runx "$id" "$SP/p-pong.txt" 8961 "${EX[@]}" -o "$s/io/out/last.txt"; echo "  -o file content is JSON: $(python3 -c "import json;json.load(open('$s/io/out/last.txt'));print('yes')" 2>/dev/null || echo no); result.json present: $([ -e "$s/io/out/result.json" ] && echo yes || echo no)"
echo "-- timeout (wall clock 25 s, shell tool sleeps 60 s):"
id=e12-timeout; rm -rf "$SP/work/$id"; step "$id"; s=$SP/work/$id
echo "Use your shell tool to run exactly: sh -c 'sleep 60' LSFMARK_E12T_$$ ; then reply with the single word: finished" > "$SP/p-sleep.txt"
t0=$(date +%s); perl -e 'alarm 25; exec @ARGV' "$R" --step "$s" --port 8961 --env CODEX_CA_CERTIFICATE=$CA --mach $LI --extra-sb "$C/shell.sb" --extra-sb "$C/kill.sb" -- exec --json --skip-git-repo-check -s danger-full-access -c 'approval_policy="never"' -m gpt-5.6-luna -c model_reasoning_effort=low "${HYG[@]}" --disable multi_agent < "$SP/p-sleep.txt" > "$SP/$id.out" 2> "$SP/$id.err"
echo "  rc=$? secs=$(( $(date +%s)-t0 )) events=$(types "$SP/$id.out")"; pkill -f "LSFMARK_E12T_$$" 2>/dev/null   # kills only this run's marked sh; a stray `sleep 60` child ends by itself after 60 s
