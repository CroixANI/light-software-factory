#!/bin/bash
# Spike 3.6: run every part-B script in order with a fresh scratch directory and print one redacted log (scratch dir -> SP, repository -> REPO, home -> HOME, real-model Step dir -> RW).
# The real-model script is only SUMMARISED here (SUMMARY_ONLY=1, outputs of the one real run in $SP_REAL); run part-b-real.sh without SUMMARY_ONLY to make the real calls (needs LOGIN_HOME).
# Usage: SP=<new scratch dir outside the repo> [SP_REAL=<scratch dir of the real run> LOGIN_HOME=...] bash part-b-all.sh > logs-part-b.txt
set -u
here="$(cd "$(dirname "$0")" && pwd)"; export LSF_GEMINI_DIR=$here H=$here/../harness; repo="$(cd "$here/../.." && pwd -P)"
red(){ sed -e "s#$SP#SP#g" -e "s#$repo#REPO#g" -e "s#$HOME#HOME#g" -e "s#/private/tmp/lsf-spike-real\.[A-Za-z0-9]*#RW#g"; }
for s in e6 perm e8 e9 e10 e11 e12 s1s5; do f=part-b-$s.sh; echo "##### $f"; bash "$here/$f" 2>&1; echo; done | red
if [ -n "${SP_REAL:-}" ]; then echo "##### part-b-real.sh (summary of the single real run)"; SP=$SP_REAL SUMMARY_ONLY=1 bash "$here/part-b-real.sh" 2>&1 | red; fi
