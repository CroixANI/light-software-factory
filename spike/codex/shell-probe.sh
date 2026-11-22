#!/bin/bash
# Spike 3.3 throwaway: one codex run with the shell tool prompt under base.sb + codex.sb + shell.sb (+ one extra .sb), summarised from --json.
# Needs env: SP (scratch dir outside the repo), prompt file $SP/p-shell.txt, gateway on PORT (default 8911; part-a.sh sets 8946). Prints rc and the command/message/error items.
# Usage: shell-probe.sh <id> <extra.sb|-> <prompt-file> -- <codex exec args...>
set -u
here="$(cd "$(dirname "$0")" && pwd)"; export LSF_CODEX_DIR="$here"; H="$here/../harness"; R="$here/run-codex.sh"
id=$1; xsb=$2; pf=$3; shift 4
CA=/private/etc/ssl/cert.pem; LI=com.apple.system.opendirectoryd.libinfo
. "$here/lib.sh"; step "$id"; s=$SP/work/$id
extra=(--extra-sb "$here/shell.sb"); [ "$xsb" != - ] && extra+=(--extra-sb "$xsb")
perl -e 'alarm 120; exec @ARGV' "$R" --step "$s" --port "${PORT:-8911}" --env CODEX_CA_CERTIFICATE=$CA --mach $LI "${extra[@]}" -- exec --json --skip-git-repo-check "$@" < "$pf" > "$SP/$id.out" 2> "$SP/$id.err"
echo "$id rc=$?"
python3 -I "$here/summarize.py" "$SP/$id.out"
grep -m1 -o 'exec_command failed.*' "$SP/$id.err" | cut -c1-160 | sed 's/^/ stderr: /'
