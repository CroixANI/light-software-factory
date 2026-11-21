#!/usr/bin/env python3
"""Throwaway stdlib validator for the JSON Schema subset used by result.schema.json
(no jsonschema package installed). Usage: validate.py <result.json> [schema.json]
Supports: type, const, enum, required, properties, additionalProperties(false), items,
minItems, minLength, maxLength, allOf, if/then. Exit 0 valid, 1 invalid."""
import json, sys, os

TYPES = {"object": dict, "array": list, "string": str, "integer": int, "number": (int, float), "boolean": bool}

def check(v, s, path, errs):
    if "type" in s and not (isinstance(v, TYPES[s["type"]]) and not (s["type"] != "boolean" and isinstance(v, bool))):
        errs.append(f"{path}: expected {s['type']}"); return
    if "const" in s and v != s["const"]: errs.append(f"{path}: must be {s['const']!r}")
    if "enum" in s and v not in s["enum"]: errs.append(f"{path}: {v!r} not in {s['enum']}")
    if isinstance(v, str):
        if len(v) < s.get("minLength", 0): errs.append(f"{path}: too short")
        if len(v) > s.get("maxLength", 10**9): errs.append(f"{path}: too long")
    if isinstance(v, list):
        if len(v) < s.get("minItems", 0): errs.append(f"{path}: fewer than {s['minItems']} items")
        for i, x in enumerate(v):
            if "items" in s: check(x, s["items"], f"{path}[{i}]", errs)
    if isinstance(v, dict):
        for k in s.get("required", []):
            if k not in v: errs.append(f"{path}: missing {k!r}")
        props = s.get("properties", {})
        for k, x in v.items():
            if k in props: check(x, props[k], f"{path}.{k}", errs)
            elif s.get("additionalProperties") is False: errs.append(f"{path}: unexpected {k!r}")
    for sub in s.get("allOf", []):
        if "if" in sub:
            probe = []; check(v, sub["if"], path, probe)
            if not probe and "then" in sub: check(v, sub["then"], path, errs)
        else: check(v, sub, path, errs)

def main():
    here = os.path.dirname(os.path.abspath(__file__))
    schema = json.load(open(sys.argv[2] if len(sys.argv) > 2 else os.path.join(here, "result.schema.json")))
    try: doc = json.load(open(sys.argv[1]))
    except Exception as e: print(f"INVALID: not JSON: {e}"); return 1
    errs = []; check(doc, schema, "$", errs)
    print("VALID" if not errs else "INVALID:\n  " + "\n  ".join(errs))
    return 1 if errs else 0

if __name__ == "__main__": sys.exit(main())
