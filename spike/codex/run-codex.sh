#!/bin/bash
# Spike 3.3 throwaway: run `codex exec` under base.sb + codex.sb with an allowlist-only environment.
# Credential: the owner's file credential (auth.json) is copied into <step>/home/.codex by the caller (mode 0400); this profile makes it write-protected (deny file-write* on that one path).
# Usage: run-codex.sh --step <dir> --port <p> [--mach NAME]... [--extra-sb FILE] [--env K=V]... [--node-root DIR] -- <codex args>   (prompt on stdin)
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"; sb="$here/../harness/sandbox"
step=; port=; mach=(); extra=(); envx=(); noderoot=/nonexistent
while [ $# -gt 0 ]; do case "$1" in
  --step) step=$2; shift 2;; --port) port=$2; shift 2;;
  --mach) mach+=("$2"); shift 2;; --extra-sb) extra+=("$2"); shift 2;; --node-root) noderoot=$2; shift 2;;
  --env) [[ "$2" =~ ^[A-Z0-9_]+=[A-Za-z0-9._:/@-]*$ ]] || { echo "bad --env" >&2; exit 2; }; envx+=("$2"); shift 2;;
  --) shift; break;; *) echo "bad arg $1" >&2; exit 2;;
esac; done
if [ "$noderoot" != /nonexistent ]; then
  [[ "$noderoot" =~ ^/[A-Za-z0-9._/-]+$ ]] && [ -d "$noderoot" ] || { echo "unsafe --node-root" >&2; exit 2; }
  noderoot="$(cd "$noderoot" && pwd -P)"
  case "$noderoot" in /|/usr|/usr/local|/opt|/opt/homebrew|/System|/Library|/bin|/Users|/Users/Shared|/private|/private/tmp|/private/var|/tmp|/var|/Applications|"$HOME") echo "refusing broad --node-root: $noderoot" >&2; exit 2;; esac
  case "$HOME/" in "$noderoot"/*) echo "refusing --node-root that contains HOME" >&2; exit 2;; esac
fi
for e in ${envx[@]+"${envx[@]}"}; do case "${e%%=*}" in HOME|PATH|HTTPS_PROXY|HTTP_PROXY|NO_PROXY|ALL_PROXY|CODEX_HOME|TMPDIR|FACTORY_STEP) echo "--env may not override ${e%%=*}" >&2; exit 2;; esac; done
[ -n "$step" ] && [[ "$port" =~ ^[0-9]{1,5}$ ]] || { echo "need --step and numeric --port" >&2; exit 2; }
for v in "$step" ${mach[@]+"${mach[@]}"}; do [[ "$v" =~ ^[A-Za-z0-9._/-]+$ ]] || { echo "refusing unsafe value: $v" >&2; exit 2; }; done
step="$(cd "$step" && pwd -P)"
cli="$(readlink -f "$(command -v codex)")"; clidir="$(dirname "$cli")"
prof="$step/tmp/lsf-codex.sb"
{ cat "$sb/base.sb"
  for r in "$step" "$clidir" "$noderoot" /usr/local/share/dotnet; do p="$(dirname "$r")"; while [ "$p" != / ]; do echo "(allow file-read-metadata (literal \"$p\"))"; p="$(dirname "$p")"; done; done | sort -u
  cat "$here/codex.sb"
  for f in ${extra[@]+"${extra[@]}"}; do cat "$f"; done
  for m in ${mach[@]+"${mach[@]}"}; do echo "(allow mach-lookup (global-name \"$m\"))"; done; } > "$prof"
cd "$step/repo"
exec /usr/bin/env -i PATH=/usr/bin:/bin HOME="$step/home" CODEX_HOME="$step/home/.codex" TMPDIR="$step/tmp" LANG=en_US.UTF-8 TERM=dumb \
  HTTPS_PROXY="http://127.0.0.1:$port" HTTP_PROXY="http://127.0.0.1:$port" FACTORY_STEP="$(basename "$step")" ${envx[@]+"${envx[@]}"} \
  /usr/bin/sandbox-exec -f "$prof" -D "STEP=$step" -D "PORT=$port" -D "PYROOT=/nonexistent" -D "NODEROOT=$noderoot" -D "CLIDIR=$clidir" "$cli" "$@"
