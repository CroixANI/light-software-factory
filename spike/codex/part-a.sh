#!/bin/bash
# Spike 3.3 throwaway: re-run of the codex part A checks (E1-E5) with fresh Step folders, one summary line each. Content-free output.
# Needs: ~/.codex/auth.json (owner's file login), codex on PATH, node >= 22, a scratch dir SP outside the repo.
# Usage: SP=/some/scratch/dir spike/codex/part-a.sh
set -u
here="$(cd "$(dirname "$0")" && pwd)"; H="$here/../harness"; R="$here/run-codex.sh"
: "${SP:?set SP to a scratch directory outside the repository}"; mkdir -p "$SP"; chmod 700 "$SP"
. "$here/lib.sh"
CA=/private/etc/ssl/cert.pem; LI=com.apple.system.opendirectoryd.libinfo
echo 'Reply with the single word: pong' > "$SP/p-pong.txt"
echo 'Use your shell tool to run exactly: echo hello-from-shell ; then reply with the command output only.' > "$SP/p-shell.txt"
printf '(allow process-exec (literal "/usr/bin/sandbox-exec"))\n' > "$SP/nest.sb"
n=0
# gw <id> <port> <launcher args...> -- <codex args...> : fresh step, own gateway on <port>, prints rc / pong / hosts
gw() {
  lbl=$1; id=$1; port=$2; shift 2; n=$((n+1)); id="$id-$n-$$"; step "$id"; s=$SP/work/$id
  node "$H/proxy/connect-proxy.mjs" --port "$port" --step "$id" > "$SP/$id.gw" 2>&1 & gp=$!; sleep 1
  perl -e 'alarm 90; exec @ARGV' "$R" --step "$s" --port "$port" "$@" < "$SP/p-pong.txt" > "$SP/$id.out" 2> "$SP/$id.err"; rc=$?
  kill -INT $gp; wait $gp 2>/dev/null
  echo "$lbl rc=$rc answers=$(grep -c '"agent_message"' "$SP/$id.out") $(python3 -I "$here/hosts.py" "$SP/$id.gw" | cut -c1-200)" | sed "s#$SP#SP#g"
}
EXEC=(exec --json --skip-git-repo-check -s read-only)
echo "E1/E3 credential + libinfo only + CA bundle:"
gw e1 8941 --env CODEX_CA_CERTIFICATE=$CA --mach $LI -- "${EXEC[@]}" -c 'cli_auth_credentials_store="file"'
echo "E3 no Mach rule at all:";                    gw e3-none 8942 --env CODEX_CA_CERTIFICATE=$CA -- "${EXEC[@]}"
echo "E3 libinfo, no CA bundle (platform TLS):";  gw e3-noca 8943 --mach $LI -- "${EXEC[@]}"
echo "E3 libinfo+trustd.agent+SecurityServer, no CA bundle:"; gw e3-sec 8944 --mach $LI --mach com.apple.trustd.agent --mach com.apple.SecurityServer -- "${EXEC[@]}"
echo "E4 hygiene flags:";                          gw e4 8945 --env CODEX_CA_CERTIFICATE=$CA --mach $LI -- "${EXEC[@]}" --disable plugins --disable remote_plugin --disable apps --disable in_app_updates -c analytics.enabled=false
echo "E4 dead gateway port (nothing listens on it; no direct egress possible):"
step "e4-dead-$$"; t0=$(date +%s)
perl -e 'alarm 90; exec @ARGV' "$R" --step "$SP/work/e4-dead-$$" --port 8999 --env CODEX_CA_CERTIFICATE=$CA --mach $LI -- "${EXEC[@]}" < "$SP/p-pong.txt" > "$SP/e4-dead-$$.out" 2> "$SP/e4-dead-$$.err"
echo "e4-dead rc=$? seconds=$(( $(date +%s) - t0 )) answers=$(grep -c '"agent_message"' "$SP/e4-dead-$$.out")"
node "$H/proxy/connect-proxy.mjs" --port 8946 --step e5 > "$SP/e5.gw" 2>&1 & g5=$!; sleep 1
echo "E5 own sandbox ON (workspace-write) inside the profile:"
PORT=8946 "$here/shell-probe.sh" e5-on-$$ "$SP/nest.sb" "$SP/p-shell.txt" -- -s workspace-write | sed "s#$SP#SP#g"
echo "E5 own sandbox OFF (danger-full-access + approval never):"
PORT=8946 "$here/shell-probe.sh" e5-off-$$ - "$SP/p-shell.txt" -- -s danger-full-access -c 'approval_policy="never"' | sed "s#$SP#SP#g"
kill -INT $g5; wait $g5 2>/dev/null
