#!/bin/bash
# Spike 3.6 E9 (+E6 file route, E10 no shell): `needs_context` re-issue. Mock model (no login); the scripted worker writes through agy's own file tools, so no shell is needed
# (call 1 = builder shape: shell.sb carries the repo/ write rule, no shell is started; call 2 = reviewer-readonly profile, agy.sb + base.sb only, so repo/ is read-only and a write to it fails; that is also the E10 run). Permissions: allow rules, no --dangerously-skip-permissions.
# Call 1 appends a marker to repo/src/calc.py and writes result.json with status needs_context. Harness: discard the Step folder and rebuild it fresh (no git or tool run inside the touched copy), add io/in/more.txt.
# Call 2 (new process, fresh Step): reads more.txt, writes a done result. Checks: result validates, the model request of call 2 holds no marker and a single turn (no state carried), state left in home/ after call 1.
# Control 2b: call 1's home/ reused with a clean repo, without and with --continue.
# Usage: SP=<new scratch dir> LSF_GEMINI_DIR=... H=... bash part-b-e9.sh
set -u
. "$LSF_GEMINI_DIR/part-b-lib.sh"; trap cleanup EXIT
V=$H/fake-cli/validate.py; SCH=$H/fake-cli/result.schema.json
rules(){ S=$1; echo "{\"enableTerminalSandbox\":false,\"permissions\":{\"allow\":[\"read_file($S)\",\"write_file($S/io/out)\",\"write_file($S/repo)\",\"edit_file($S/repo)\"]}}"; }
echo "do the task" > "$SP/p.txt"
NEEDS='{\"schema\":\"fake-result/1\",\"status\":\"needs_context\",\"summary\":\"need more\",\"role_shape\":\"builder\",\"needs_context\":[{\"kind\":\"file\",\"ref\":\"io/in/more.txt\",\"why\":\"missing detail\"}]}'
DONE='{\"schema\":\"fake-result/1\",\"status\":\"done\",\"summary\":\"used more.txt\",\"role_shape\":\"builder\"}'
rm -rf "$SP/dump/e9-c1" "$SP/dump/e9-c2"; stepnew e9-c1; S1=$SP/work/e9-c1
cat > "$SP/sc-e9-c1.json" <<J
[{"calls":[{"name":"read_file","args":{"Path":"$S1/repo/src/calc.py"}},{"name":"write_file","args":{"Path":"$S1/repo/src/calc.py","Content":"# MARKER-FROM-CALL-1\n","Append":true}},{"name":"write_file","args":{"Path":"$S1/io/out/result.json","Content":"$NEEDS","Overwrite":true}}]},{"text":"needs context"}]
J
mockstart 8913 "$SP/sc-e9-c1.json" "$SP/dump/e9-c1"
runa e9-c1 8913 60 "$SP/p.txt" --extra-sb "$G/shell.sb" -- --output-format json --settings "$(rules "$S1")" --model $MODEL
echo "call 1: $(head -c 300 "$SP/e9-c1.out" | sed 's/"conversation_id":"[^"]*",//')"
echo "call 1 result.json: $(cat "$S1/io/out/result.json" 2>/dev/null | head -c 200)"; python3 -I "$V" "$S1/io/out/result.json" "$SCH" | head -2
echo "marker in call-1 calc.py: $(grep -c MARKER-FROM-CALL-1 "$S1/repo/src/calc.py")"
echo "state left in home/ after call 1 (names, depth 3):"; (cd "$S1/home" && find . -maxdepth 3 \( -type f -o -type d \) | sed 's#^\./##' | grep -v '^$' | sort | head -40)
echo "tmp/ after call 1: $(ls "$S1/tmp" | tr '\n' ' ')"
mockstop 8913; sleep 1
# harness: discard, rebuild fresh, add input
stepnew e9-c2; S2=$SP/work/e9-c2; echo "MORE-CONTEXT-DETAIL" > "$S2/io/in/more.txt"
cat > "$SP/sc-e9-c2.json" <<J
[{"calls":[{"name":"read_file","args":{"Path":"$S2/io/in/more.txt"}},{"name":"write_file","args":{"Path":"$S2/io/out/result.json","Content":"$DONE","Overwrite":true}}]},{"text":"done"}]
J
mockstart 8913 "$SP/sc-e9-c2.json" "$SP/dump/e9-c2"
runa e9-c2 8913 60 "$SP/p.txt" -- --output-format json --settings "$(rules "$S2")" --model $MODEL
echo "call 2: $(head -c 300 "$SP/e9-c2.out" | sed 's/"conversation_id":"[^"]*",//')"
python3 -I "$V" "$S2/io/out/result.json" "$SCH" | head -2; echo "status in call-2 result: $(python3 -I -c "import json,sys;print(json.load(open(sys.argv[1]))['status'])" "$S2/io/out/result.json" 2>&1)"
echo "call-2 request 1: $(python3 -I "$G/bodyinfo.py" "$SP/dump/e9-c2/req-1.bin" | tail -1); marker strings in all call-2 requests: $(cat "$SP/dump"/e9-c2/req-*.bin | grep -c MARKER-FROM-CALL-1)"
echo "call-2 read of more.txt reached the model: $(cat "$SP/dump"/e9-c2/req-2.bin | grep -c MORE-CONTEXT-DETAIL)"
echo "marker in call-2 calc.py: $(grep -c MARKER-FROM-CALL-1 "$S2/repo/src/calc.py")"
mockstop 8913; sleep 1
# control 2b: call 1's home reused (clean repo), without and with --continue
for mode in plain continue; do
  id=e9-2b-$mode; rm -rf "$SP/dump/$id" "$SP/work/$id"; stepnew "$id"; S3=$SP/work/$id; rm -rf "$S3/home"; cp -R "$S1/home" "$S3/home"
  echo '[{"text":"ok"}]' > "$SP/sc-$id.json"; mockstart 8913 "$SP/sc-$id.json" "$SP/dump/$id"
  extra=(); [ $mode = continue ] && extra=(--continue)
  runa "$id" 8913 60 "$SP/p.txt" -- --output-format json ${extra[@]+"${extra[@]}"} --model $MODEL
  echo "2b-$mode: contents in request 1 = $(python3 -I "$G/bodyinfo.py" "$SP/dump/$id/req-1.bin" | tail -1 | sed 's/bytes.*//'); marker strings = $(cat "$SP/dump/$id/req-1.bin" | grep -c MARKER-FROM-CALL-1)"
  mockstop 8913; sleep 1
done
# control 2c: same Step path and home as call 1 (repo file restored by overwriting), with --continue: does the conversation come back?
id=e9-2c; rm -rf "$SP/dump/$id"; cp "$H/sample-repo/src/calc.py" "$S1/repo/src/calc.py"
echo '[{"text":"ok"}]' > "$SP/sc-$id.json"; mockstart 8913 "$SP/sc-$id.json" "$SP/dump/$id"
"$G/with-timeout.pl" 60 "$R" --step "$S1" --port 8913 "${X[@]}" --env "AGY_LLM_GATEWAY_URL=http://127.0.0.1:8913" --env AGY_LLM_GATEWAY_API_KEY=fake --env "AGY_LLM_GATEWAY_MODELS=$MODEL" -- --output-format json --continue --model $MODEL < "$SP/p.txt" > "$SP/$id.out" 2> "$SP/$id.err"; echo "$id rc=$?"
echo "2c (same path+home, --continue): contents in request 1 = $(python3 -I "$G/bodyinfo.py" "$SP/dump/$id/req-1.bin" | tail -1 | sed 's/bytes.*//'); marker strings = $(cat "$SP/dump/$id/req-1.bin" | grep -c MARKER-FROM-CALL-1)"
mockstop 8913
