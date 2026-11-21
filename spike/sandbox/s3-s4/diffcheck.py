#!/usr/bin/env python3
"""Spike throwaway (task 2.2): a minimal model of the orchestrator's diff check (architecture §5 steps 3-5), enough for S4.
Usage: diffcheck.py manifest <repo> <out.json>  |  diffcheck.py check <repo> <manifest.json> <role: builder|restore|reviewer>
Manifest = path -> {sha256, mode, link} for every entry under <repo>, excluding the top-level .git. The check lists added/changed/removed entries and
flags: protected paths (lock files, workflow/instruction/settings files, anything under .factory/), symlinks, mode changes, any change at all for a reviewer/restore role.
Exit 0 = nothing flagged, 1 = flagged. This is a model, not the product's diff check."""
import fnmatch, hashlib, json, os, sys, stat
PROTECTED = ["packages.lock.json", "**/packages.lock.json", "package-lock.json", "**/package-lock.json", ".github", ".github/*", ".github/**", ".factory/**", ".factory",
             "CLAUDE.md", "**/CLAUDE.md", "AGENTS.md", "**/AGENTS.md", "GEMINI.md", "**/GEMINI.md", "CLAUDE.local.md", "**/CLAUDE.local.md", ".mcp.json", "**/.mcp.json",
             ".claude/**", ".codex/**", ".gemini/**", ".cursor/**", ".git", ".git/**", "**/.git", "**/.git/**", "Directory.Build.props", "Directory.Packages.props", "nuget.config", "NuGet.Config", ".npmrc"]
def protected(p): return any(fnmatch.fnmatchcase(p, g) for g in PROTECTED)
def walk(repo):
    m = {}
    for d, dirs, files in os.walk(repo, followlinks=False):
        rel = os.path.relpath(d, repo)
        if rel == ".": dirs[:] = [x for x in dirs if x != ".git"]
        for n in dirs + files:
            p = os.path.normpath(os.path.join(rel, n)); full = os.path.join(d, n); st = os.lstat(full)
            e = {"mode": stat.S_IMODE(st.st_mode)}
            if stat.S_ISLNK(st.st_mode): e["link"] = os.readlink(full)
            elif stat.S_ISREG(st.st_mode): e["sha256"] = hashlib.sha256(open(full, "rb").read()).hexdigest()
            else: e["dir"] = True
            m[p] = e
    return m
cmd = sys.argv[1]
if cmd == "manifest":
    json.dump(walk(sys.argv[2]), open(sys.argv[3], "w"), indent=1, sort_keys=True); sys.exit(0)
repo, mf, role = sys.argv[2], sys.argv[3], sys.argv[4]
old, new = json.load(open(mf)), walk(repo)
flags, lines = [], []
for p in sorted(set(old) | set(new)):
    o, n = old.get(p), new.get(p)
    if o == n: continue
    kind = "added" if o is None else "removed" if n is None else "changed"
    if o and n and o.get("dir") and n.get("dir") and o["mode"] == n["mode"]: continue
    why = []
    if protected(p): why.append("protected path")
    if n and "link" in n: why.append("symlink")
    if o and n and o["mode"] != n["mode"]: why.append("mode change")
    if role in ("reviewer", "restore"): why.append(f"{role} role may not change the repo")
    lines.append(f"{kind:8} {p}" + (f"  <- FLAGGED: {', '.join(why)}" if why else ""))
    if why: flags.append(p)
print("\n".join(lines) if lines else "(no differences)")
print(f"RESULT: {'FLAGGED ' + str(len(flags)) + ' path(s)' if flags else 'nothing flagged'}")
sys.exit(1 if flags else 0)
