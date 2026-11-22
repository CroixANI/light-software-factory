# Spike 3.4 throwaway helpers (source me). Needs: SP (NEW scratch dir outside the repo, made by the caller), R (run-codex.sh), H (spike/harness), LSF_CODEX_DIR (spike/codex).
# Credential copies carry a DUMMY refresh token (lib.sh step); gateways allow only chatgpt.com whenever a run has a shell tool.
# gwstart <port> [allow]   : start a gateway, remember its PID in $SP/gw.<port>
# gwstop <port> ; gwcleanup stops only those started by gwstart in this shell (use it in an EXIT trap)
# runx <id> <prompt-file> <port> <codex exec args...> : run codex exec under the profile (CA + libinfo + hygiene), 120 s wall clock, stdout -> $SP/<id>.out, stderr -> $SP/<id>.err; XSB=<extra .sb>, XENV=(--env K=V ...) optional
. "$LSF_CODEX_DIR/lib.sh"
# refuse a scratch directory that is not new or not made by these scripts (part-a.sh does the same): everything below works under $SP/work only
: "${SP:?set SP to a NEW scratch directory outside the repository}"
if [ -e "$SP" ] && [ ! -f "$SP/.lsf-codex-scratch" ]; then echo "SP exists and is not a scratch dir made by these scripts: $SP" >&2; exit 2; fi
mkdir -p "$SP"; chmod 700 "$SP"; : > "$SP/.lsf-codex-scratch"
CA=/private/etc/ssl/cert.pem; LI=com.apple.system.opendirectoryd.libinfo
HYG=(--disable plugins --disable remote_plugin --disable apps --disable in_app_updates -c analytics.enabled=false)
GWOWN=""
gwstart(){ if [ -f "$SP/gw.$1" ] && kill -0 "$(cat "$SP/gw.$1")" 2>/dev/null; then [ "$(cat "$SP/gw.$1.allow" 2>/dev/null)" = "${2:-}" ] && return 0; echo "gateway on $1 runs with a different allowlist; stop it first" >&2; return 1; fi; GWOWN="$GWOWN $1"; local a=(); [ -n "${2:-}" ] && a=(--allow "$2"); node "$H/proxy/connect-proxy.mjs" --port "$1" --step "gw$1" ${a[@]+"${a[@]}"} > "$SP/gw$1.log" 2>&1 & echo $! > "$SP/gw.$1"; echo "${2:-}" > "$SP/gw.$1.allow"; sleep 1; }
gwcleanup(){ for p in $GWOWN; do gwstop "$p"; done; }   # stops only the gateways this shell started (a caller's gateway on the same port is left alone)
gwstop(){ kill -INT "$(cat "$SP/gw.$1")" 2>/dev/null; wait "$(cat "$SP/gw.$1")" 2>/dev/null; rm -f "$SP/gw.$1" "$SP/gw.$1.allow"; }
runx(){ id=$1; pf=$2; port=$3; shift 3; s=$SP/work/$id; xsb=(); for f in ${XSB:-}; do xsb+=(--extra-sb "$f"); done
  perl -e 'alarm 120; exec @ARGV' "$R" --step "$s" --port "$port" --env CODEX_CA_CERTIFICATE=$CA --mach $LI ${xsb[@]+"${xsb[@]}"} ${XENV[@]+"${XENV[@]}"} -- "$@" < "$pf" > "$SP/$id.out" 2> "$SP/$id.err"; echo "$id rc=$?"; }
