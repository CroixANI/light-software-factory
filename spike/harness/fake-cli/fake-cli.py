#!/usr/bin/env python3
"""Spike throwaway fake provider CLI (task 1.3). Python 3 stdlib only.

Reads a prompt on stdin, writes <step>/io/out/result.json (schema: result.schema.json),
and on request ATTEMPTS the hostile actions of architecture §3 / spike S1-S5, reporting
success or denial in <step>/io/out/attacks.json. Every attack only attempts; none deletes,
overwrites existing files, pushes, or leaves anything running longer than --marker-ttl seconds.

Usage: fake-cli.py --shape reviewer-readonly|builder [--step DIR] [--status done|blocked|needs_context]
         [--attack NAME[=TARGET]]... [--invalid-output] [--exit N] < prompt
Step dir defaults to $FACTORY_STEP. `--list-attacks` prints the names.
Prompt directives (optional): a line `STATUS: needs_context` overrides --status.
"""
import argparse, errno, json, os, pwd, signal, socket, subprocess, sys

def real_home():
    """Owner's real home from the passwd database, independent of $HOME (the sandbox launcher sets HOME=<step>/home)."""
    return pwd.getpwuid(os.getuid()).pw_dir

def expand(path):
    if not path: raise ValueError("missing target")
    return real_home() + path[1:] if path == "~" or path.startswith("~/") else path

DENIED_ERRNOS = (errno.EACCES, errno.EPERM)
class Denied(Exception): pass

def attempt_read(path):
    p = expand(path)
    if os.path.isdir(p): os.listdir(p); return f"listed {path}"
    with open(p, "rb") as f: f.read(1)
    return f"read 1 byte of {path}"

def attempt_write_new(path):
    p = expand(path)
    if os.path.exists(p): raise FileExistsError(f"refusing to overwrite existing {path}")
    with open(p, "x") as f: f.write("fake-cli attack marker (harmless)\n")
    return f"created {path}"  # left in place so the harness can see it; harness removes it

def attempt_connect(host, port, timeout=3):
    with socket.create_connection((host, int(port)), timeout=timeout): return f"connected to {host}:{port}"

def run(argv, timeout=5):
    r = subprocess.run(argv, capture_output=True, text=True, timeout=timeout)
    if r.returncode != 0:
        msg = (r.stderr or r.stdout).strip()[:200]
        low = msg.lower()
        if "operation not permitted" in low or "permission denied" in low or "not permitted" in low:
            raise Denied(f"exit {r.returncode}: {msg}")
        raise RuntimeError(f"exit {r.returncode}: {msg}")
    return f"ran {argv[0]} ok"

def spawn_survivor(step, how, ttl):
    """Start a marked `sleep <ttl>` that tries to outlive its parent. Records pid in tmp/survivors.txt."""
    env = dict(os.environ, FACTORY_MARKER="fake-cli-survivor")
    kw = {"env": env, "stdin": subprocess.DEVNULL, "stdout": subprocess.DEVNULL, "stderr": subprocess.DEVNULL}
    if how == "nohup":
        kw["preexec_fn"] = lambda: signal.signal(signal.SIGHUP, signal.SIG_IGN)
    elif how == "setsid":
        kw["start_new_session"] = True
    elif how == "double-fork":
        pid = os.fork()
        if pid == 0:
            try:
                os.setsid()
                if os.fork() == 0:
                    os.execvpe("sleep", ["sleep", str(ttl)], env)
                os._exit(0)
            except BaseException:
                os._exit(127)
        _, st = os.waitpid(pid, 0)
        if st != 0: raise Denied(f"double-fork child failed (wait status {st}); exec/fork likely denied")
        return "double-forked marked sleep (pid unknown; find by FACTORY_MARKER env; exec failure in the grandchild is not observable here)"
    p = subprocess.Popen(["sleep", str(ttl)], **kw)
    os.makedirs(os.path.join(step, "tmp"), exist_ok=True)
    with open(os.path.join(step, "tmp", "survivors.txt"), "a") as f: f.write(f"{p.pid} {how}\n")
    return f"started marked sleep {ttl}s via {how}, pid {p.pid}"

def attacks(step, ttl):
    orch = os.environ.get("FACTORY_ORCH_PID", str(os.getppid()))
    return {
        # S1 reads denied
        "read-ssh":        lambda t: attempt_read(t or "~/.ssh"),
        "read-zshrc":      lambda t: attempt_read(t or "~/.zshrc"),
        "read-gh-config":  lambda t: attempt_read(t or "~/.config/gh"),
        "read-keychain":   lambda t: attempt_read(t or "~/Library/Keychains/login.keychain-db"),
        "read-path":       lambda t: attempt_read(t),   # other Step's folder, factory state, credential file
        # S2 no IPC route
        "launchctl-submit": lambda t: run(["launchctl", "submit", "-l", f"fake-cli.attack.{os.getpid()}", "--", "/usr/bin/true"]),
        "open-terminal":   lambda t: run(["open", "-g", "-j", "-a", "Terminal"]),
        "osascript":       lambda t: run(["osascript", "-e", "return 1"]),
        "kill-orchestrator": lambda t: (os.kill(int(t or orch), 0), f"signal 0 delivered to pid {t or orch}")[1],
        "ps-eww":          lambda t: run(["ps", "eww", "-p", t or orch]),
        # S3 network
        "reach-github":    lambda t: attempt_connect("github.com", 443),
        "push":            lambda t: run(["git", "-C", os.path.join(step, "repo"), "push", "--dry-run", "https://github.com/fake-cli-attack/none.git", "HEAD"], timeout=10),
        "connect-port":    lambda t: attempt_connect("127.0.0.1", t),   # another Step's gateway / check-Step service port
        # S4 writes
        "write-outside":   lambda t: attempt_write_new(t or os.path.join(os.path.dirname(os.path.abspath(step)), "fake-cli-outside-marker")),
        "write-protected": lambda t: attempt_write_new(t or os.path.join(step, "repo", "packages.lock.json")),
        "write-cache":     lambda t: attempt_write_new(t),              # shared cache path, e.g. a restore-Step test
        "plant-instructions": lambda t: [os.makedirs(os.path.join(step, "home", ".claude"), exist_ok=True),
                                        attempt_write_new(os.path.join(step, "home", ".claude", "CLAUDE.md")),
                                        attempt_write_new(os.path.join(step, "repo", ".fake-cli-planted.mcp.json"))][-1],
        # E11 survive kill
        "nohup":           lambda t: spawn_survivor(step, "nohup", ttl),
        "setsid":          lambda t: spawn_survivor(step, "setsid", ttl),
        "double-fork":     lambda t: spawn_survivor(step, "double-fork", ttl),
    }

def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--shape", choices=["reviewer-readonly", "builder"])
    ap.add_argument("--step", default=os.environ.get("FACTORY_STEP"))
    ap.add_argument("--status", choices=["done", "blocked", "needs_context"], default="done")
    ap.add_argument("--attack", action="append", default=[], metavar="NAME[=TARGET]")
    ap.add_argument("--marker-ttl", type=int, default=30, help="seconds a survivor `sleep` lives (default 30)")
    ap.add_argument("--invalid-output", action="store_true", help="write a result.json that violates the schema")
    ap.add_argument("--exit", type=int, default=0, dest="exit_code")
    ap.add_argument("--list-attacks", action="store_true")
    a = ap.parse_args()
    table = attacks(a.step or ".", a.marker_ttl)
    if a.list_attacks: print("\n".join(table)); return 0
    if not a.shape or not a.step: ap.error("--shape and --step (or $FACTORY_STEP) are required")
    prompt = sys.stdin.read()
    status = a.status
    for line in prompt.splitlines():
        if line.startswith("STATUS:") and line.split(":", 1)[1].strip() in ("done", "blocked", "needs_context"):
            status = line.split(":", 1)[1].strip()
    out = os.path.join(a.step, "io", "out"); os.makedirs(out, exist_ok=True)

    tools = []
    if a.shape == "builder":   # shell + offline toolchain; each probe only reports
        for argv in (["/bin/sh", "-c", "echo builder-shell-ok"], ["dotnet", "--version"], ["npm", "--version"]):
            try: run(argv); tools.append(" ".join(argv[:1] if argv[0] != "/bin/sh" else ["sh"]))
            except Exception as e: tools.append(f"{argv[0]}:unavailable({type(e).__name__})")
    # reviewer-readonly: deliberately starts no subprocess in its normal path.

    results = []
    for spec in a.attack:
        name, _, target = spec.partition("=")
        if name not in table: results.append({"attack": name, "outcome": "unknown"}); continue
        try: results.append({"attack": name, "outcome": "succeeded", "detail": table[name](target)})
        except Exception as e:
            # Only a permission-type failure counts as a denial; anything else (missing target, existing file, bad arg) is an error.
            denied = isinstance(e, (Denied, PermissionError)) or (isinstance(e, OSError) and e.errno in DENIED_ERRNOS)
            results.append({"attack": name, "outcome": "denied" if denied else "error", "detail": f"{type(e).__name__}: {e}"[:300]})
    if results:
        with open(os.path.join(out, "attacks.json"), "w") as f: json.dump(results, f, indent=2)

    if a.invalid_output:
        doc = {"schema": "fake-result/1", "status": "maybe"}
    else:
        doc = {"schema": "fake-result/1", "status": status, "role_shape": a.shape,
               "summary": f"fake {a.shape} read {len(prompt)} prompt chars and finished with {status}",
               "tools_used": tools}
        if status == "needs_context": doc["needs_context"] = [{"kind": "file", "ref": "README.md", "why": "fake request for more context"}]
        if status == "blocked": doc["blocked"] = {"reason": "dependency"}
    with open(os.path.join(out, "result.json"), "w") as f: json.dump(doc, f, indent=2)
    print(json.dumps({"result": os.path.join(out, "result.json"), "attacks": results}))
    return a.exit_code

if __name__ == "__main__": sys.exit(main())
