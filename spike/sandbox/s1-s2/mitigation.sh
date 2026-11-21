#!/bin/bash
# Spike throwaway (task 2.1): re-run S1/S2 with a CANDIDATE fix for the KERN_PROCARGS2 leak.
# Copies spike/harness/sandbox to spike/work/patched (depth 3 below the repo root: the launcher locates the repo from its own path),
# appends the candidate rules to its base.sb, and runs run.sh against the copy. spike/harness is NOT modified.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd -P)"; spike="$(cd "$here/../.." && pwd -P)"
dst="$spike/work/patched"; rm -rf "$dst"; mkdir -p "$spike/work"; cp -R "$spike/harness/sandbox" "$dst"
cat >> "$dst/base.sb" <<'RULES'

;; CANDIDATE (task 2.1): process-info-pidinfo is the operation behind sysctl(KERN_PROCARGS2) and proc_pidinfo.
;; `(deny process-info-pidinfo (target others))` does NOT stop it; denying the whole family and re-allowing pidinfo for self does.
(deny process-info*)
(allow process-info-pidinfo (target self))
RULES
SANDBOX_DIR="$dst" RESULTS_NAME=results-mitigated "$here/run.sh"
