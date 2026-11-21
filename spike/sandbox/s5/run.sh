#!/bin/bash
# Spike S5: run a command under the builder profile with toolchain env. Usage: run.sh <step> [--extra FILE]... [--mach X]... -- <cmd...>
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"; step="$(cd "$1" && pwd -P)"; shift
opts=(); while [ "${1:-}" = --mach ] || [ "${1:-}" = --extra ]; do opts+=("$1" "$2"); shift 2; done; [ "${1:-}" = -- ] && shift
c="$step/io/in/cache"
exec "$here/launcher.sh" --shape builder --step "$step" --port 8999 --cli-dir "$here/fixtures" ${opts[@]+"${opts[@]}"} -- \
  /usr/bin/env NUGET_PACKAGES="$c/nuget" DOTNET_CLI_HOME="$step/home" DOTNET_NOLOGO=1 DOTNET_CLI_TELEMETRY_OPTOUT=1 \
  DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1 DOTNET_GENERATE_ASPNET_CERTIFICATE=false MSBUILDDISABLENODEREUSE=1 DOTNET_CLI_USE_MSBUILD_SERVER=0 \
  NUGET_XMLDOC_MODE=skip NPM_CONFIG_CACHE="$c/npm" NPM_CONFIG_OFFLINE=true NPM_CONFIG_UPDATE_NOTIFIER=false NPM_CONFIG_AUDIT=false NPM_CONFIG_FUND=false \
  "$@"
