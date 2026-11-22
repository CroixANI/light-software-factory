#!/bin/bash
# Spike 3.4 E9 throwaway (needs_context re-issue). Call 1 edits repo/ and writes a needs_context result; the harness DISCARDS the Step folder and rebuilds a fresh one (empty home, new credential copy, repo from the sample), adds io/in/more.txt; call 2 is a new process. Control: call 2b reuses call 1's home/ with a clean repo/.
# Usage: SP=<existing scratch dir> LSF_CODEX_DIR=... H=... R=...  part-b-e9.sh   (gateway on 8961 allowing chatgpt.com must be running)
set -u
. "$LSF_CODEX_DIR/part-b-lib.sh"
BASE=(exec --json --skip-git-repo-check -s danger-full-access -c 'approval_policy="never"' -m gpt-5.6-luna -c model_reasoning_effort=low "${HYG[@]}" --disable multi_agent --ignore-user-config --ignore-rules -c project_doc_max_bytes=0 -c skills.include_instructions=false)
rm -rf "$SP/work/e9-1" "$SP/work/e9-2" "$SP/work/e9-2b"; step e9-1; s1=$SP/work/e9-1
cat > "$SP/p-e9-1.txt" <<E2
Do these two things with your tools. 1) Append one line "MARKER-E9-ALPHA" to $s1/repo/src/calc.py. 2) Create $s1/io/out/result.json containing exactly this JSON: {"schema":"fake-result/1","status":"needs_context","summary":"need more input","role_shape":"builder","needs_context":[{"kind":"file","ref":"io/in/more.txt","why":"missing input"}]}. Then reply with the single word: done
E2
XSB="$LSF_CODEX_DIR/shell.sb" runx e9-1 "$SP/p-e9-1.txt" 8961 "${BASE[@]}" >/dev/null; echo "call 1: result.json $(python3 -I "$H/fake-cli/validate.py" "$s1/io/out/result.json"); marker in calc.py: $(grep -c MARKER-E9-ALPHA "$s1/repo/src/calc.py")"
echo "state left in home/.codex after call 1: $(cd "$s1/home/.codex" && ls | tr '\n' ' ')"; echo "state in tmp/ after call 1: $(ls "$s1/tmp" | tr '\n' ' ')"
# harness discard + rebuild (the recommended procedure: no git or other tool is run inside the worker-touched copy)
step e9-2; s2=$SP/work/e9-2; echo "MORE-INPUT-E9: the answer is 42." > "$s2/io/in/more.txt"
cat > "$SP/p-e9-2.txt" <<E2
Read $s2/io/in/more.txt with your shell tool and put its content into the "summary" of $s2/io/out/result.json, which must be exactly one JSON object {"schema":"fake-result/1","status":"done","summary":"<content>","role_shape":"builder"}. Also: if you remember adding a MARKER line to src/calc.py in an earlier session, put its text in "notes" of that JSON, otherwise put NO-MEMORY in "notes" (then the object has the extra key "notes"). Reply with the single word: done
E2
XSB="$LSF_CODEX_DIR/shell.sb" runx e9-2 "$SP/p-e9-2.txt" 8961 "${BASE[@]}" --ephemeral >/dev/null
echo "call 2 (fresh Step, --ephemeral): $(python3 -I "$H/fake-cli/validate.py" "$s2/io/out/result.json"); marker in calc.py: $(grep -c MARKER-E9-ALPHA "$s2/repo/src/calc.py"); notes=$(python3 -c "import json;print(json.load(open('$s2/io/out/result.json')).get('notes'))")"; echo "  call 2 home/.codex has sessions: $(find "$s2/home/.codex/sessions" -name '*.jsonl' 2>/dev/null | wc -l | tr -d ' ') rollout file(s)"
# control: same home/ as call 1, repo/ restored from the sample, no --ephemeral
step e9-2b; s2b=$SP/work/e9-2b; rm -rf "$s2b/home"; cp -cR "$s1/home" "$s2b/home"; echo "MORE-INPUT-E9: the answer is 42." > "$s2b/io/in/more.txt"
sed "s#$s2#$s2b#g" "$SP/p-e9-2.txt" > "$SP/p-e9-2b.txt"
XSB="$LSF_CODEX_DIR/shell.sb" runx e9-2b "$SP/p-e9-2b.txt" 8961 "${BASE[@]}" >/dev/null
echo "call 2b (call 1's home/ reused): $(python3 -I "$H/fake-cli/validate.py" "$s2b/io/out/result.json"); notes=$(python3 -c "import json;print(json.load(open('$s2b/io/out/result.json')).get('notes'))"); rollout files in home now: $(find "$s2b/home/.codex/sessions" -name '*.jsonl' | wc -l | tr -d ' ')"
