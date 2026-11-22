#!/bin/bash
# Spike 3.5 throwaway: write the authorization code from a secret file into the login FIFO of a Step. Prints nothing about the code.
# Usage: feed-code.sh <step> <secret-file>
set -eu
step="$(cd "$1" && pwd -P)"; [ -p "$step/tmp/login.fifo" ] || { echo "no login fifo (agy not waiting)" >&2; exit 1; }
pgrep -f "acp --login" >/dev/null || { echo "no agy login process is running; code not fed" >&2; exit 1; }
[ -s "$2" ] || { echo "secret file empty" >&2; exit 1; }
{ tr -d '\r\n' < "$2"; echo; } > "$step/tmp/login.fifo"; echo "code_fed bytes=$(tr -d '\r\n' < "$2" | wc -c | tr -d ' ')"
