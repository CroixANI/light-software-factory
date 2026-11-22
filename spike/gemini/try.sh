#!/bin/bash
# usage: try.sh <step> <seconds> <run-agy args before --> -- <agy args>  ; prints rc, stdout/stderr heads, new gateway lines and the head of cli.log errors
# no `set -e`: the greps below legitimately find nothing; arguments and the gateway log are checked explicitly
set -uo pipefail
[ $# -ge 3 ] || { echo "usage: try.sh <step-dir> <seconds> <run-agy args> -- <agy args>" >&2; exit 2; }
here="$(cd "$(dirname "$0")" && pwd)"; step=$1; secs=$2; shift 2
[ -d "$step/tmp" ] && [[ "$secs" =~ ^[0-9]+$ ]] || { echo "bad step dir or seconds" >&2; exit 2; }
G=${GW_LOG:-$HOME/.factory-spike/gw-8931.log}
[ -f "$G" ] || { echo "gateway log $G not found (start connect-proxy.mjs first)" >&2; exit 2; }
n0=$(wc -l < "$G")
/usr/bin/perl -e 'alarm shift; exec @ARGV' "$secs" "$here/run-agy.sh" --step "$step" "$@" </dev/null > "$step/tmp/o.out" 2> "$step/tmp/o.err"; echo "rc=$?"
echo "--stdout"; head -c ${OUTMAX:-600} "$step/tmp/o.out" | sed -E 's#https://accounts[^ ]*#<url>#; s/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+/<email>/g; s/(ya29\.|1\/\/|eyJ)[A-Za-z0-9._-]+/<r>/g'; echo; echo "--stderr"; head -c 600 "$step/tmp/o.err" | sed -E 's#https://accounts[^ ]*#<url>#; s/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+/<email>/g'; echo
echo "--gateway"; tail -n +$((n0+1)) "$G" | grep -E '"ev":"(open|denied|refused)"' | sed -E 's/.*"host":"([^"]*)","port":([0-9]+).*/\1:\2/' | sort | uniq -c
echo "--cli.log E/W"; grep -E "^[EW][0-9]" "$step/home/.gemini/antigravity-cli/cli.log" 2>/dev/null | grep -v -E "token source|not logged" | sed -E "s/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+/<email>/g" | cut -c1-230 | head -${LOGMAX:-8}
