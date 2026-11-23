#!/usr/bin/env bash
# Find (and claim) the next ready task. D-74. Requires gh and jq.
#   scripts/next-task.sh              list ready / claimed / blocked tasks as JSON
#   scripts/next-task.sh <N>          same, plus whether task N is ready
#   scripts/next-task.sh --claim <N>  claim task N: create its branch (the lock), assign, comment
#   scripts/next-task.sh --claim <N> --here  same, then switch THIS clean checkout (your own worktree) to the branch
#   scripts/next-task.sh --release <N>  undo a claim (delete branch, unassign, comment)
# DRY_RUN=1 prints the claim/release actions without doing them. Without --claim/--release it only reads: 2 API calls + 1 ls-remote.
set -euo pipefail

usage() { sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }
mode=list; target=; here=0
case "${1:-}" in
  "") ;;
  --claim) mode=claim; target=${2:-}; [[ "$target" =~ ^[0-9]+$ ]] || usage
    case "${3:-}" in "") ;; --here) here=1 ;; *) usage ;; esac
    [ $# -le 3 ] || usage ;;
  --release) mode=release; target=${2:-}; [[ "$target" =~ ^[0-9]+$ ]] || usage; [ $# -le 2 ] || usage ;;
  -h|--help) usage ;;
  *) [[ "$1" =~ ^[0-9]+$ ]] && target=$1 || usage ;;
esac
run() { if [ "${DRY_RUN:-0}" = 1 ]; then echo "DRY_RUN: $*" >&2; else "$@"; fi; }

# --here: check the local checkout BEFORE claiming, so a refusal leaves GitHub untouched.
if [ "$here" = 1 ]; then
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "--here: not inside a git checkout" >&2; exit 5; }
  if [ -n "$(git status --porcelain)" ]; then
    echo "--here: this checkout has uncommitted changes; commit or discard them, or use a clean worktree" >&2; exit 5
  fi
  gitdir=$(cd "$(git rev-parse --git-dir)" && pwd -P); commondir=$(cd "$(git rev-parse --git-common-dir)" && pwd -P)
  # The main checkout is refused on any branch and in detached HEAD; a linked worktree (even detached) is fine.
  if [ "$gitdir" = "$commondir" ]; then
    echo "--here: this is the main checkout; create your own worktree first (or use the worktree steps in docs/process/session-protocol.md)" >&2; exit 5
  fi
fi

repo=$(gh repo view --json nameWithOwner -q .nameWithOwner)
all=$(gh api "repos/$repo/issues?state=open&per_page=100" --paginate | jq -s 'add')
prs=$(gh pr list --state open --json number,headRefName,body --limit 100)
branches=$(git ls-remote --heads origin | sed 's#.*refs/heads/##' | jq -R . | jq -s .)

report=$(jq -n --argjson all "$all" --argjson prs "$prs" --argjson br "$branches" '
  # Declared files -> normalized prefixes: directories end with "/", files are exact; "" = repository root.
  def prefixes: (. // "") | gsub("\\([^)]*\\)"; "") | gsub("`"; "") | [splits("[,;\\n]")]
    | map(gsub("^\\s+|\\s+$"; "") | gsub("^[-*]\\s+"; "")) | map(select(length > 0 and (test("\\s") | not)))
    | map(if test("\\*") then (sub("\\*.*$"; "") | sub("[^/]*$"; "")) else . end);
  def overlap($a; $b): any($a[]; . as $x | any($b[]; . as $y | ($x | startswith($y)) or ($y | startswith($x))));
  # Works for GitHub issue-form bodies ("### Declared files") and plain "## Declared files" / "Key: value" bodies.
  def files: ((.body // "") | capture("#{2,3} Declared files\\s*\\n(?<f>[\\s\\S]*?)(?=\\n#{2,3} |$)"; null) | .f) // "";
  def attended: (.body // "") | test("(Attended:\\s*yes|#{2,3}\\s*Attended\\s*\\n+\\s*yes\\b)"; "i");
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
  | ($free | map(select((.issue_dependencies_summary.blocked_by // 0) > 0))) as $blocked
  | ($free | map(select((.issue_dependencies_summary.blocked_by // 0) == 0))) as $ready0
  | ($ready0 | map(select(. as $t | (($t | files | prefixes) as $tf
        | any($cl[]; overlap($tf; (. | files | prefixes))) | not)))) as $ready1
  | ($ready0 | map(select(. as $t | $ready1 | map(.number) | index($t.number) | not))) as $dropped
  | {
      ready: ($ready1 | map({number, title, milestone: .milestone.title, milestone_no: (.milestone.number // 999),
                attended: attended, declared_files: files, task: tasknum})
              | sort_by([.attended, .milestone_no, .task]) | map(del(.milestone_no, .task))),
      claimed: ($cl | map({number, title, assignee: .assignee.login, updated_at,
                stale: ((now - (.updated_at | fromdateiso8601)) > 86400)})),
      blocked: ($blocked | map({number, title, open_blockers: (.issue_dependencies_summary.blocked_by // 0)})),
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
  change=$(echo "$issue" | jq -r '((.body // "") | capture("OpenSpec change(?::|\\s*\\n+)\\s*(?<c>[a-z0-9-]+)"; "i") | .c) // empty')
  kind=$(echo "$issue" | jq -r '[.labels[].name | select(startswith("type:")) | sub("type:";"")][0]')
  case "$kind" in impl) kind=feat;; decision) kind=docs;; esac
  [ -n "$change" ] || { echo "issue #$target has no OpenSpec change slug (expected 'OpenSpec change: <slug>' or the form field)" >&2; exit 3; }
  branch="$kind/$change-$target"
  # --here: a leftover local branch (e.g. after --release) would make the switch fail AFTER GitHub changed, so refuse now.
  if [ "$here" = 1 ] && git show-ref --verify --quiet "refs/heads/$branch"; then
    echo "--here: a local branch $branch already exists (left from an earlier claim or --release). If it holds nothing you need, remove it with 'git branch -D $branch' (from another worktree if it is checked out here) and run the claim again; GitHub was not changed" >&2; exit 7
  fi
  sha=$(gh api "repos/$repo/git/ref/heads/main" -q .object.sha)
  # Creating the ref is the lock: HTTP 422 if another session already has it.
  run gh api -X POST "repos/$repo/git/refs" -f ref="refs/heads/$branch" -f sha="$sha" >/dev/null \
    || { echo "could not create $branch: already claimed by another session" >&2; exit 4; }
  run gh issue edit "$target" --add-assignee @me >/dev/null
  run gh issue comment "$target" --body "claimed: ${AGENT_NAME:-agent}, $(date -u +%Y-%m-%dT%H:%MZ), branch \`$branch\`" >/dev/null
  if [ "$here" = 1 ]; then
    run git fetch --quiet origin "$branch" \
      && run git switch -q -c "$branch" --track "origin/$branch" \
      || { echo "claimed #$target (branch $branch) but could not switch this checkout; run: git fetch origin $branch && git switch -c $branch --track origin/$branch (if a local branch of that name exists: git branch -f $branch origin/$branch && git switch $branch)" >&2; exit 6; }
  fi
  jq -n --arg b "$branch" --argjson n "$target" --argjson h "$here" --argjson d "$([ "${DRY_RUN:-0}" = 1 ] && echo 1 || echo 0)" '{claimed: $n, branch: $b, switched_here: ($h == 1 and $d == 0)}'
  exit 0
fi

# release
branch=$(echo "$branches" | jq -r --arg s "-$target" 'map(select(endswith($s)))[0] // empty')
[ -n "$branch" ] || { echo "no branch for #$target" >&2; exit 3; }
run gh api -X DELETE "repos/$repo/git/refs/heads/$branch" >/dev/null
run gh issue edit "$target" --remove-assignee @me >/dev/null
run gh issue comment "$target" --body "released: ${AGENT_NAME:-agent}, branch \`$branch\` deleted" >/dev/null
echo "released #$target"
