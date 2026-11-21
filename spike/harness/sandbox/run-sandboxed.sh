#!/bin/bash
# Spike throwaway: run a command under the Seatbelt profile with an allowlist-only environment.
# Usage: run-sandboxed.sh --shape reviewer-readonly|builder --step <step-dir> --port <gateway-port> --cli-dir <dir> [--mach NAME]... -- <cmd> [args]
# Prints the profile it used on stderr with --show-profile. Exit code = the command's.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
shape=; step=; port=; show=0; clidir=; mach=()
while [ $# -gt 0 ]; do case "$1" in
  --shape) shape=$2; shift 2;; --step) step=$2; shift 2;; --port) port=$2; shift 2;;
  --cli-dir) clidir=$(cd "$2" && pwd -P); shift 2;; --mach) mach+=("$2"); shift 2;; --show-profile) show=1; shift;; --) shift; break;; *) echo "bad arg $1" >&2; exit 2;;
esac; done
[ -f "$here/$shape.sb" ] && [ -d "$step" ] && [ -n "$port" ] && [ -n "$clidir" ] && [ $# -gt 0 ] || { echo "usage: see header" >&2; exit 2; }
step="$(cd "$step" && pwd -P)"          # Seatbelt matches resolved paths (/private/var, not /var)
interp="$(readlink -f "$(command -v python3)")"
pyroot="${interp%/bin/*}"                # .../Python.framework/Versions/3.x
nodebin="$(command -v node || true)"; noderoot=/nonexistent; [ -n "$nodebin" ] && noderoot="$(dirname "$(dirname "$(readlink -f "$nodebin")")")"
prof="$(mktemp -t lsf-profile)"; trap 'rm -f "$prof"' EXIT
{ cat "$here/base.sb" "$here/$shape.sb"
  for m in ${mach[@]+"${mach[@]}"}; do echo "(allow mach-lookup (global-name \"$m\"))"; done; } > "$prof"
[ "$show" = 1 ] && cat "$prof" >&2
cd "$step/repo"                          # the worker starts in its own workspace; the owner's cwd is not readable inside
# Empty environment: nothing is inherited. PATH is curated (system dirs + the toolchain dirs the profile can read).
exec /usr/bin/env -i \
  PATH="$(dirname "$interp"):$(dirname "$nodebin"):/usr/local/share/dotnet:/usr/bin:/bin" \
  HOME="$step/home" XDG_CONFIG_HOME="$step/home/.config" XDG_CACHE_HOME="$step/home/.cache" XDG_DATA_HOME="$step/home/.local/share" \
  CLAUDE_CONFIG_DIR="$step/home/.claude" CODEX_HOME="$step/home/.codex" GEMINI_CLI_HOME="$step/home" \
  TMPDIR="$step/tmp" LANG=en_US.UTF-8 TERM=dumb \
  HTTPS_PROXY="http://127.0.0.1:$port" HTTP_PROXY="http://127.0.0.1:$port" \
  FACTORY_STEP="$(basename "$step")" \
  /usr/bin/sandbox-exec -f "$prof" -D "STEP=$step" -D "PORT=$port" -D "PYROOT=$pyroot" -D "NODEROOT=$noderoot" -D "CLIDIR=$clidir" \
  "$@"
