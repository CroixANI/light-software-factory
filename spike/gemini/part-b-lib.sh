# Spike 3.6 throwaway helpers (source me). Needs: SP (NEW scratch dir outside the repo), LSF_GEMINI_DIR (spike/gemini), H (spike/harness).
# Every run uses the mock model endpoint (mock-api.mjs, agy's enterprise-gateway route: no login, no quota) unless a script says otherwise.
# mockstart <port> <spec> [dumpdir] : start mock-api.mjs (spec = status:<n> or a scenario file); mockstop <port>; cleanup stops only what this shell started (EXIT trap)
# gwstart <port> [allow] / gwstop <port> : connect-proxy.mjs for the Step gateway (E11)
# stepnew <id> : fresh Step folder under $SP/work (build-step-folder.sh); then rm -rf of the id first if it exists
# runa <id> <port> <seconds> <prompt-file|-> <run-agy extra args...> -- <agy args...> : with-timeout.pl + run-agy.sh with the mock route env; stdout -> $SP/<id>.out, stderr -> $SP/<id>.err; echo rc
: "${SP:?set SP to a NEW scratch directory outside the repository}"; : "${LSF_GEMINI_DIR:?}"; : "${H:?}"
case "$SP" in "$PWD"/*|*/light-software-factory/*) echo "SP must be outside the repository" >&2; exit 2;; esac
mkdir -p "$SP/work" "$SP/dump"; chmod 700 "$SP"
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
