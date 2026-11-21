#!/bin/bash
# Spike throwaway (task 2.2): S3 (network) and S4 (writes) under the task-1.4 Seatbelt profiles.
# Shapes: reviewer-readonly and builder (the repo's profiles; only the network rule moves from base.sb into each shape file), plus two MODELLED shapes
# the spike needs (architecture §5): check-step = builder exec/writes, network only to its own service ports, no gateway;
# restore = no repo write, writes only the item's package overlay, its own gateway. They live in a patched COPY of spike/harness/sandbox
# (spike/work/patched-s3s4); spike/harness itself is not modified.
# Usage: spike/sandbox/s3-s4/run.sh      Output: results/<shape>/*.json|txt, results/baseline/*, profiles/*.sb (paths sanitised: <work> <repo> <home> <user>)
# Needs: macOS, python3, node >= 22. Creates spike/work/s3-s4 (git-ignored), starts local listeners/proxies and stops them at the end.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd -P)"; spike="$(cd "$here/../.." && pwd -P)"; H="$spike/harness"; REPO="$(cd "$spike/.." && pwd -P)"
W="$spike/work/s3-s4"; PATCHED="$spike/work/patched-s3s4"
case "$W" in */spike/work/s3-s4) rm -rf "${W:?}" "${PATCHED:?}";; *) echo "unexpected work dir" >&2; exit 2;; esac
mkdir -p "$W"; W="$(cd "$W" && pwd -P)"
GA=8911 GB=8912 S1=8913 S2=8914 X=8915 GR=8916 GC=8917   # gateways of step a / b / restore / c; two check-Step service ports; an unrelated "orchestrator API" port
CACHES="$W/caches"; OVERLAY="$W/items/1/packages"; OVERLAY2="$W/items/2/packages"
mkdir -p "$CACHES/nuget" "$CACHES/npm" "$OVERLAY" "$OVERLAY2" "$W/outside-dir" "$W/factory-state"
reset_state() {   # the caches are deliberately owner-WRITABLE, so a denial below is the profile's doing and not file modes
  find "${CACHES:?}" "${W:?}/items" -type f -delete; rm -rf "${CACHES:?}/npm/evil"
  echo "cache-file" > "$CACHES/nuget/pkg.txt"; echo "cache-file" > "$CACHES/npm/index.txt"; echo "cache-file" > "$CACHES/nuget/other.txt"
  echo "overlay-of-item-1" > "$OVERLAY/existing.txt"; echo "overlay-of-item-2" > "$OVERLAY2/existing.txt"
}
reset_state; echo '{"canary":"state"}' > "$W/factory-state/state.json"

# ---- patched profile copy: network rule moves from base.sb into the shapes; two modelled shapes ----
cp -R "$H/sandbox" "$PATCHED"
python3 - "$PATCHED" "$CACHES" "$OVERLAY" "$S1" "$S2" <<'PY'
import sys
d, caches, overlay, s1, s2 = sys.argv[1:6]
base = open(f"{d}/base.sb").read()
net = '(allow network-outbound (remote ip (string-append "localhost:" (param "PORT"))))\n'
assert net in base
open(f"{d}/base.sb", "w").write(base.replace(net, ";; (network rule moved into each shape file by spike/sandbox/s3-s4/run.sh)\n"))
rd = f'(allow file-read* (subpath "{caches}") (subpath "{overlay}"))   ; shared caches + item overlay: read-only for every Step\n'
rev = open(f"{d}/reviewer-readonly.sb").read(); bld = open(f"{d}/builder.sb").read()
open(f"{d}/reviewer-readonly.sb", "w").write(rev + net + rd)
open(f"{d}/builder.sb", "w").write(bld + net + rd)
open(f"{d}/check-step.sb", "w").write(";; MODEL (spike/sandbox/s3-s4/run.sh): check-step = builder shape below, network replaced by the Step's own service ports\n" + bld + f'(allow network-outbound (remote ip "localhost:{s1}") (remote ip "localhost:{s2}"))   ; MODEL: only the Step\'s own service ports, no gateway\n' + rd)
rst = "\n".join(l for l in bld.splitlines() if '/repo"' not in l)   # builder exec/read rules minus the repo write rule
open(f"{d}/restore.sb", "w").write(";; MODEL (spike/sandbox/s3-s4/run.sh): restore = builder exec/read rules WITHOUT the repo write; writes only the item overlay\n" + rst + "\n" + net + rd + f'(allow file-write* (subpath "{overlay}"))   ; MODEL: restore writes only the item overlay\n')
l = open(f"{d}/run-sandboxed.sh").read()
assert "^(reviewer-readonly|builder)$" in l
open(f"{d}/run-sandboxed.sh", "w").write(l.replace("^(reviewer-readonly|builder)$", "^(reviewer-readonly|builder|check-step|restore)$"))
PY
SB="$PATCHED"

# ---- Step folders ----
mk() { local d; d="$("$H/build-step-folder.sh" "$1" "$W")"; (cd "$d" && pwd -P); }
A="$(mk step-a)"; C="$(mk step-c)"; D="$(mk step-d)"; E="$(mk step-e)"; B="$(mk step-b)"
echo "other-step-canary" > "$B/home/notes.txt"
HOSTLIP="$(ipconfig getifaddr en0 2>/dev/null || true)"

# ---- listeners and gateways (outside the sandbox) ----
PIDS=()
cat > "$W/listeners.py" <<'PY'
import socket, sys, threading, time
def serve(port):
    s = socket.socket(); s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1); s.bind(("127.0.0.1", port)); s.listen(8)
    while True:
        c, _ = s.accept(); c.sendall(f"svc-{port}\n".encode()); c.close()
for p in map(int, sys.argv[1:]): threading.Thread(target=serve, args=(p,), daemon=True).start()
time.sleep(1800)
PY
python3 "$W/listeners.py" "$S1" "$S2" "$X" >/dev/null 2>&1 </dev/null &
PIDS+=($!)
for spec in "$GA:step-a:example.com" "$GB:step-b:example.com" "$GR:step-restore:registry.npmjs.org,api.nuget.org" "$GC:step-c:example.com"; do
  IFS=: read -r p n al <<<"$spec"
  node "$H/proxy/connect-proxy.mjs" --port "$p" --step "$n" --allow "$al" >"$W/proxy-$n.log" 2>&1 </dev/null & PIDS+=($!)
done
trap 'kill "${PIDS[@]}" 2>/dev/null; wait 2>/dev/null' EXIT
sleep 2

out="$here/results"; rm -rf "${out:?}"; mkdir -p "$out/baseline" "$here/profiles"
sanitize() { sed -e "s#$W#<work>#g" -e "s#$REPO#<repo>#g" -e "s#$HOME#<home>#g" -e "s#$(id -un)#<user>#g" ${HOSTLIP:+-e "s#$HOSTLIP#<lan-ip>#g"}; }
sbx() { local shape=$1 step=$2 port=$3; shift 3; "$SB/run-sandboxed.sh" --shape "$shape" --step "$step" --port "$port" --cli-dir "$here" -- "$@"; }   # cli-dir = this folder (probe.py)
fcli() { local shape=$1 step=$2 port=$3; shift 3; echo prompt | "$SB/run-sandboxed.sh" --shape "$shape" --step "$step" --port "$port" --cli-dir "$H/fake-cli" -- \
  python3 "$H/fake-cli/fake-cli.py" --shape "$([ "$shape" = reviewer-readonly ] && echo reviewer-readonly || echo builder)" --step "$step" "$@"; }

# ---- S3 ----
NET=( "direct-1.1.1.1:443=tcp:1.1.1.1:443" "direct-8.8.8.8:53-tcp=tcp:8.8.8.8:53" "direct-udp-dns=udp:8.8.8.8:53" "direct-ext-ip-on-gw-a-port=tcp:1.1.1.1:$GA" "direct-ext-ip-on-gw-c-port=tcp:1.1.1.1:$GC" "direct-ext-ip-on-gw-restore-port=tcp:1.1.1.1:$GR" "dns-github.com=dns:github.com"
      "mdns-responder-socket=unix:/var/run/mDNSResponder" "listen-127.0.0.1:8920=listen:8920"
      "gw-a=tcp:127.0.0.1:$GA" "gw-b=tcp:127.0.0.1:$GB" "gw-c=tcp:127.0.0.1:$GC" "gw-restore=tcp:127.0.0.1:$GR" "svc-1=tcp:127.0.0.1:$S1" "svc-2=tcp:127.0.0.1:$S2" "orch-api=tcp:127.0.0.1:$X"
      "gw-a-via-localhost=tcp:localhost:$GA" "gw-a-via-ipv6=tcp:::1:$GA" "gw-a-via-127.0.0.2=tcp:127.0.0.2:$GA" )
[ -n "$HOSTLIP" ] && NET+=( "gw-a-via-lan-ip=tcp:$HOSTLIP:$GA" )
runnet() { # name shape step gateway-port [extra probe specs...]
  local name=$1 shape=$2 S=$3 port=$4; shift 4; local o="$out/$name"; mkdir -p "$o"; find "$S/io/out" -type f -delete
  sbx "$shape" "$S" "$port" python3 "$here/probe.py" --out "$S/io/out/net.json" "${NET[@]}" "$@" >/dev/null 2>"$o/probe.stderr"; echo $? > "$o/probe.exit"; cp "$S/io/out/net.json" "$o/net.json" 2>/dev/null
  fcli "$shape" "$S" "$port" --attack reach-github --attack push --attack "connect-port=$GB" --attack "connect-port=$S1" >/dev/null 2>"$o/fake-cli.stderr"; cp "$S/io/out/attacks.json" "$o/fake-cli-attacks.json" 2>/dev/null
}
runnet reviewer-readonly reviewer-readonly "$A" "$GA" "proxy-allowed-host=proxy:$GA:example.com" "proxy-other-host=proxy:$GA:github.com"
runnet builder builder "$C" "$GC" "proxy-allowed-host=proxy:$GC:example.com" "proxy-other-host=proxy:$GC:github.com"
runnet check-step check-step "$D" "$S1"
runnet restore restore "$E" "$GR" "proxy-allowed-host=proxy:$GR:registry.npmjs.org" "proxy-other-host=proxy:$GR:example.com"
python3 "$here/probe.py" --out "$out/baseline/net.json" "${NET[@]}" "proxy-allowed-host=proxy:$GA:example.com" "proxy-other-host=proxy:$GA:github.com"

# ---- S4 ----
WR() { local S=$1
  echo "repo-new=write:$S/repo/new.txt" "repo-edit-existing=append:$S/repo/src/calc.py" "repo-lockfile-packages=write:$S/repo/packages.lock.json" "repo-lockfile-npm=write:$S/repo/package-lock.json" \
       "repo-edit-CLAUDE.md=append:$S/repo/CLAUDE.md" "repo-mkdir-github=mkdir:$S/repo/.github" "repo-symlink-out=symlink:$W/outside-dir>$S/repo/link-out" "repo-write-through-symlink=write:$S/repo/link-out/pwn.txt" \
       "out-io/out=write:$S/io/out/artifact.txt" "out-home=write:$S/home/note.txt" "out-tmp=write:$S/tmp/scratch.txt" \
       "deny-step-root=write:$S/root-file.txt" "deny-io/in=write:$S/io/in/x.txt" "deny-io-dir=mkdir:$S/io/extra" "deny-mkdir-step=mkdir:$S/extra" \
       "deny-parent-dir=write:$(dirname "$S")/outside-marker.txt" "deny-other-step-home=write:$B/home/pwn.txt" "deny-other-step-edit=append:$B/home/notes.txt" "deny-factory-state=write:$W/factory-state/pwn.txt" \
       "deny-owner-home=write:$MARKER" "deny-rename-out=rename:$S/repo/README.md>$S/README.md" "deny-symlink-at-root=symlink:/etc>$S/link-root" \
       "cache-read=read:$CACHES/nuget/pkg.txt" "cache-new-file=write:$CACHES/nuget/new.txt" "cache-append=append:$CACHES/nuget/pkg.txt" "cache-truncate=truncate:$CACHES/nuget/pkg.txt" \
       "cache-rename-in=rename:$CACHES/nuget/pkg.txt>$S/home/stolen.txt" "cache-chmod=chmod:$CACHES/npm/index.txt" "cache-mkdir=mkdir:$CACHES/npm/evil" "cache-unlink=unlink:$CACHES/nuget/other.txt" \
       "overlay-read=read:$OVERLAY/existing.txt" "overlay-new-file=write:$OVERLAY/new.txt" "overlay-append=append:$OVERLAY/existing.txt" "overlay-other-item=write:$OVERLAY2/new.txt" "overlay-other-item-edit=append:$OVERLAY2/existing.txt"
}
MARKER="$HOME/.s3s4-marker-$$"      # in the owner's home: must NOT be created (removed if it is)
diffrole() { case $1 in reviewer-readonly) echo reviewer;; restore) echo restore;; *) echo builder;; esac; }
runw() { local name=$1 shape=$2 S=$3 port=$4 o="$out/$1"; mkdir -p "$o"
  python3 "$here/diffcheck.py" manifest "$S/repo" "$W/manifest-$name.json"
  sbx "$shape" "$S" "$port" python3 "$here/probe.py" --out "$S/io/out/writes.json" $(WR "$S") >/dev/null 2>"$o/writes.stderr"; echo $? > "$o/writes.exit"; cp "$S/io/out/writes.json" "$o/writes.json" 2>/dev/null
  if [ -e "$MARKER" ]; then echo "MARKER CREATED IN OWNER HOME" > "$o/owner-home-marker.txt"; rm -f "$MARKER"; fi
  if [ -e "$(dirname "$S")/outside-marker.txt" ]; then echo "marker created outside the Step folder" > "$o/outside-marker.txt"; rm -f "$(dirname "$S")/outside-marker.txt"; fi
  python3 "$here/diffcheck.py" check "$S/repo" "$W/manifest-$name.json" "$(diffrole "$shape")" > "$o/diffcheck.txt" 2>&1; echo $? > "$o/diffcheck.exit"
  { [ -e "$W/outside-dir/pwn.txt" ] && echo "pwn.txt EXISTS in the symlink target" || echo "nothing written through the symlink"; } > "$o/through-symlink-effect.txt"; rm -f "$W/outside-dir/pwn.txt"
  (cd "$CACHES" && find . -mindepth 1 | sort | while read -r f; do echo "$f $(stat -f '%z %Sp' "$f")"; done) > "$o/caches-after.txt"
  (cd "$W/items" && find . -type f | sort | while read -r f; do echo "$f $(stat -f %z "$f")"; done) > "$o/overlays-after.txt"
  reset_state
}
# benign builder run: edits and new source/test files only; the diff check must let it through
S="$("$H/build-step-folder.sh" step-benign "$W")"; S="$(cd "$S" && pwd -P)"; mkdir -p "$out/builder-benign"
python3 "$here/diffcheck.py" manifest "$S/repo" "$W/manifest-benign.json"
sbx builder "$S" "$GC" python3 "$here/probe.py" --out "$S/io/out/benign.json" "benign-edit-source=append:$S/repo/src/calc.py" "benign-new-source=write:$S/repo/src/new_module.py" "benign-new-test=write:$S/repo/src/test_new.py" >/dev/null 2>&1
cp "$S/io/out/benign.json" "$out/builder-benign/benign.json"; python3 "$here/diffcheck.py" check "$S/repo" "$W/manifest-benign.json" builder > "$out/builder-benign/diffcheck.txt" 2>&1; echo $? > "$out/builder-benign/diffcheck.exit"
runw reviewer-readonly-writes reviewer-readonly "$A" "$GA"
runw builder-writes builder "$C" "$GC"
runw check-step-writes check-step "$D" "$S1"
runw restore-writes restore "$E" "$GR"
# baseline: the same writes without the sandbox, in a throwaway Step, to show every target is writable (a denial above is the profile's doing)
BASE="$(mk step-base)"; MARKER="$W/baseline-home-marker"
python3 "$here/probe.py" --out "$out/baseline/writes.json" $(WR "$BASE")

cp "$PATCHED"/{base,builder,reviewer-readonly,check-step,restore}.sb "$here/profiles/"
for n in step-a step-b step-restore step-c; do { echo "== gateway $n"; grep -E '"ev":"(denied|open|refused|listening)"' "$W/proxy-$n.log" | sed -E "s/^\{\"t\":\"[^\"]*\",/{/" | head -8; } >> "$out/proxy-events.txt"; done
find "$out" "$here/profiles" -type f \( -name '*.json' -o -name '*.txt' -o -name '*.stderr' -o -name '*.exit' -o -name '*.sb' \) -print0 | while IFS= read -r -d '' f; do sanitize < "$f" > "$f.tmp" && mv "$f.tmp" "$f"; done
find "$out" -name "*.stderr" -size 0 -delete
echo "done: $out"
