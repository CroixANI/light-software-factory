#!/bin/bash
# Spike 3.6 E11 harness side (same procedure as spike/codex/e11-kill.sh): kill procedure of ADR-005 §7 applied to a running Step. Usage: e11-kill.sh <root-pid> <gateway-pid> <probe-log> <run-tag>
# NOTE: run the launcher in its own process group (perl -e 'setpgrp(0,0); exec @ARGV'); killing groups of an inherited group would hit the caller. 1 snapshot descendants of <root-pid> (ppid walk) + their process groups; 2 TERM to groups and pids; 3 wait 10 s; 4 KILL; 5 scan survivors by marker (LSFMARK_*);
# 6 close the gateway port (deliberately BEFORE the marker kill here, to see whether survivors keep network; ADR-005 §7 order is the reverse); 7 kill marker survivors. Prints what each stage found. Touches only the pids it derived.
root=$1; gw=$2; probe=$3; tag=${4:?tag}
desc(){ local out=$1; for p in $(ps -axo pid=,ppid= | awk -v r="$1" '$2==r{print $1}'); do out="$out $(desc $p)"; done; echo $out; }
tracked=$(desc "$root"); groups=$(ps -o pgid= -p $(echo $tracked | tr ' ' ',') | sort -u | tr '\n' ' ')
echo "tracked pids: $tracked | groups: $groups"
scan(){ ps -axo pid=,ppid=,pgid=,command= | grep "LSFMARK_${tag}_" | grep -v grep | grep -v e11-kill | grep -E 'perl|sleep' | cut -c1-80; }
echo "marker scan before kill:"; scan
for g in $groups; do kill -TERM -- -$g 2>/dev/null; done; for p in $tracked; do kill -TERM $p 2>/dev/null; done
sleep 10
echo "after TERM+10 s, marker scan:"; scan
for g in $groups; do kill -KILL -- -$g 2>/dev/null; done; for p in $tracked; do kill -KILL $p 2>/dev/null; done
sleep 1; echo "after KILL of tracked set (group+pid), marker survivors:"; scan
kill -TERM "$gw"; sleep 1; echo "gateway closed at $(date +%s)"
echo "marker survivors still alive 3 s after gateway close:"; sleep 3; scan
echo "probe log tail:"; tail -4 "$probe" 2>/dev/null
for p in $(scan | awk '{print $1}'); do kill -KILL $p; done; sleep 1; echo "after marker-scan KILL:"; scan; echo "(end)"
