#!/bin/bash
# Spike throwaway: run a command under the Seatbelt profile with an allowlist-only environment.
# Usage: run-sandboxed.sh --shape reviewer-readonly|builder --step <step-dir> --port <gateway-port> --cli-dir <dir> [--mach NAME]... -- <cmd> [args]
# Prints the profile it used on stderr with --show-profile. Exit code = the command's.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
shape=; step=; port=; show=0; clidir=; mach=()
while [ $# -gt 0 ]; do case "$1" in
  --shape|--step|--port|--cli-dir|--mach) [ $# -ge 2 ] || { echo "missing value for $1" >&2; exit 2; }; k=$1; v=$2; shift 2
    case $k in --shape) shape=$v;; --step) step=$v;; --port) port=$v;; --cli-dir) clidir=$(cd "$v" && pwd -P);;
      --mach) [[ "$v" =~ ^[A-Za-z0-9._-]+$ ]] || { echo "bad mach name" >&2; exit 2; }; mach+=("$v");; esac;;
  --show-profile) show=1; shift;; --) shift; break;; *) echo "bad arg $1" >&2; exit 2;;
esac; done
[[ "$shape" =~ ^(reviewer-readonly|builder)$ ]] && [[ "$port" =~ ^[0-9]+$ ]] && [ -f "$here/$shape.sb" ] && [ -d "$step" ] && [ -n "$port" ] && [ -n "$clidir" ] && [ $# -gt 0 ] || { echo "usage: see header" >&2; exit 2; }
step="$(cd "$step" && pwd -P)"          # Seatbelt matches resolved paths (/private/var, not /var)
interp="$(readlink -f "$(command -v python3)")"
pyroot="${interp%/bin/*}"                # .../Python.framework/Versions/3.x
nodebin="$(command -v node || true)"; noderoot=/nonexistent; [ -n "$nodebin" ] && noderoot="$(dirname "$(dirname "$(readlink -f "$nodebin")")")"
repo_root="$(cd "$here/../../.." && pwd -P)"
for r in "$pyroot" "$noderoot" "$clidir" "$step"; do   # roots become read (and exec) rules: refuse broad ones
  case "$r" in /|/usr|/usr/local|/opt|/opt/homebrew|/System|/Library|/bin|/Users|/private|/Applications) echo "refusing broad root: $r" >&2; exit 2;; esac
  case "$r" in *[\"\(\)\\]*) echo "refusing path with quote/paren/backslash: $r" >&2; exit 2;; esac
  for guard in "$HOME" "$repo_root"; do case "$guard/" in "$r"/*) echo "refusing root that contains $guard: $r" >&2; exit 2;; esac; done
done
prof="$(mktemp -t lsf-profile)"; trap 'rm -f "$prof"' EXIT
{ cat "$here/base.sb"
  # metadata-only access to the ancestor directories of each allowed root (and nothing else)
  for r in "$step" "$pyroot" "$noderoot" "$clidir" /usr/local/share/dotnet; do
    p="$(dirname "$r")"; while [ "$p" != / ]; do echo "(allow file-read-metadata (literal \"$p\"))"; p="$(dirname "$p")"; done
  done | sort -u
  cat "$here/$shape.sb"
  for m in ${mach[@]+"${mach[@]}"}; do echo "(allow mach-lookup (global-name \"$m\"))"; done; } > "$prof"
[ "$show" = 1 ] && cat "$prof" >&2 || true
print_roots() { echo "roots: py=$pyroot node=$noderoot cli=$clidir" >&2; }; print_roots
cd "$step/repo"                          # the worker starts in its own workspace; the owner's cwd is not readable inside
# Empty environment: nothing is inherited. PATH is curated (system dirs + the toolchain dirs the profile can read).
set +e
/usr/bin/env -i \
  PATH="$(dirname "$interp")${nodebin:+:$(dirname "$nodebin")}:/usr/local/share/dotnet:/usr/bin:/bin" \
  HOME="$step/home" XDG_CONFIG_HOME="$step/home/.config" XDG_CACHE_HOME="$step/home/.cache" XDG_DATA_HOME="$step/home/.local/share" \
  CLAUDE_CONFIG_DIR="$step/home/.claude" CODEX_HOME="$step/home/.codex" GEMINI_CLI_HOME="$step/home" \
  TMPDIR="$step/tmp" LANG=en_US.UTF-8 TERM=dumb \
  HTTPS_PROXY="http://127.0.0.1:$port" HTTP_PROXY="http://127.0.0.1:$port" \
  FACTORY_STEP="$(basename "$step")" \
  /usr/bin/sandbox-exec -f "$prof" -D "STEP=$step" -D "PORT=$port" -D "PYROOT=$pyroot" -D "NODEROOT=$noderoot" -D "CLIDIR=$clidir" \
  "$@"
rc=$?
exit $rc
