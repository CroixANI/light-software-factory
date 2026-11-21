#!/bin/bash
# Spike throwaway (task 2.1): S1 (reads denied) and S2 (no IPC route) under the task-1.4 Seatbelt profiles, both shapes.
# Usage: spike/sandbox/s1-s2/run.sh   (env SANDBOX_DIR=<patched copy of spike/harness/sandbox>, RESULTS_NAME=<dir> for the mitigation re-run)
#   Output: results/<shape>/*.json + results/baseline/*.json (paths sanitised: <home>, <work>).
# Needs: macOS, python3, the repo's spike/harness. Creates spike/work/s1-s2 (git-ignored), leaves nothing running.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd -P)"; SB="${SANDBOX_DIR:-}"; H="$here/../../harness"; H="$(cd "$H" && pwd -P)"
[ -n "$SB" ] || SB="$H/sandbox"; RES="${RESULTS_NAME:-results}"
W="$(cd "$here/../.." && pwd -P)/work/s1-s2"
case "$W" in */spike/work/s1-s2) rm -rf "$W";; *) echo "unexpected work dir" >&2; exit 2;; esac
mkdir -p "$W"
A="$("$H/build-step-folder.sh" step-a "$W")"; B="$("$H/build-step-folder.sh" step-b "$W")"; C="$("$H/build-step-folder.sh" step-base "$W")"
A="$(cd "$A" && pwd -P)"; B="$(cd "$B" && pwd -P)"; C="$(cd "$C" && pwd -P)"
mkdir -p "$W/factory-state"; chmod 700 "$W/factory-state"
echo '{"canary":"factory-state-canary"}' > "$W/factory-state/state.json"; echo "cred-canary" > "$W/factory-state/credential-canary"
echo "step-b-secret-canary" > "$B/home/notes.txt"
CANARY_ENV="canary-env-$$-$RANDOM"; CANARY_ARG="canary-arg-$$-$RANDOM"
# Orchestrator stand-in: an owner process outside the sandbox with a secret in its environment and in its argv.
orch() { FACTORY_CANARY_SECRET="$CANARY_ENV" python3 -c 'import time; time.sleep(600)' "$CANARY_ARG" >/dev/null 2>&1 </dev/null & echo $!; }
PORT=8901   # no listener: S1/S2 need no network; the profile only needs a port number
out="$here/$RES"; rm -rf "$out"; mkdir -p "$out"
REPO="$(cd "$H/../.." && pwd -P)"
sanitize() { sed -e "s#$W#<work>#g" -e "s#$REPO#<repo>#g" -e "s#$HOME#<home>#g" -e "s#$(id -un)#<user>#g"; }

READS=( "read-ssh=$HOME/.ssh" "read-zshrc=$HOME/.zshrc" "read-gh-config=$HOME/.config/gh" "read-keychain=$HOME/Library/Keychains/login.keychain-db"
        "read-path=/Library/Keychains/System.keychain" "read-path=$B" "read-path=$B/home/notes.txt" "read-path=$W/factory-state" "read-path=$W/factory-state/credential-canary"
        "read-path=$HOME/Documents" "read-path=$H" )
runshape() { # shape step outdir
  local shape=$1 S=$2 o=$3 orchpid; mkdir -p "$o"; rm -f "$S/io/out/"*
  orchpid=$(orch); sleep 1
  local atk=(); for r in "${READS[@]}" "read-path=$S/home" "read-path=$S/io/out"; do atk+=(--attack "$r"); done
  atk+=(--attack launchctl-submit --attack open-terminal --attack osascript --attack "kill-orchestrator=$orchpid" --attack "ps-eww=$orchpid")
  echo "prompt" | "$SB/run-sandboxed.sh" --shape "$shape" --step "$S" --port $PORT --cli-dir "$H/fake-cli" -- \
      python3 "$H/fake-cli/fake-cli.py" --shape "$shape" --step "$S" "${atk[@]}" >/dev/null 2>"$o/fake-cli.stderr"; echo $? > "$o/fake-cli.exit"
  cp "$S/io/out/attacks.json" "$o/attacks.json" 2>/dev/null; cp "$S/io/out/result.json" "$o/result.json" 2>/dev/null; python3 "$H/fake-cli/validate.py" "$S/io/out/result.json" > "$o/result-valid.txt" 2>&1
  "$SB/run-sandboxed.sh" --shape "$shape" --step "$S" --port $PORT --cli-dir "$here" -- \
      python3 "$here/extra.py" --orch-pid "$orchpid" --canary-env "$CANARY_ENV" --canary-arg "$CANARY_ARG" --out "$S/io/out/extra.json" >/dev/null 2>"$o/extra.stderr"; echo $? > "$o/extra.exit"
  cp "$S/io/out/extra.json" "$o/extra.json" 2>/dev/null
  # builder only: the same exec attacks through a shell, by absolute path
  if [ "$shape" = builder ]; then
    for cmd in "/bin/launchctl list" "/usr/bin/open -g -j -a Terminal" "/usr/bin/osascript -e 'return 1'" "/bin/ps eww -p $orchpid" "/usr/bin/security list-keychains" "/bin/kill -0 $orchpid"; do
      "$SB/run-sandboxed.sh" --shape builder --step "$S" --port $PORT --cli-dir "$H/fake-cli" -- /bin/sh -c "$cmd" >"$o/sh.out" 2>&1; echo "rc=$? :: $cmd :: $(head -c 200 "$o/sh.out" | tr '\n' ' ')" >> "$o/shell-attacks.txt"
    done; rm -f "$o/sh.out"
  fi
  if kill -0 "$orchpid" 2>/dev/null; then echo "orchestrator stand-in alive after the run" > "$o/orchestrator-after.txt"; else echo "orchestrator stand-in was KILLED by the worker" > "$o/orchestrator-after.txt"; fi
  kill "$orchpid" 2>/dev/null; wait "$orchpid" 2>/dev/null
}
runshape reviewer-readonly "$A" "$out/reviewer-readonly"
runshape builder "$C" "$out/builder"

# Baseline: the same probes WITHOUT the sandbox (shows that targets exist / calls work, so a denial above is the profile's doing).
mkdir -p "$out/baseline"; orchpid=$(orch); sleep 1
python3 "$here/extra.py" --orch-pid "$orchpid" --canary-env "$CANARY_ENV" --canary-arg "$CANARY_ARG" --out "$out/baseline/extra.json"
kill -0 "$orchpid" 2>/dev/null && echo alive > "$out/baseline/orchestrator-after.txt" || echo "KILLED (expected: baseline SIGTERM works)" > "$out/baseline/orchestrator-after.txt"
bl=(); for r in "${READS[@]}"; do bl+=(--attack "$r"); done
mkdir -p "$B/io/out"; rm -f "$B/io/out/"*
echo p | python3 "$H/fake-cli/fake-cli.py" --shape builder --step "$B" "${bl[@]}" >/dev/null 2>&1; cp "$B/io/out/attacks.json" "$out/baseline/attacks.json"
{ for cmd in "launchctl help" "open" "osascript -e 'return 1'" "ps eww -p $$" "security list-keychains"; do bash -c "$cmd" >/dev/null 2>&1; echo "rc=$? :: $cmd"; done; } > "$out/baseline/shell-controls.txt"
wait 2>/dev/null
find "$out" -type f \( -name '*.json' -o -name '*.txt' -o -name '*.stderr' -o -name '*.exit' \) -print0 | while IFS= read -r -d '' f; do sanitize < "$f" > "$f.tmp" && mv "$f.tmp" "$f"; done
echo "done: $out"
