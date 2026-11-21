#!/usr/bin/env python3
"""Spike throwaway (task 2.2): network and write probes that the fake CLI does not have. Python 3 stdlib only.
Runs INSIDE the sandbox (and unsandboxed as the baseline). Every probe only attempts; files it creates are markers the harness removes.
Usage: probe.py --out FILE OP...   where OP is NAME=KIND:ARG[:ARG...]  (the ARGs of tcp/udp/connect-proxy are HOST:PORT[...] so split on the first ':' only)
  tcp:HOST:PORT        connect, read a banner (<=0.5 s)      udp:HOST:PORT      sendto
  dns:HOST             getaddrinfo                           unix:PATH          connect AF_UNIX
  listen:PORT          bind+listen on 127.0.0.1               proxy:PORT:HOST    HTTP CONNECT HOST:443 through 127.0.0.1:PORT, report the status line
  write:PATH           create new file                       append:PATH        open existing for append
  unlink:PATH          remove                                 rename:SRC>DST     rename
  symlink:TARGET>PATH  create symlink                         mkdir:PATH         make directory
  chmod:PATH           chmod 0600                             truncate:PATH      truncate to 0
  read:PATH            read 1 byte / list
Outcome: denied = EPERM/EACCES; refused = ECONNREFUSED (the sandbox let the connection attempt through, nothing listened); error = anything else; succeeded."""
import errno, json, os, socket, sys

DEN = (errno.EPERM, errno.EACCES)
res = []
def rec(name, outcome, detail=""): res.append({"probe": name, "outcome": outcome, "detail": str(detail)[:600]})

def do(kind, arg):
    if kind in ("tcp", "udp"):
        host, port = arg.rsplit(":", 1)
        fam = socket.AF_INET6 if ":" in host else socket.AF_INET
        if kind == "udp":
            s = socket.socket(fam, socket.SOCK_DGRAM); s.sendto(b"x", (host, int(port))); s.close(); return "sent datagram"
        s = socket.socket(fam, socket.SOCK_STREAM); s.settimeout(3); s.connect((host, int(port)))
        s.settimeout(0.5)
        try: b = s.recv(64).decode(errors="replace").strip()
        except Exception: b = ""
        s.close(); return f"connected, banner={b!r}"
    if kind == "dns": return "resolved " + str(socket.getaddrinfo(arg, 443)[0][4][0])
    if kind == "unix":
        s = socket.socket(socket.AF_UNIX); s.settimeout(2); s.connect(arg); s.close(); return "connected"
    if kind == "listen":
        s = socket.socket(); s.bind(("127.0.0.1", int(arg))); s.listen(1); s.close(); return "bound and listening"
    if kind == "proxy":
        port, host = arg.split(":", 1)
        s = socket.create_connection(("127.0.0.1", int(port)), timeout=5)
        s.sendall(f"CONNECT {host}:443 HTTP/1.1\r\nHost: {host}:443\r\n\r\n".encode()); line = s.recv(200).split(b"\r\n")[0].decode(errors="replace"); s.close()
        return "status line: " + line
    if kind == "write":
        with open(arg, "x") as f: f.write("s3-s4 marker (harmless)\n")
        return "created"
    if kind == "append":
        with open(arg, "a") as f: f.write("x")
        return "appended"
    if kind == "unlink": os.unlink(arg); return "removed"
    if kind == "rename": a, b = arg.split(">", 1); os.rename(a, b); return "renamed"
    if kind == "symlink": a, b = arg.split(">", 1); os.symlink(a, b); return "symlink created"
    if kind == "mkdir": os.mkdir(arg); return "created directory"
    if kind == "chmod": os.chmod(arg, 0o600); return "chmod ok"
    if kind == "truncate": os.truncate(arg, 0); return "truncated"
    if kind == "read":
        if os.path.isdir(arg): return f"listed {len(os.listdir(arg))} entries"
        with open(arg, "rb") as f: f.read(1)
        return "read 1 byte"
    raise ValueError("unknown kind " + kind)

args = sys.argv[1:]
out = None
if args[:1] == ["--out"]: out, args = args[1], args[2:]
for spec in args:
    name, _, rest = spec.partition("=")
    kind, _, arg = rest.partition(":")
    try: rec(name, "succeeded", do(kind, arg))
    except ConnectionRefusedError as e: rec(name, "refused", f"{type(e).__name__}: {e}")
    except (OSError, ValueError) as e:
        en = getattr(e, "errno", None)
        rec(name, "denied" if en in DEN else "error", f"{type(e).__name__}: {e}")
if out:
    with open(out, "w") as f: json.dump(res, f, indent=2)
else: print(json.dumps(res, indent=2))
