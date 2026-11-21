#!/bin/bash
# Spike throwaway: build work/<step-id>/{home,io/in,io/out,tmp,repo}, all mode 0700.
# repo/ is an APFS clone (cp -c) of sample-repo/, then a throwaway git repo is initialised in it.
# Usage: build-step-folder.sh <step-id> [work-root]   (work-root defaults to spike/work)
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
step="${1:?usage: $0 <step-id> [work-root]}"
root="${2:-$here/../work}"
[[ "$step" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || { echo "bad step-id: $step" >&2; exit 2; }
umask 077
mkdir -p "$root"; chmod 0700 "$root"
dir="$root/$step"
[ ! -e "$dir" ] || { echo "exists: $dir" >&2; exit 1; }
mkdir -m 0700 "$dir"
for d in home io io/in io/out tmp; do mkdir -m 0700 "$dir/$d"; done
# -c = clonefile(2) on APFS; fails loudly on other filesystems instead of silently copying.
cp -cR "$here/sample-repo" "$dir/repo"
chmod -R go-rwx "$dir/repo"
(
  cd "$dir/repo"
  git init -q
  git add -A -f
  git -c user.name=spike -c user.email=spike@example.invalid -c commit.gpgsign=false commit -q -m "sample repo"
)
echo "$dir"
