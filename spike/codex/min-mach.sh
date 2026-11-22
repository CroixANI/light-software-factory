#!/bin/bash
# Spike 3.3 throwaway (E3): greedy minimisation of the Mach allowlist for `codex exec`.
# Profile = (allow default) + (deny mach-lookup) + an allowlist; start from a candidate list (one name per line),
# drop one name at a time and keep the drop when the call still answers. Prints NEEDED / dropped per name and the final set.
# EXTRAENV="K=V K2=V2" adds environment variables to the run.
# Usage: min-mach.sh <step-dir> <gateway-port> <candidates-file> <prompt-file>
set -u
step=$1; port=$2; cands=$3; prompt=$4; 
cli="$(readlink -f "$(command -v codex)")"; tmp="$(mktemp -d "${TMPDIR:-/tmp}/minmach.XXXXXX")"
run() {
  { printf '(version 1)\n(allow default)\n(deny mach-lookup)\n'
    for m in "$@"; do printf '(allow mach-lookup (global-name "%s"))\n' "$m"; done; } > "$tmp/p.sb"
  ( cd "$step/repo" && perl -e 'alarm 25; exec @ARGV' /usr/bin/env -i PATH=/usr/bin:/bin HOME="$step/home" CODEX_HOME="$step/home/.codex" \
      TMPDIR="$step/tmp" LANG=en_US.UTF-8 TERM=dumb HTTPS_PROXY="http://127.0.0.1:$port" ${EXTRAENV:-} \
      /usr/bin/sandbox-exec -f "$tmp/p.sb" "$cli" exec --json --skip-git-repo-check -s read-only < "$prompt" > "$tmp/o" 2> "$tmp/e" )
  grep -c '"agent_message"' "$tmp/o"
}
cur=(); while IFS= read -r l; do [ -n "$l" ] && cur+=("$l"); done < "$cands"
for m in ${cur[@]+"${cur[@]}"}; do
  trial=(); for x in ${cur[@]+"${cur[@]}"}; do [ "$x" != "$m" ] && trial+=("$x"); done
  r=$(run ${trial[@]+"${trial[@]}"})
  if [ "$r" = 1 ]; then cur=("${trial[@]}"); echo "dropped $m"; else echo "NEEDED $m"; fi
done
echo "FINAL: ${cur[*]}"
