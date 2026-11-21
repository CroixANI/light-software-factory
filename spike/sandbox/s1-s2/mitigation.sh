#!/bin/bash
# Spike throwaway (task 2.1): re-run S1/S2 with a CANDIDATE fix for the KERN_PROCARGS2 leak.
# Copies spike/harness/sandbox to spike/work/patched (depth 3 below the repo root: the launcher locates the repo from its own path),
# replaces the two process-info* lines in its base.sb with the candidate rules, and runs run.sh against the copy. spike/harness is NOT modified.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd -P)"; spike="$(cd "$here/../.." && pwd -P)"
dst="$spike/work/patched"; rm -rf "$dst"; mkdir -p "$spike/work"; cp -R "$spike/harness/sandbox" "$dst"
# Replace (not append to) the process-info lines, so the tested profile is exactly the proposed one.
python3 - "$dst/base.sb" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
a="(allow process-info* (target self))\n(deny process-info* (target others))\n"
assert a in s
s=s.replace(a,"(deny process-info*)\n(allow process-info-pidinfo (target self))   ; CANDIDATE: only pidinfo of self (sysctl KERN_PROCARGS2, proc_pidinfo)\n")
open(p,"w").write(s)
PY
SANDBOX_DIR="$dst" RESULTS_NAME=results-mitigated "$here/run.sh"
