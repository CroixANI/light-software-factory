#!/bin/bash
# Spike 3.6 S1-S5 re-run with agy as the worker: agy's own terminal tool (scripted mock model, no login) runs s1s5.sh under agy.sb + shell.sb + pty.sb + kill.sb + s5.sb + tokro.sb.
# Content-free log: rc + `denied` or a byte count. The Step holds a FAKE credential file (canary string) so that "the worker can read its own credential" can be shown without a real token.
# Usage: SP=<new scratch dir> LSF_GEMINI_DIR=... H=... bash part-b-s1s5.sh
set -u
. "$LSF_GEMINI_DIR/part-b-lib.sh"
NODEBIN=$(dirname "$(readlink -f "$(command -v node)")"); NODEROOT=$(dirname "$NODEBIN")
id=s1s5; rm -rf "$SP/dump/$id"; stepnew $id; stepnew s1s5-other; S=$SP/work/$id; cp "$G/s1s5.sh" "$S/tmp/s1s5.sh"
T=$S/home/.gemini/antigravity-cli; mkdir -p "$T"; echo '{"access_token":"CANARY-FAKE-ACCESS","refresh_token":"CANARY-FAKE-REFRESH","expiry":"2000-01-01T00:00:00Z"}' > "$T/antigravity-oauth-token"; chmod 600 "$T/antigravity-oauth-token"
sleep 400 & OPID=$!
trap 'kill $OPID 2>/dev/null; wait $OPID 2>/dev/null; /bin/launchctl remove lsf.spike 2>/dev/null; cleanup' EXIT   # launchctl remove runs OUTSIDE the sandbox and only removes the label s1s5.sh submits (a leftover job if the profile ever failed to block `launchctl submit`)
gwstart 8962 ""   # the "sibling Step's gateway"
cat > "$SP/sc-$id.json" <<J
[{"calls":[{"name":"run_command","args":{"CommandLine":"sh $S/tmp/s1s5.sh $S $HOME $SP/work/s1s5-other $OPID 8962 $NODEBIN 8913","toolSummary":"s1s5","WaitMsBeforeAsync":60000}},{"name":"run_command","args":{"CommandLine":"cat $T/antigravity-oauth-token","toolSummary":"cat","WaitMsBeforeAsync":5000}},{"name":"read_file","args":{"Path":"$T/antigravity-oauth-token"}},{"name":"run_command","args":{"CommandLine":"env | sed 's/=.*//' | sort > $S/io/out/env-names.txt","toolSummary":"envnames","WaitMsBeforeAsync":5000}}]},{"text":"finished"}]
J
mockstart 8913 "$SP/sc-$id.json" "$SP/dump/$id"; echo go > "$SP/p.txt"
runa $id 8913 120 "$SP/p.txt" --extra-sb "$G/shell.sb" --extra-sb "$G/pty.sb" --extra-sb "$G/kill.sb" --extra-sb "$G/s5.sb" --env GEMINI_API_KEY=CANARYFAKEKEY --node-root "$NODEROOT" --ro-token "$T/antigravity-oauth-token" -- --output-format json --dangerously-skip-permissions --settings '{"enableTerminalSandbox":false}' --model $MODEL
sed "s#$SP#SP#g; s#$HOME#HOME#g" "$S/io/out/s1s5.log"
echo "the worker's terminal tool and read_file tool read the Step's own (fake) credential file; canary occurrences in the request that carries the tool results (= what would reach the model provider): $(grep -o CANARY-FAKE-ACCESS "$SP/dump/$id/req-2.bin" | wc -l | tr -d ' ')"
echo "environment variable NAMES visible to the terminal tool: $(tr '\n' ' ' < "$S/io/out/env-names.txt")"
echo "GEMINI_API_KEY (set for agy, fake) value reached the model request: $(grep -o CANARYFAKEKEY "$SP/dump/$id/req-2.bin" | wc -l | tr -d ' ')"
