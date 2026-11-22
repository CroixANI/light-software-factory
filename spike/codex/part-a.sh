#!/bin/bash
# Spike 3.3 throwaway: re-run of the codex part A checks (E1-E5) with fresh Step folders, one summary per check. Content-free output.
# Step credentials carry a DUMMY refresh token (lib.sh step); the owner's real file is only read. All Step folders (and so the credential copies) are removed on exit.
# Needs: ~/.codex/auth.json (owner's file login), codex on PATH, node >= 22, a scratch dir SP outside the repo.
# Usage: SP=/some/scratch/dir spike/codex/part-a.sh
set -u
here="$(cd "$(dirname "$0")" && pwd)"; export LSF_CODEX_DIR="$here"; H="$here/../harness"; R="$here/run-codex.sh"
: "${SP:?set SP to a scratch directory outside the repository}"; mkdir -p "$SP"; chmod 700 "$SP"
trap 'rm -rf "$SP/work"' EXIT
. "$here/lib.sh"
CA=/private/etc/ssl/cert.pem; LI=com.apple.system.opendirectoryd.libinfo
echo 'Reply with the single word: pong' > "$SP/p-pong.txt"
echo 'Use your shell tool to run exactly: echo hello-from-shell ; then reply with the command output only.' > "$SP/p-shell.txt"
cat > "$SP/p-write.txt" <<'E'
Use your shell tool to run exactly this one command: sh -c 'echo x > ../OUTSIDE-TEST; echo rc=$?; echo y > ./inside-test; echo rc2=$?' ; then reply with the command output only.
E
printf '(allow process-exec (literal "/usr/bin/sandbox-exec"))\n' > "$SP/nest.sb"
n=0
# gw <label> <port> <launcher args...> -- <codex args...> : fresh step (credential unless label starts with nocred), own gateway on <port>
gw() {
  lbl=$1; id=$1; port=$2; shift 2; n=$((n+1)); id="$id-$n-$$"
  case "$lbl" in nocred*) step_nocred "$id";; e2a*) step "$id"; python3 -I "$here/mutate-auth.py" "$HOME/.codex/auth.json" "$SP/work/$id/home/.codex/auth.json" old-last-refresh >/dev/null;;
    e2b*) step "$id"; python3 -I "$here/mutate-auth.py" "$HOME/.codex/auth.json" "$SP/work/$id/home/.codex/auth.json" bad-access-token >/dev/null;; *) step "$id";; esac
  s=$SP/work/$id
  node "$H/proxy/connect-proxy.mjs" --port "$port" --step "$id" > "$SP/$id.gw" 2>&1 & gp=$!; sleep 1
  perl -e 'alarm 90; exec @ARGV' "$R" --step "$s" --port "$port" "$@" < "$SP/p-pong.txt" > "$SP/$id.out" 2> "$SP/$id.err"; rc=$?
  kill -INT $gp; wait $gp 2>/dev/null
  echo "$lbl rc=$rc answers=$(grep -c '"agent_message"' "$SP/$id.out") $(python3 -I "$here/hosts.py" "$SP/$id.gw" | cut -c1-200)" | sed "s#$SP#SP#g"
  python3 -I "$here/summarize.py" "$SP/$id.out" | grep -E '^ err:' | head -2 | cut -c1-160
}
EXEC=(exec --json --skip-git-repo-check -s read-only)
echo "E2 token lifetimes of the owner's file (no token values):"; python3 -I "$here/mutate-auth.py" "$HOME/.codex/auth.json" show-exp
echo "E1/E3 credential (dummy refresh token) + libinfo only + CA bundle:"
gw e1 8941 --env CODEX_CA_CERTIFICATE=$CA --mach $LI -- "${EXEC[@]}" -c 'cli_auth_credentials_store="file"'
echo "E1 no credential file at all:";             gw nocred 8947 --env CODEX_CA_CERTIFICATE=$CA --mach $LI -- "${EXEC[@]}"
echo "E2a last_refresh 30 days old, valid access token (expect no auth.openai.com):"
gw e2a 8948 --env CODEX_CA_CERTIFICATE=$CA --mach $LI -- "${EXEC[@]}"
echo "E2b access-token signature destroyed (expect one auth.openai.com CONNECT, rc 1):"
gw e2b 8949 --env CODEX_CA_CERTIFICATE=$CA --mach $LI -- "${EXEC[@]}"
echo "E3 no Mach rule at all:";                    gw e3-none 8942 --env CODEX_CA_CERTIFICATE=$CA -- "${EXEC[@]}"
echo "E3 libinfo, no CA bundle (platform TLS):";  gw e3-noca 8943 --mach $LI -- "${EXEC[@]}"
echo "E3 libinfo+trustd.agent, no CA bundle:";    gw e3-trust 8950 --mach $LI --mach com.apple.trustd.agent -- "${EXEC[@]}"
echo "E3 libinfo+trustd.agent+SecurityServer, no CA bundle:"; gw e3-sec 8944 --mach $LI --mach com.apple.trustd.agent --mach com.apple.SecurityServer -- "${EXEC[@]}"
echo "E3 libinfo+cfprefsd.agent+cfprefsd.daemon, CA bundle:"; gw e3-cfd 8951 --env CODEX_CA_CERTIFICATE=$CA --mach $LI --mach com.apple.cfprefsd.agent --mach com.apple.cfprefsd.daemon -- "${EXEC[@]}"
echo "E4 hygiene flags:";                          gw e4 8945 --env CODEX_CA_CERTIFICATE=$CA --mach $LI -- "${EXEC[@]}" --disable plugins --disable remote_plugin --disable apps --disable in_app_updates -c analytics.enabled=false
echo "E4 plugin switches but analytics left on:";  gw e4-an 8952 --env CODEX_CA_CERTIFICATE=$CA --mach $LI -- "${EXEC[@]}" --disable plugins --disable remote_plugin --disable apps --disable in_app_updates
echo "E4 dead gateway port (nothing listens on it; no direct egress possible):"
step "e4-dead-$$"; t0=$(date +%s)
perl -e 'alarm 90; exec @ARGV' "$R" --step "$SP/work/e4-dead-$$" --port 8999 --env CODEX_CA_CERTIFICATE=$CA --mach $LI -- "${EXEC[@]}" < "$SP/p-pong.txt" > "$SP/e4-dead-$$.out" 2> "$SP/e4-dead-$$.err"
echo "e4-dead rc=$? seconds=$(( $(date +%s) - t0 )) answers=$(grep -c '"agent_message"' "$SP/e4-dead-$$.out")"
node "$H/proxy/connect-proxy.mjs" --port 8946 --step e5 > "$SP/e5.gw" 2>&1 & g5=$!; sleep 1
export PORT=8946
echo "E5 own sandbox ON (workspace-write), no sandbox-exec exec rule:"
"$here/shell-probe.sh" e5-on-$$ - "$SP/p-shell.txt" -- -s workspace-write | sed "s#$SP#SP#g"
echo "E5 own sandbox ON (workspace-write), /usr/bin/sandbox-exec exec-allowed:"
"$here/shell-probe.sh" e5-nest-$$ "$SP/nest.sb" "$SP/p-shell.txt" -- -s workspace-write | sed "s#$SP#SP#g"
echo "E5 own sandbox OFF (danger-full-access + approval never):"
"$here/shell-probe.sh" e5-off-$$ - "$SP/p-shell.txt" -- -s danger-full-access -c 'approval_policy="never"' | sed "s#$SP#SP#g"
echo "E5 own sandbox OFF (--dangerously-bypass-approvals-and-sandbox):"
"$here/shell-probe.sh" e5-byp-$$ - "$SP/p-shell.txt" -- --dangerously-bypass-approvals-and-sandbox | sed "s#$SP#SP#g"
echo "E5 outer profile still enforces with the CLI sandbox off (write outside repo/ vs inside):"
"$here/shell-probe.sh" e5-wr-$$ - "$SP/p-write.txt" -- -s danger-full-access -c 'approval_policy="never"' | sed "s#$SP#SP#g"
echo "  inside-test present in repo/: $(ls "$SP/work/e5-wr-$$/repo" | grep -c '^inside-test$'); OUTSIDE-TEST present beside repo/: $(ls "$SP/work/e5-wr-$$" | grep -c OUTSIDE-TEST)"
kill -INT $g5; wait $g5 2>/dev/null
