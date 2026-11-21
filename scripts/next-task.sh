#!/usr/bin/env bash
# Find (and claim) the next ready task. D-74. Requires gh and jq.
#   scripts/next-task.sh              list ready / claimed / blocked tasks as JSON
#   scripts/next-task.sh <N>          same, plus whether task N is ready
#   scripts/next-task.sh --claim <N>  claim task N: create its branch (the lock), assign, comment
#   scripts/next-task.sh --release <N>  undo a claim (delete branch, unassign, comment)
# DRY_RUN=1 prints the claim/release actions without doing them. Read-only otherwise: 2 API calls + 1 ls-remote.
set -euo pipefail

usage() { sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }
mode=list; target=
case "${1:-}" in
  "") ;;
  --claim) mode=claim; target=${2:-}; [[ "$target" =~ ^[0-9]+$ ]] || usage ;;
  --release) mode=release; target=${2:-}; [[ "$target" =~ ^[0-9]+$ ]] || usage ;;
  -h|--help) usage ;;
  *) [[ "$1" =~ ^[0-9]+$ ]] && target=$1 || usage ;;
esac
run() { if [ "${DRY_RUN:-0}" = 1 ]; then echo "DRY_RUN: $*" >&2; else "$@"; fi; }

repo=$(gh repo view --json nameWithOwner -q .nameWithOwner)
all=$(gh api "repos/$repo/issues?state=open&per_page=100" --paginate | jq -s 'add')
prs=$(gh pr list --state open --json number,headRefName,body --limit 100)
branches=$(git ls-remote --heads origin 2>/dev/null | sed 's#.*refs/heads/##' | jq -R . | jq -s .)

report=$(jq -n --argjson all "$all" --argjson prs "$prs" --argjson br "$branches" '
  def prefixes: (. // "") | split(",")
    | map(gsub("\\s*\\(.*$";"") | gsub("^\\s+|\\s+$";"") | gsub("\\*.*$";"")) | map(select(length > 0));
  def overlap($a; $b): any($a[]; . as $x | any($b[]; . as $y | ($x | startswith($y)) or ($y | startswith($x))));
  def files: ((.body // "") | capture("## Declared files\\s*\\n(?<f>[^\\n]*)"; "") | .f) // "";
  def tasknum: ((.title | capture("^(?<a>[0-9]+)\\.(?<b>[0-9]+)")) | [(.a | tonumber), (.b | tonumber)]) // [999, 999];
  ($all | map(select(.pull_request == null))) as $issues
  | ($issues | map(.number)) as $open
  | ($issues | map(select(
        .parent_issue_url != null
        and ((.parent_issue_url | split("/") | last | tonumber) as $p | $open | index($p) != null)
        and (.author_association | IN("OWNER","MEMBER","COLLABORATOR"))
        and any(.labels[]; .name | startswith("type:"))))) as $tasks
  | def claimed($n): ($n.assignee != null)
      or any($br[]; test("-" + ($n.number | tostring) + "(-[0-9a-f]+)?$"))
      or any($prs[]; (.body // "") | test("(?i)closes\\s+#" + ($n.number | tostring) + "\\b"));
  ($tasks | map(select(claimed(.)))) as $cl
  | ($tasks | map(select(claimed(.) | not))) as $free
  | ($free | map(select(.issue_dependencies_summary.blocked_by > 0))) as $blocked
  | ($free | map(select(.issue_dependencies_summary.blocked_by == 0))) as $ready0
  | ($ready0 | map(select(. as $t | (($t | files | prefixes) as $tf
        | any($cl[]; overlap($tf; (. | files | prefixes))) | not)))) as $ready1
  | ($ready0 | map(select(. as $t | $ready1 | map(.number) | index($t.number) | not))) as $dropped
  | {
      ready: ($ready1 | map({number, title, milestone: .milestone.title, milestone_no: (.milestone.number // 999),
                attended: ((.body // "") | test("Attended:\\s*yes"; "i")), declared_files: files, task: tasknum})
              | sort_by([.attended, .milestone_no, .task]) | map(del(.milestone_no, .task))),
      claimed: ($cl | map({number, title, assignee: .assignee.login, updated_at,
                stale: ((now - (.updated_at | fromdateiso8601)) > 86400)})),
      blocked: ($blocked | map({number, title, open_blockers: .issue_dependencies_summary.blocked_by})),
      dropped_for_file_overlap: ($dropped | map({number, title}))
    }')

if [ "$mode" = list ]; then
  if [ -n "$target" ]; then
    echo "$report" | jq --argjson n "$target" '. + {requested: $n, requested_is_ready: (.ready | any(.number == $n))}'
  else echo "$report" | jq .; fi
  exit 0
fi

if [ "$mode" = claim ]; then
  echo "$report" | jq -e --argjson n "$target" '.ready | any(.number == $n)' >/dev/null \
    || { echo "task #$target is not ready (blocked, claimed, overlapping, or not a task); run without arguments to see why" >&2; exit 3; }
  issue=$(echo "$all" | jq --argjson n "$target" '.[] | select(.number == $n)')
  change=$(echo "$issue" | jq -r '(.body // "") | capture("OpenSpec change:\\s*(?<c>[a-z0-9-]+)") | .c')
  kind=$(echo "$issue" | jq -r '[.labels[].name | select(startswith("type:")) | sub("type:";"")][0]')
  case "$kind" in impl) kind=feat;; decision) kind=docs;; esac
  [ -n "$change" ] || { echo "issue #$target has no 'OpenSpec change: <slug>' line" >&2; exit 3; }
  branch="$kind/$change-$target"
  sha=$(gh api "repos/$repo/git/ref/heads/main" -q .object.sha)
  # Creating the ref is the lock: HTTP 422 if another session already has it.
  run gh api -X POST "repos/$repo/git/refs" -f ref="refs/heads/$branch" -f sha="$sha" >/dev/null \
    || { echo "could not create $branch: already claimed by another session" >&2; exit 4; }
  run gh issue edit "$target" --add-assignee @me >/dev/null
  run gh issue comment "$target" --body "claimed: ${AGENT_NAME:-agent}, $(date -u +%Y-%m-%dT%H:%MZ), branch \`$branch\`" >/dev/null
  jq -n --arg b "$branch" --argjson n "$target" '{claimed: $n, branch: $b}'
  exit 0
fi

# release
branch=$(echo "$branches" | jq -r --arg s "-$target" 'map(select(endswith($s)))[0] // empty')
[ -n "$branch" ] || { echo "no branch for #$target" >&2; exit 3; }
run gh api -X DELETE "repos/$repo/git/refs/heads/$branch" >/dev/null
run gh issue edit "$target" --remove-assignee @me >/dev/null
run gh issue comment "$target" --body "released: ${AGENT_NAME:-agent}, branch \`$branch\` deleted" >/dev/null
echo "released #$target"
