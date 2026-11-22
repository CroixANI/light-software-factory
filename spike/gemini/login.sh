#!/bin/bash
# Spike 3.5 throwaway: log agy in INSIDE a Seatbelt Step (isolated HOME, Keychain and `open` denied). Nothing is copied from the owner's login.
# Starts `agy acp --login`, keeps its stdin open on a FIFO, saves the login URL to <step>/tmp/login.url and waits (max <wait-seconds>) for agy to exit.
# The authorization code is fed by feed-code.sh from a 0600 secret file (never argv, never echoed).
# Usage: login.sh <step> <port> <wait-seconds>
set -u
here="$(cd "$(dirname "$0")" && pwd)"; step=$1; port=$2; waits=${3:-600}
step="$(cd "$step" && pwd -P)"; fifo="$step/tmp/login.fifo"; rm -f "$fifo"; mkfifo -m 600 "$fifo"
exec 7<>"$fifo"
"$here/run-agy.sh" --step "$step" --port "$port" --mach com.apple.trustd.agent --extra-sb "$here/hosts.sb" --extra-sb "$here/lsbind.sb" -- acp --login <&7 >"$step/tmp/login.out" 2>"$step/tmp/login.err" &
pid=$!
for i in $(seq 1 30); do grep -q "oauth2/auth" "$step/tmp/login.err" "$step/tmp/login.out" 2>/dev/null && break; kill -0 $pid 2>/dev/null || break; sleep 1; done
grep -h -o "https://accounts.google.com/o/oauth2/auth[^ ]*" "$step/tmp/login.err" "$step/tmp/login.out" 2>/dev/null | head -1 > "$step/tmp/login.url"
echo "url_saved_bytes=$(wc -c < "$step/tmp/login.url") agy_alive=$(kill -0 $pid 2>/dev/null && echo yes || echo no)"
for i in $(seq 1 "$waits"); do kill -0 $pid 2>/dev/null || break; sleep 1; done
kill -0 $pid 2>/dev/null && { kill $pid; echo "agy_killed_after_wait"; }
wait $pid 2>/dev/null; echo "agy_rc=$?"
for f in out err; do echo "--- $f (token-like strings and URL redacted)"; sed -E 's/(ya29\.|1\/\/|eyJ)[A-Za-z0-9._-]+/<r>/g; s/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+/<email>/g; s#https://accounts[^ ]*#<url>#' "$step/tmp/login.$f" | head -c 1200; done
rm -f "$fifo"
