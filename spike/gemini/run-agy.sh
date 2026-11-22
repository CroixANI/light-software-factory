#!/bin/bash
# Spike 3.5 throwaway: run `agy` (Antigravity CLI) under base.sb + agy.sb with an allowlist-only environment.
# NO credential handling on purpose: the owner forbade copying their login into a Step (see findings). Use --env GEMINI_API_KEY=<fake> for credential-free probes.
# Usage: run-agy.sh --step <dir> --port <p> [--mach NAME]... [--extra-sb FILE] [--env K=V]... [--ro-token ABS_PATH_OF_TOKEN_FILE] [--node-root DIR] [--unsandboxed] -- <agy args>   (--unsandboxed is for fake-key diagnostics only; do not use it with a real login)   (prompt in the args or on stdin)
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"; sb="$here/../harness/sandbox"
step=; port=; mach=(); extra=(); envx=(); unsb=0; rotok=; noderoot=/nonexistent
while [ $# -gt 0 ]; do case "$1" in
  --step) step=$2; shift 2;; --port) port=$2; shift 2;;
  --mach) mach+=("$2"); shift 2;; --extra-sb) extra+=("$2"); shift 2;; --unsandboxed) unsb=1; shift;; --ro-token) rotok=$2; shift 2;; --node-root) noderoot=$2; shift 2;;
  --env) [[ "$2" =~ ^[A-Z0-9_]+=[A-Za-z0-9._:/@-]*$ ]] || { echo "bad --env" >&2; exit 2; }; envx+=("$2"); shift 2;;
  --) shift; break;; *) echo "bad arg $1" >&2; exit 2;;
esac; done
for e in ${envx[@]+"${envx[@]}"}; do case "${e%%=*}" in HOME|PATH|HTTPS_PROXY|HTTP_PROXY|NO_PROXY|ALL_PROXY|TMPDIR|FACTORY_STEP) echo "--env may not override ${e%%=*}" >&2; exit 2;; esac; done
if [ "$noderoot" != /nonexistent ]; then   # part B (S5): read access to a node install (exec needs s5.sb); same checks as spike/claude/run-claude.sh
  [[ "$noderoot" =~ ^/[A-Za-z0-9._/-]+$ ]] && [ -d "$noderoot" ] || { echo "unsafe --node-root" >&2; exit 2; }
  noderoot="$(cd "$noderoot" && pwd -P)"
  [[ "$noderoot" =~ ^/[A-Za-z0-9._/-]+$ ]] || { echo "unsafe resolved --node-root" >&2; exit 2; }
  case "$noderoot" in /|/usr|/usr/local|/opt|/opt/homebrew|/System|/Library|/bin|/Users|/Users/Shared|/private|/private/tmp|/private/var|/tmp|/var|/Applications|"$HOME") echo "refusing broad --node-root: $noderoot" >&2; exit 2;; esac
  case "$HOME/" in "$noderoot"/*) echo "refusing --node-root that contains HOME" >&2; exit 2;; esac
fi
[ -n "$step" ] && [[ "$port" =~ ^[0-9]{1,5}$ ]] || { echo "need --step and numeric --port" >&2; exit 2; }
for v in "$step" ${mach[@]+"${mach[@]}"}; do [[ "$v" =~ ^[A-Za-z0-9._/-]+$ ]] || { echo "refusing unsafe value: $v" >&2; exit 2; }; done
step="$(cd "$step" && pwd -P)"
[[ "$step" =~ ^/[A-Za-z0-9._/-]+$ ]] || { echo "unsafe resolved step path" >&2; exit 2; }
agy="$(readlink -f "$(command -v agy)")"
[[ "$agy" =~ ^/[A-Za-z0-9._/-]+$ ]] && [ -f "$agy" ] || { echo "unsafe agy path: $agy" >&2; exit 2; }
if [ -n "$rotok" ]; then [ -f "$rotok" ] || { echo "--ro-token: no such file" >&2; exit 2; }
  [ ! -L "$rotok" ] || { echo "--ro-token must not be a symlink (Seatbelt matches the real path)" >&2; exit 2; }
  rotok="$(cd "$(dirname "$rotok")" && pwd -P)/$(basename "$rotok")"
  [[ "$rotok" =~ ^/[A-Za-z0-9._/-]+$ ]] || { echo "unsafe --ro-token path" >&2; exit 2; }
  # the directory part is resolved with pwd -P, so a symlinked parent directory changes the path and is refused here (fail-safe)
  [ "$rotok" = "$step/home/.gemini/antigravity-cli/antigravity-oauth-token" ] || { echo "--ro-token must be <step>/home/.gemini/antigravity-cli/antigravity-oauth-token (no symlinks)" >&2; exit 2; }; fi
if [ "$unsb" = 1 ]; then
  case " ${envx[*]-} " in *" GEMINI_API_KEY="*) ;; *) echo "--unsandboxed needs a fake GEMINI_API_KEY in --env (otherwise agy opens a browser login)" >&2; exit 2;; esac
  [ ! -e "$step/home/.gemini/antigravity-cli/antigravity-oauth-token" ] || { echo "--unsandboxed refused: this Step holds a real token file" >&2; exit 2; }
  nospace="$(printf '%s' "$*" | tr -d '[:space:]')"   # accept { "modelProvider": "gemini" } with any spacing (inline JSON only, not a settings file)
  case "$nospace" in *'"modelProvider":"gemini"'*) ;; *) echo "--unsandboxed needs --settings '{\"modelProvider\":\"gemini\"}' so the fake key is used (inline JSON; spaces are ignored)" >&2; exit 2;; esac
fi
prof="$step/tmp/lsf-agy.sb"
{ cat "$sb/base.sb"
  p="$(dirname "$agy")"; while [ "$p" != / ]; do echo "(allow file-read-metadata (literal \"$p\"))"; p="$(dirname "$p")"; done
  p="$(dirname "$step")"; while [ "$p" != / ]; do echo "(allow file-read-metadata (literal \"$p\"))"; p="$(dirname "$p")"; done
  if [ "$noderoot" != /nonexistent ]; then p="$(dirname "$noderoot")"; while [ "$p" != / ]; do echo "(allow file-read-metadata (literal \"$p\"))"; p="$(dirname "$p")"; done; fi
  cat "$here/agy.sb"
  [ -n "$rotok" ] && cat "$here/tokro.sb"
  for f in ${extra[@]+"${extra[@]}"}; do cat "$f"; done
  for m in ${mach[@]+"${mach[@]}"}; do echo "(allow mach-lookup (global-name \"$m\"))"; done; } > "$prof"
cd "$step/repo"
envv=(PATH=/usr/bin:/bin HOME="$step/home" TMPDIR="$step/tmp" LANG=en_US.UTF-8 TERM=dumb
  HTTPS_PROXY="http://127.0.0.1:$port" HTTP_PROXY="http://127.0.0.1:$port" FACTORY_STEP="$(basename "$step")" ${envx[@]+"${envx[@]}"})
if [ "$unsb" = 1 ]; then exec /usr/bin/env -i "${envv[@]}" "$agy" "$@"; fi
exec /usr/bin/env -i "${envv[@]}" /usr/bin/sandbox-exec -f "$prof" -D "STEP=$step" -D "PORT=$port" -D "PYROOT=/nonexistent" -D "NODEROOT=$noderoot" -D "CLIDIR=/nonexistent" -D "AGY=$agy" -D "TOKEN=${rotok:-/nonexistent}" "$agy" "$@"
