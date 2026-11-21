#!/usr/bin/env bash
# Throwaway spike script (S7, issue #13). Runs OpenSpec's own `archive` on every fixture case in a COPY of
# the project structure under a temp dir; never touches the real openspec/ of this repository.
# Usage: spike/openspec-archive/run.sh [case-id ...]    (default: all cases)
# Output: spike/openspec-archive/results/<case>/{cli-output.txt,exit-code.txt,validate-after.txt,before-tree.txt,
#         after-tree.txt,specs.diff,after/specs/,after/archived-change/}   (dates in archive folder names are normalised to <DATE>)
set -u
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
bin="$repo/node_modules/.bin/openspec"
[ -x "$bin" ] || { echo "run 'npm install' in the repo root first" >&2; exit 2; }
export NO_COLOR=1 OPENSPEC_TELEMETRY=0 DO_NOT_TRACK=1 CI=1
cases=("$@")
[ ${#cases[@]} -gt 0 ] || cases=($(ls "$here/cases"))
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
for c in "${cases[@]}"; do
  today="$(date +%Y-%m-%d)"   # per case; a run that crosses midnight stays consistent within a case
  work="$tmp/$c"; mkdir -p "$work"
  cp -R "$here/base/openspec" "$work/openspec"
  cp -R "$here/cases/$c/changes/." "$work/openspec/changes/"
  if [ -d "$here/cases/$c/pre" ]; then
    cp -R "$here/cases/$c/pre/." "$work/"
    find "$work" -depth -name '*@DATE@*' | while read -r p; do mv "$p" "${p//@DATE@/$today}"; done
  fi
  work="$(cd "$work" && pwd -P)"
  out="$here/results/$c"; rm -rf "$out"; mkdir -p "$out"
  (cd "$work" && find openspec -type f | sort) | sed "s/$today/<DATE>/g" > "$out/before-tree.txt"
  cp -R "$work/openspec" "$tmp/$c-before"
  flags="$(cat "$here/cases/$c/flags")"
  # shellcheck disable=SC2086
  (cd "$work" && "$bin" archive $flags "$c" </dev/null) > "$out/cli-output.txt" 2>&1
  echo "$?" > "$out/exit-code.txt"
  (cd "$work" && find openspec -type f | sort) | sed "s/$today/<DATE>/g" > "$out/after-tree.txt"
  (cd "$work" && "$bin" validate --specs --strict --no-interactive </dev/null) > "$out/validate-after.txt" 2>&1
  echo "exit=$?" >> "$out/validate-after.txt"
  diff -ru "$tmp/$c-before/specs" "$work/openspec/specs" 2>&1 | sed -E 's/^(---|\+\+\+) ([^[:space:]]+)[[:space:]]+[0-9]{4}-.*/\1 \2/; s#'"$tmp"'/'"$c"'-before#before#g; s#'"$work"'#.#g' > "$out/specs.diff"
  mkdir -p "$out/after" && [ -d "$work/openspec/specs" ] && cp -R "$work/openspec/specs" "$out/after/specs"
  # archived change folder: also present, as the pre-created fixture, in h18 where the archive fails
  if [ -d "$work/openspec/changes/archive/$today-$c" ]; then cp -R "$work/openspec/changes/archive/$today-$c" "$out/after/archived-change"; fi
  for f in "$out/cli-output.txt" "$out/validate-after.txt"; do sed "s/$today/<DATE>/g; s#$work#<project>#g; s#$tmp#<tmp>#g" "$f" > "$f.tmp" && mv "$f.tmp" "$f"; done
  printf '%-50s exit=%s\n' "$c" "$(cat "$out/exit-code.txt")"
done
