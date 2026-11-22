#!/bin/bash
# Spike 3.4 S1-S5 re-run with codex as the worker: the codex shell tool runs s1s5.sh under base.sb + codex.sb + shell.sb + kill.sb + s5.sb. Content-free log: rc + `denied` or a byte count.
# Usage: SP=<existing scratch dir> LSF_CODEX_DIR=... H=... R=...  part-b-s1s5.sh   (gateways: 8961 allowing chatgpt.com must run as the "sibling Step's gateway"; this script starts 8972 for the Step itself)
set -u
. "$LSF_CODEX_DIR/part-b-lib.sh"; C=$LSF_CODEX_DIR
NODEBIN=$(dirname "$(readlink -f "$(command -v node)")"); NODEROOT=$(dirname "$NODEBIN")
gwstart 8972 chatgpt.com
id=s1s5; rm -rf "$SP/work/$id" "$SP/work/s1s5-other"; step "$id"; step s1s5-other; s=$SP/work/$id; cp "$C/s1s5.sh" "$s/tmp/s1s5.sh"
sleep 400 & OPID=$!
trap 'kill $OPID 2>/dev/null; /bin/launchctl remove lsf.spike 2>/dev/null; gwcleanup' EXIT   # launchctl remove runs OUTSIDE the sandbox and only removes the label s1s5.sh submits (a leftover job if the profile ever failed to block `launchctl submit`)
cat > "$SP/p-s1s5.txt" <<E2
Use your shell tool to run exactly this one command: sh $s/tmp/s1s5.sh $s $HOME $SP/work/s1s5-other $OPID 8961 $NODEBIN
Then reply with the single word: finished
E2
XENV=(--env OWNP=8972 --node-root "$NODEROOT")
XSB="$C/shell.sb $C/kill.sb $C/s5.sb" runx "$id" "$SP/p-s1s5.txt" 8972 exec --json --skip-git-repo-check -s danger-full-access -c 'approval_policy="never"' -m gpt-5.6-luna -c model_reasoning_effort=low "${HYG[@]}" --disable multi_agent --ignore-user-config --ignore-rules -c project_doc_max_bytes=0 -c skills.include_instructions=false
sed "s#$SP#SP#g; s#$HOME#HOME#g" "$s/io/out/s1s5.log"
