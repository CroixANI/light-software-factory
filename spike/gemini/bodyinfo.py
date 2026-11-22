#!/usr/bin/env python3 -I
"""Spike 3.6 throwaway: summarise one model request body saved by mock-api.mjs (MOCK_DUMP).
Usage: bodyinfo.py <req.bin> [--canaries] [--tools] [--last N] [--cfg]
 --canaries: count of every CANARY-* string in the whole body (E8: what reached the model's context)
 --tools: names of the declared tools; --cfg: generationConfig + labels keys; --last N: the last N contents (role, part kind, text/response cut to 300 chars)"""
import json, re, sys
p = sys.argv[1]; raw = open(p, 'rb').read().decode('utf-8', 'replace'); d = json.loads(raw)
a = sys.argv[2:]
if '--canaries' in a:
    c = {}
    for m in re.findall(r'CANARY[A-Z0-9_-]*', raw): c[m] = c.get(m, 0) + 1
    print('canaries:', json.dumps(c, sort_keys=True))
if '--tools' in a:
    names = [f['name'] for t in d.get('tools', []) for f in t.get('functionDeclarations', [])]
    print('tools:', ' '.join(names))
if '--cfg' in a:
    print('generationConfig:', json.dumps(d.get('generationConfig'))); print('labels:', json.dumps(d.get('labels'))[:300])
if '--last' in a:
    n = int(a[a.index('--last') + 1]); cs = d['contents'][-n:]
    for c in cs:
        for pt in c['parts']:
            k = [x for x in pt if x != 'thoughtSignature']
            if 'text' in pt: s = pt['text']
            else: s = json.dumps(pt.get('functionResponse') or pt.get('functionCall') or pt)
            print(f"{c.get('role')} {k}: {s[:300]!r}")
print('contents:', len(d['contents']), 'bytes:', len(raw))
