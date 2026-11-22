#!/bin/bash
# Spike 3.6 E11 (kill and escape). Mock model (no login): its scripted turn makes agy's own terminal tool run e11-spawn.sh (nohup, setsid, double fork, setsid + double fork + CONNECT probe against the Step gateway port).
# The mock process doubles as the Step gateway port (it answers CONNECT with 200; stopping it closes the port). Then the harness applies e11-kill.sh (ADR-005 §7) to the running Step.
# Usage: SP=<new scratch dir> LSF_GEMINI_DIR=... H=... bash part-b-e11.sh
set -u
. "$LSF_GEMINI_DIR/part-b-lib.sh"; trap 'pkill -KILL -f "LSFMARK_$$_" 2>/dev/null; [ -n "${root:-}" ] && kill -TERM -- "-$root" 2>/dev/null; cleanup' EXIT
id=e11; rm -rf "$SP/dump/$id"; stepnew $id; S=$SP/work/$id; cp "$G/e11-spawn.sh" "$S/tmp/e11-spawn.sh"
cat > "$SP/sc-$id.json" <<J
[{"call":{"name":"run_command","args":{"CommandLine":"sh $S/tmp/e11-spawn.sh $S/tmp 8913 $$","toolSummary":"spawn","WaitMsBeforeAsync":120000}}},{"text":"finished"}]
J
mockstart 8913 "$SP/sc-$id.json" "$SP/dump/$id"; mockpid=$(cat "$SP/mock.8913")
echo go > "$SP/p.txt"
perl -e 'setpgrp(0,0); exec @ARGV' "$R" --step "$S" --port 8913 "${X[@]}" --extra-sb "$G/shell.sb" --extra-sb "$G/pty.sb" --extra-sb "$G/kill.sb" --env "AGY_LLM_GATEWAY_URL=http://127.0.0.1:8913" --env AGY_LLM_GATEWAY_API_KEY=fake --env "AGY_LLM_GATEWAY_MODELS=$MODEL" -- --output-format json --dangerously-skip-permissions --settings '{"enableTerminalSandbox":false}' --model $MODEL < "$SP/p.txt" > "$SP/$id.out" 2> "$SP/$id.err" &
root=$!; sleep 40
echo "process tree before the kill (pid ppid pgid sid-leader?, marker or binary name):"
ps -axo pid=,ppid=,pgid=,sess=,tty=,command= | grep -E "LSFMARK_$$|e11-spawn|bin/agy|agy --output" | grep -v grep | awk '{printf "  %s %s %s tty=%s %s %s\n",$1,$2,$3,$5,$6,$7}' | sed 's#/[^ ]*/##' | cut -c1-110
echo "probe lines before the kill: $(grep -c 'reply:HTTP/1.1 200' "$S/tmp/probe.log")"
bash "$G/e11-kill.sh" "$root" "$mockpid" "$S/tmp/probe.log" $$ 2>&1 | cut -c1-120
wait $root 2>/dev/null; echo "launcher exit after the kill: $?"; echo "leftover LSFMARK processes: $(pgrep -f "LSFMARK_$$" | wc -l | tr -d ' ')"
echo "agy stdout after kill: $(head -c 250 "$SP/$id.out")"
