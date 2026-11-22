# Spike 3.6 throwaway helpers (source me). Needs: SP (NEW scratch dir outside the repo), LSF_GEMINI_DIR (spike/gemini), H (spike/harness).
# Every run uses the mock model endpoint (mock-api.mjs, agy's enterprise-gateway route: no login, no quota) unless a script says otherwise.
# mockstart <port> <spec> [dumpdir] : start mock-api.mjs (spec = status:<n> or a scenario file); mockstop <port>; cleanup stops only what this shell started (EXIT trap)
# gwstart <port> [allow] / gwstop <port> : connect-proxy.mjs for the Step gateway (E11)
# stepnew <id> : fresh Step folder under $SP/work (build-step-folder.sh); then rm -rf of the id first if it exists
# runa <id> <port> <seconds> <prompt-file|-> <run-agy extra args...> -- <agy args...> : with-timeout.pl + run-agy.sh with the mock route env; stdout -> $SP/<id>.out, stderr -> $SP/<id>.err; echo rc
: "${SP:?set SP to a NEW scratch directory outside the repository}"; : "${LSF_GEMINI_DIR:?}"; : "${H:?}"
case "$SP" in /*) ;; *) echo "SP must be an absolute path" >&2; exit 2;; esac
SP="${SP%/}"; [ -n "$SP" ] || { echo "SP is empty after removing the trailing slash" >&2; exit 2; }
# canonical path (symlinks resolved): the directory itself if it exists, else its existing parent plus the last name
if [ -d "$SP" ]; then SP="$(cd "$SP" && pwd -P)"; elif [ -d "$(dirname "$SP")" ]; then SP="$(cd "$(dirname "$SP")" && pwd -P)/$(basename "$SP")"; else echo "parent of SP does not exist: $SP" >&2; exit 2; fi
case "$SP" in /|/tmp|/private|/private/tmp|/Users|"$(cd "$HOME" && pwd -P)") echo "SP is too broad: $SP" >&2; exit 2;; esac
top=$(git -C "$(dirname "$LSF_GEMINI_DIR")" rev-parse --show-toplevel 2>/dev/null) || top=
case "$SP/" in "$(pwd -P)"/*|"$([ -n "$top" ] && cd "$top" && pwd -P || echo /nonexistent)"/*) echo "SP must be outside the repository" >&2; exit 2;; esac
# an existing directory is reused only if an earlier run of these scripts made it (sentinel, as in spike/codex/part-b-lib.sh)
if [ -e "$SP" ] && [ ! -f "$SP/.lsf-gemini-scratch" ] && [ -n "$(ls -A "$SP" 2>/dev/null)" ]; then echo "SP exists, is not empty and was not made by these scripts: $SP" >&2; exit 2; fi
mkdir -p "$SP/work" "$SP/dump"; chmod 700 "$SP"; : > "$SP/.lsf-gemini-scratch"
G=$LSF_GEMINI_DIR; R=$G/run-agy.sh; MODEL=mock-model
X=(--mach com.apple.trustd.agent --extra-sb "$G/hosts.sb" --extra-sb "$G/lsbind.sb")
OWN=""
mockstart(){ local d=${3:-}; [ -n "$d" ] && { mkdir -p -m 700 "$d"; export MOCK_DUMP=$d; } || unset MOCK_DUMP; node "$G/mock-api.mjs" "$1" "$2" > "$SP/mock$1.log" 2>&1 < /dev/null & echo $! > "$SP/mock.$1"; OWN="$OWN m$1"; unset MOCK_DUMP; sleep 1; }
mockstop(){ [ -f "$SP/mock.$1" ] || return 0; kill -INT "$(cat "$SP/mock.$1")" 2>/dev/null; rm -f "$SP/mock.$1"; }
gwstart(){ local a=(); [ -n "${2:-}" ] && a=(--allow "$2"); node "$H/proxy/connect-proxy.mjs" --port "$1" --step "gw$1" ${a[@]+"${a[@]}"} > "$SP/gw$1.log" 2>&1 < /dev/null & echo $! > "$SP/gw.$1"; OWN="$OWN g$1"; sleep 1; }
gwstop(){ [ -f "$SP/gw.$1" ] || return 0; kill -INT "$(cat "$SP/gw.$1")" 2>/dev/null; rm -f "$SP/gw.$1"; }
cleanup(){ for o in $OWN; do case $o in m*) mockstop "${o#m}";; g*) gwstop "${o#g}";; esac; done; }
stepnew(){ rm -rf "$SP/work/$1"; "$H/build-step-folder.sh" "$1" "$SP/work" >/dev/null; }
runa(){ local id=$1 port=$2 secs=$3 pf=$4; shift 4; local ra=(); while [ $# -gt 0 ] && [ "$1" != -- ]; do ra+=("$1"); shift; done; shift
  [ "$pf" = - ] && pf=/dev/null
  "$G/with-timeout.pl" "$secs" "$R" --step "$SP/work/$id" --port "$port" "${X[@]}" --env "AGY_LLM_GATEWAY_URL=http://127.0.0.1:$port" --env AGY_LLM_GATEWAY_API_KEY=fake --env "AGY_LLM_GATEWAY_MODELS=$MODEL" ${ra[@]+"${ra[@]}"} -- "$@" < "$pf" > "$SP/$id.out" 2> "$SP/$id.err"; echo "$id rc=$?"; }
