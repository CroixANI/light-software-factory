#!/usr/bin/env python3
"""Spike throwaway (task 2.1): attacks the fake CLI does not have. Python 3 stdlib only. Runs INSIDE the sandbox (and unsandboxed as the baseline).
Usage: extra.py --orch-pid N --canary-env STR --canary-arg STR --out FILE
Every attack only reads or probes. The only signal sent to another process is SIGTERM to the stand-in `sleep`-like process the harness started (the 'orchestrator')."""
import argparse, ctypes, ctypes.util, json, os, signal, struct, sys

ap = argparse.ArgumentParser()
ap.add_argument("--orch-pid", type=int, required=True)
ap.add_argument("--canary-env", required=True)
ap.add_argument("--canary-arg", required=True)
ap.add_argument("--out", required=True)
a = ap.parse_args()
libc = ctypes.CDLL("/usr/lib/libSystem.B.dylib", use_errno=True)
res = []
def rec(name, outcome, detail=""): res.append({"attack": name, "outcome": outcome, "detail": str(detail)[:300]})
def errname(e): return f"errno {e} ({os.strerror(e)})"

CTL_KERN, KERN_PROC, KERN_PROC_ALL, KERN_PROCARGS2 = 1, 14, 0, 49

def procargs(pid):
    """sysctl(CTL_KERN, KERN_PROCARGS2, pid) -> (bytes or None, errno)"""
    mib = (ctypes.c_int * 3)(CTL_KERN, KERN_PROCARGS2, pid)
    size = ctypes.c_size_t(0)
    if libc.sysctl(mib, 3, None, ctypes.byref(size), None, 0) != 0: return None, ctypes.get_errno()
    buf = ctypes.create_string_buffer(size.value)
    if libc.sysctl(mib, 3, buf, ctypes.byref(size), None, 0) != 0: return None, ctypes.get_errno()
    return buf.raw[:size.value], 0

def try_procargs(name, pid):
    data, e = procargs(pid)
    if data is None: rec(name, "denied" if e in (1, 13) else "error", errname(e)); return
    env_hit, arg_hit = a.canary_env.encode() in data, a.canary_arg.encode() in data
    rec(name, "succeeded", f"read {len(data)} bytes of argv+environ; environment canary {'FOUND' if env_hit else 'not found'}; argv canary {'FOUND' if arg_hit else 'not found'}")

try_procargs("procargs2-orchestrator", a.orch_pid)
try_procargs("procargs2-parent", os.getppid())
try_procargs("procargs2-pid1-launchd", 1)
try_procargs("procargs2-self", os.getpid())      # control: the call itself works for own pid

# proc_listallpids
n = libc.proc_listallpids(None, 0)
if n <= 0: rec("proc_listallpids", "denied" if ctypes.get_errno() in (1, 13) else "error", errname(ctypes.get_errno()))
else:
    pids = (ctypes.c_int * (n + 64))()
    got = libc.proc_listallpids(pids, ctypes.sizeof(pids))
    if got <= 0: rec("proc_listallpids", "denied" if ctypes.get_errno() in (1, 13) else "error", errname(ctypes.get_errno()))
    else: rec("proc_listallpids", "succeeded", f"{got} pids listed; orchestrator pid {'visible' if a.orch_pid in list(pids)[:got] else 'not visible'}")

# proc_name / proc_pidpath of another process
buf = ctypes.create_string_buffer(1024)
r = libc.proc_name(a.orch_pid, buf, 1024)
rec("proc_name-orchestrator", "succeeded" if r > 0 else ("denied" if ctypes.get_errno() in (1, 13) else "error"), buf.value.decode(errors="replace") if r > 0 else errname(ctypes.get_errno()))
r = libc.proc_pidpath(a.orch_pid, buf, 1024)
rec("proc_pidpath-orchestrator", "succeeded" if r > 0 else ("denied" if ctypes.get_errno() in (1, 13) else "error"), buf.value.decode(errors="replace") if r > 0 else errname(ctypes.get_errno()))

# sysctl KERN_PROC_ALL (what ps uses for the process table)
mib = (ctypes.c_int * 3)(CTL_KERN, KERN_PROC, KERN_PROC_ALL)
size = ctypes.c_size_t(0)
if libc.sysctl(mib, 3, None, ctypes.byref(size), None, 0) != 0: rec("sysctl-kern.proc.all", "denied" if ctypes.get_errno() in (1, 13) else "error", errname(ctypes.get_errno()))
else: rec("sysctl-kern.proc.all", "succeeded", f"process table of {size.value} bytes readable")

# signals to the orchestrator
try: os.kill(a.orch_pid, 0); rec("kill-0-orchestrator", "succeeded", "signal 0 delivered")
except OSError as e: rec("kill-0-orchestrator", "denied" if e.errno in (1, 13) else "error", errname(e.errno))
try: os.kill(a.orch_pid, signal.SIGTERM); rec("kill-TERM-orchestrator", "succeeded", "SIGTERM delivered to the stand-in")
except OSError as e: rec("kill-TERM-orchestrator", "denied" if e.errno in (1, 13) else "error", errname(e.errno))
try: os.kill(1, 0); rec("kill-0-pid1", "succeeded", "signal 0 delivered")
except OSError as e: rec("kill-0-pid1", "denied" if e.errno in (1, 13) else "error", errname(e.errno))

# Mach: bootstrap_look_up of services that are excluded by design (and one control that is not excluded in the baseline)
port = ctypes.c_uint.in_dll(libc, "bootstrap_port")
libc.bootstrap_look_up.argtypes = [ctypes.c_uint, ctypes.c_char_p, ctypes.POINTER(ctypes.c_uint)]
SERVICES = [
    ("com.apple.coreservices.launchservicesd", "LaunchServices (open)"),
    ("com.apple.CoreServices.coreservicesd", "LaunchServices (open)"),
    ("com.apple.SecurityServer", "Keychain / security"),
    ("com.apple.securityd.xpc", "Keychain / security (xpc)"),
    ("com.apple.pasteboard.1", "pasteboard"),
    ("com.apple.coreservices.appleevents", "Apple Events (osascript target)"),
    ("com.apple.system.opendirectoryd.libinfo", "directory service (candidate, not added)"),
    ("com.apple.cfprefsd.daemon", "preferences daemon"),
    ("com.apple.trustd", "trust evaluation"),
]
for svc, why in SERVICES:
    p = ctypes.c_uint(0)
    kr = libc.bootstrap_look_up(port.value, svc.encode(), ctypes.byref(p))
    rec(f"mach-lookup:{svc}", "succeeded" if kr == 0 else ("denied" if kr == 1100 else "error"), f"kern_return {kr}; {why}")
with open(a.out, "w") as f: json.dump(res, f, indent=2)
