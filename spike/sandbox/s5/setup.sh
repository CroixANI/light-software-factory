#!/bin/bash
# Spike S5 setup (NOT sandboxed): build a Step folder, copy fixtures into repo/, fill read-only caches in io/in/cache.
# Usage: setup.sh <step-id>   -> prints the step dir
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
step="$("$here/../../harness/build-step-folder.sh" "$1")"
# Pre-seed the dotnet first-use sentinels so build/test never run the first-use code (which needs /tmp/.dotnet); restore still does (see findings).
mkdir -p "$step/home/.dotnet"; for f in dotnetFirstUseSentinel toolpath.sentinel aspNetCertificateSentinel; do touch "$step/home/.dotnet/$(dotnet --version).$f"; done
cp -R "$here/fixtures/dotnet-app" "$here/fixtures/npm-app" "$step/repo/"
c="$step/io/in/cache"; mkdir -p "$c/nuget" "$c/npm"
# NuGet: restore from the local global-packages folder as a feed (no network), into the cache dir.
(cd "$step/repo/dotnet-app" && DOTNET_CLI_HOME="$step/tmp" HOME="$step/tmp" NUGET_PACKAGES="$c/nuget" \
   dotnet restore --source "${NUGET_FEED:-$HOME/.nuget/packages}" >/dev/null)
# npm: populate cache online once.
(cd "$step/repo/npm-app" && HOME="$step/tmp" npm install --cache "$c/npm" --no-audit --no-fund >/dev/null && rm -rf node_modules)
rm -rf "$step/repo/dotnet-app/obj" "$step/repo/dotnet-app/bin"
chmod -R a-w "$c"          # read-only caches
echo "$step"
