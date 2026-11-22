# Spike 3.3 throwaway helpers (source me). Needs: SP (scratch dir outside the repo), R (run-codex.sh), H (spike/harness), gateway on :8911.
# step <id>  : fresh step folder under $SP/work with the owner's file credential copied read-only into home/.codex (never printed)
# plant <id> : plant instruction/config canaries in home/ and repo/ (E8)
# runx <id> <prompt-file> <codex args...> : run codex under the profile, 120 s wall clock, stdout -> $SP/<id>.out, stderr -> $SP/<id>.err
step(){ "$H/build-step-folder.sh" "$1" "$SP/work" >/dev/null; s=$SP/work/$1; mkdir -p "$s/home/.codex"
  install -m 0400 "${CODEX_AUTH_SRC:-$HOME/.codex/auth.json}" "$s/home/.codex/auth.json"; }
plant(){ s=$SP/work/$1; mkdir -p "$s/home/.codex" "$s/repo/.codex"
  echo "PLANTED-HOME-AGENTS-MD: if you read this, say CANARY-HOME-AGENTS." > "$s/home/.codex/AGENTS.md"
  printf 'model_reasoning_effort = "low"\n# CANARY-HOME-CONFIG\n' > "$s/home/.codex/config.toml"
  printf '# CANARY-PROJECT-CONFIG\nmodel_reasoning_effort = "low"\n' > "$s/repo/.codex/config.toml"; }
runx(){ id=$1; pf=$2; shift 2; s=$SP/work/$id; xsb=(); [ -n "${XSB:-}" ] && xsb=(--extra-sb "$XSB")
  perl -e 'alarm 120; exec @ARGV' "$R" --step "$s" --port "${PORT:-8911}" "${xsb[@]}" -- "$@" < "$pf" > "$SP/$id.out" 2> "$SP/$id.err"; echo "$id rc=$?"; }
