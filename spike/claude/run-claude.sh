#!/bin/bash
# Spike 3.1 throwaway: run `claude -p` under base.sb + claude.sb with an allowlist-only environment.
# The credential is read from a file (never printed) and handed over ONLY as CLAUDE_CODE_OAUTH_TOKEN (no Keychain, no credential file).
# Usage: run-claude.sh --step <dir> --port <p> [--token-file F] [--mach NAME]... [--extra-sb FILE] [--no-token] -- <claude args>   (prompt on stdin)
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"; sb="$here/../harness/sandbox"
step=; port=; tokf=; mach=(); extra=(); notoken=0
while [ $# -gt 0 ]; do case "$1" in
  --step) step=$2; shift 2;; --port) port=$2; shift 2;; --token-file) tokf=$2; shift 2;;
  --mach) mach+=("$2"); shift 2;; --extra-sb) extra+=("$2"); shift 2;; --no-token) notoken=1; shift;; --) shift; break;; *) echo "bad arg $1" >&2; exit 2;;
esac; done
step="$(cd "$step" && pwd -P)"
cli="$(readlink -f "$(command -v claude)")"; clidir="$(dirname "$cli")"
interp="$(readlink -f "$(command -v python3)")"; pyroot="${interp%/bin/*}"
prof="$(mktemp -t lsf-claude)"; trap 'rm -f "$prof"' EXIT
{ cat "$sb/base.sb"
  for r in "$step" "$pyroot" "$clidir"; do p="$(dirname "$r")"; while [ "$p" != / ]; do echo "(allow file-read-metadata (literal \"$p\"))"; p="$(dirname "$p")"; done; done | sort -u
  cat "$here/claude.sb"
  for f in ${extra[@]+"${extra[@]}"}; do cat "$f"; done
  for m in ${mach[@]+"${mach[@]}"}; do echo "(allow mach-lookup (global-name \"$m\"))"; done; } > "$prof"
tokenv=(); [ "$notoken" = 0 ] && tokenv=("CLAUDE_CODE_OAUTH_TOKEN=$(cat "${tokf:-$HOME/.factory-spike/claude-token}")")
cd "$step/repo"
exec /usr/bin/env -i PATH=/usr/bin:/bin HOME="$step/home" CLAUDE_CONFIG_DIR="$step/home/.claude" TMPDIR="$step/tmp" LANG=en_US.UTF-8 TERM=dumb \
  CLAUDE_CODE_TMPDIR="$step/tmp" CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 DISABLE_TELEMETRY=1 DISABLE_ERROR_REPORTING=1 DISABLE_AUTOUPDATER=1 HTTPS_PROXY="http://127.0.0.1:$port" HTTP_PROXY="http://127.0.0.1:$port" FACTORY_STEP="$(basename "$step")" ${tokenv[@]+"${tokenv[@]}"} \
  /usr/bin/sandbox-exec -f "$prof" -D "STEP=$step" -D "PORT=$port" -D "PYROOT=$pyroot" -D "NODEROOT=/nonexistent" -D "CLIDIR=$clidir" "$cli" "$@"
