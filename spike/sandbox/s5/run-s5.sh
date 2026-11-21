#!/bin/bash
# Spike S5: the whole matrix. Needs macOS, dotnet SDK, node/npm, network for the npm cache fill. Usage: run-s5.sh   (prints a PASS/FAIL table, writes results/*.txt)
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"; export DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1
out="$here/results"
sid="s5-$$"; step="$("$here/setup.sh" "$sid" | tail -1)" || { echo "setup failed" >&2; exit 2; }
step="$(cd "$step" && pwd -P)"; trap 'chmod -R u+w "$step" 2>/dev/null; rm -rf "${step:?}"' EXIT
rm -rf "$out"; mkdir -p "$out"
echo "paths in results are replaced by <step>, <spike>, <home-of-owner>" >&2
clean() { sed -e "s|$step|<step>|g" -e "s|$(cd "$here/../.." && pwd -P)|<spike>|g" -e "s|$HOME|<home-of-owner>|g"; }
pass=0; fail=0
# case <name> <expect:0|nonzero> <extra files, comma list or -> <mach list or -> -- cmd...
case_() { local name=$1 expect=$2 extra=$3 mach=$4; shift 5; local o=(); local f
  IFS=, read -ra fs <<<"$extra"; for f in "${fs[@]}"; do [ "$f" != - ] && o+=(--extra "$here/$f"); done
  IFS=, read -ra ms <<<"$mach"; for f in "${ms[@]}"; do [ "$f" != - ] && o+=(--mach "$f"); done
  perl -e 'alarm 240; exec @ARGV' "$here/run.sh" "$step" ${o[@]+"${o[@]}"} -- "$@" 2>&1 | cat >"$step/tmp/$name.raw"; local rc=${PIPESTATUS[0]}   # stdout MUST be a pipe or a file inside the Step: see case 14
  clean <"$step/tmp/$name.raw" | head -40 >"$out/$name.txt"
  local ok=FAIL; if [ "$expect" = 0 ] && [ $rc -eq 0 ]; then ok=PASS; elif [ "$expect" != 0 ] && [ $rc -ne 0 ]; then ok=PASS; fi
  [ $ok = PASS ] && pass=$((pass+1)) || fail=$((fail+1)); printf '%-4s rc=%-3s %s\n' $ok $rc "$name" | tee -a "$out/summary.txt"; }
D=extra-dotnet.sb; case_ 00-dotnet-restore-no-tmp-rule nonzero - - -- dotnet restore dotnet-app -p:NuGetAudit=false
case_ 01-dotnet-restore-offline  0 $D - -- dotnet restore dotnet-app -p:NuGetAudit=false
case_ 02-dotnet-build            0 - - -- dotnet build --no-restore dotnet-app -p:NuGetAudit=false
case_ 03-dotnet-test-loopback    0 extra-vstest-loopback.sb - -- dotnet test --no-build dotnet-app -p:NuGetAudit=false
case_ 04-dotnet-test-no-loopback nonzero - - -- dotnet test --no-build dotnet-app -p:NuGetAudit=false
case_ 06-npm-ci-offline          0 - - -- npm ci --offline --prefix npm-app
case_ 07-npm-test                0 - - -- npm test --prefix npm-app
case_ 08-npm-uncached-offline    nonzero - - -- npm install --offline --prefix npm-app left-pad@1.3.0
case_ 09-dotnet-uncached-pkg     nonzero $D - -- dotnet add dotnet-app package Newtonsoft.Json --version 13.0.3
case_ 10-cache-write-denied-nuget nonzero - - -- /bin/sh -c 'echo x > "$NUGET_PACKAGES/x"'
case_ 11-cache-write-denied-npm  nonzero - - -- /bin/sh -c 'echo x > "$NPM_CONFIG_CACHE/x"'
case_ 12-write-outside-denied    nonzero - - -- /bin/sh -c 'echo x > "$HOME/../escape.txt"'
case_ 13-direct-egress-denied    nonzero - - -- node -e 'require("net").connect(443,"1.1.1.1").on("connect",()=>process.exit(0)).on("error",e=>{console.log("code="+e.code);process.exit(1)})'
case_ 15-exec-coreutils-denied   nonzero - - -- /bin/sh -c '/bin/cat /dev/null'
case_ 16-exec-git-denied         nonzero - - -- /usr/bin/git --version
# the denial must come from the sandbox, not from file modes / offline flags / a dead port: check the message text
req() { grep -q -- "$2" "$out/$1.txt" && echo "PASS text  $1 contains '$2'" | tee -a "$out/summary.txt" || { echo "FAIL text  $1 lacks '$2'" | tee -a "$out/summary.txt"; fail=$((fail+1)); }; }
for n in 10-cache-write-denied-nuget 11-cache-write-denied-npm 12-write-outside-denied 15-exec-coreutils-denied 16-exec-git-denied; do req $n "Operation not permitted"; done
req 13-direct-egress-denied "code=EPERM"
# 14: pitfall. node aborts at startup (rc 134) when its stdout is a regular file OUTSIDE the readable roots; python and dotnet do not.
t="$(mktemp -t s5-stdout)"; "$here/run.sh" "$step" -- node -v >"$t" 2>&1; rc14=$?; "$here/run.sh" "$step" -- python3 -c 1 >"$t.p" 2>&1; rc17=$?; "$here/run.sh" "$step" -- dotnet --version >"$t.d" 2>&1; rc18=$?; "$here/run.sh" "$step" -- node -v >"$step/io/out/n.txt" 2>&1; rc19=$?; rm -f "$t.p" "$t.d"; echo "INFO python-file=$rc17 dotnet-file=$rc18 node-file-in-io/out=$rc19 (expected 0 0 0)" | tee -a "$out/summary.txt"; clean <"$t" | head -8 >"$out/14-node-stdout-file-outside-step.txt"; rm -f "$t"
[ "$rc17$rc18$rc19" = 000 ] || { echo "FAIL info python/dotnet/node file-stdout expected 0 0 0" | tee -a "$out/summary.txt"; fail=$((fail+1)); }
echo "INFO rc=$rc14 14-node-stdout-file-outside-step (expected 134)" | tee -a "$out/summary.txt"
[ "$rc14" = 134 ] || { echo "FAIL info case 14 expected rc 134 (node abort) got $rc14" | tee -a "$out/summary.txt"; fail=$((fail+1)); }
echo "pass=$pass fail=$fail" | tee -a "$out/summary.txt"
echo "env: macOS $(sw_vers -productVersion), dotnet $(dotnet --version), node $(node -v), npm $(npm -v)" | tee -a "$out/summary.txt"
exit $((fail>0))
