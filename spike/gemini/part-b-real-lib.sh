# Spike 3.6 part B, real-model runs (source me; sources part-b-lib.sh). Needs a Step-local login token made by login.sh (path in LOGIN_HOME, outside the repository). At most ~5 real model calls in total (model gemini-3.8-flash-low).
# gateway: connect-proxy.mjs on 8931 with the verified four-host allowlist; every real run copies the token read-only (tokro.sb) into its own fresh Step. Nothing printed from the token except field names / expiry.
. "$LSF_GEMINI_DIR/part-b-lib.sh"
RMODEL=gemini-3.8-flash-low; RP=8931; HOSTS="daily-cloudcode-pa.googleapis.com,aicode.googleapis.com,www.googleapis.com,oauth2.googleapis.com"
: "${LOGIN_HOME:?path of the login Step home}"
# Real-model Steps live under a NEUTRAL path (no user name in it): the model sees the workspace path in its context and in tool calls, so it is sent to the provider.
# RW is always a NEW private directory made here (never taken from the environment): rstep and the real run delete things under it. SUMMARY_ONLY makes no directory.
if [ -n "${SUMMARY_ONLY:-}" ]; then RW=/nonexistent-summary-only
else RW=$(mktemp -d /private/tmp/lsf-spike-real.XXXXXX) && [ -d "$RW" ] && [ ! -L "$RW" ] && [ -O "$RW" ] || { echo "cannot make a private RW dir" >&2; exit 2; }; chmod 700 "$RW"; fi
tokpath(){ echo "$RW/$1/home/.gemini/antigravity-cli/antigravity-oauth-token"; }
rstep(){ rm -rf "$RW/$1"; "$H/build-step-folder.sh" "$1" "$RW" >/dev/null; mkdir -p "$RW/$1/home/.gemini/antigravity-cli"; cp "$LOGIN_HOME/.gemini/antigravity-cli/antigravity-oauth-token" "$(tokpath "$1")"; chmod 600 "$(tokpath "$1")"; }
# runr <id> <seconds> <prompt-file|-> <run-agy extra args...> -- <agy args...>   (real route, token read-only)
runr(){ local id=$1 secs=$2 pf=$3; shift 3; local ra=(); while [ $# -gt 0 ] && [ "$1" != -- ]; do ra+=("$1"); shift; done; shift; [ "$pf" = - ] && pf=/dev/null
  "$G/with-timeout.pl" "$secs" "$R" --step "$RW/$id" --port $RP "${X[@]}" --ro-token "$(tokpath "$id")" ${ra[@]+"${ra[@]}"} -- "$@" < "$pf" > "$SP/$id.out" 2> "$SP/$id.err"; echo "$id rc=$?"; }
