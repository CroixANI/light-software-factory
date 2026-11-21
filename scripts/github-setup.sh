#!/usr/bin/env bash
# Idempotent setup of labels and milestones for D-73. Run once after D-73 is accepted:
#   scripts/github-setup.sh            # uses the repo of the current directory
# Requires an authenticated `gh`. Existing labels and milestones are left unchanged.
set -euo pipefail

label() { gh label create "$1" --color "$2" --description "$3" 2>/dev/null || echo "label exists: $1"; }

label "type:spike"    "5319e7" "Provider CLI / sandbox experiment (throwaway code in spike/)"
label "type:spec"     "0e8a16" "OpenSpec change authoring"
label "type:impl"     "1d76db" "Implementation of a specified task"
label "type:docs"     "0075ca" "Documentation only"
label "type:decision" "fbca04" "Decision proposal (D-NN)"
label "area:station"  "c5def5" "Factory.Station: sandbox, gateway, provider adapters"
label "area:core"     "c5def5" "Factory.Core: domain, store, pipeline, adapters"
label "area:host"     "c5def5" "Factory.Host: CLI and API"
label "area:web"      "c5def5" "web/: React UI"
label "area:process"  "c5def5" "Working process, templates, tooling"

milestone() {
  local existing
  existing=$(gh api "repos/{owner}/{repo}/milestones?state=all&per_page=100" --jq ".[] | select(.title==\"$1\") | .number")
  if [ -n "$existing" ]; then echo "milestone exists: $1"; else
    gh api "repos/{owner}/{repo}/milestones" -f title="$1" -f description="$2" >/dev/null && echo "milestone created: $1"
  fi
}

milestone "M0 Spike"        "Run each provider CLI inside the deny-by-default sandbox; produce docs/spike/findings.md"
milestone "M1 Spike review" "Owner gate: findings reviewed, architecture and decisions updated; no production code before this"
milestone "M2 Foundation"   "Solution scaffold, CI, domain state machines, SQLite store and board, config, spec adapter"
milestone "M3 Station"      "Sandbox, step folders, gateway, provider adapters, hostile-worker tests"
milestone "M4 Pipeline"     "GitHub/git adapter, plan, dispatcher, gates, plan critique, adversarial review"
milestone "M5 Surface"      "CLI, API, five UI screens, escalation inbox"
milestone "M6 Dogfood"      "init, doctor, first real group, calibration of caps, retrospective"
