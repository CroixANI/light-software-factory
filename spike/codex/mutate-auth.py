# Spike 3.3 throwaway (E2): write a MUTATED COPY of a codex auth.json so refresh paths can be exercised without touching the owner's real
# refresh token. The refresh token is always replaced by a dummy, so a refresh attempt can only fail and cannot rotate the real one.
# Usage: python3 -I mutate-auth.py <src auth.json> <dest> <mode>   modes: old-last-refresh | bad-access-token | both
# Prints only field NAMES and non-secret facts, never token values.
import json, sys, datetime, os
src, dest, mode = sys.argv[1:4]
d = json.load(open(src))
d['tokens']['refresh_token'] = 'rt_DUMMY_for_spike_not_a_real_token'
if mode in ('old-last-refresh', 'both'):
    d['last_refresh'] = (datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=30)).strftime('%Y-%m-%dT%H:%M:%S.%fZ')
if mode in ('bad-access-token', 'both'):
    t = d['tokens']['access_token']; head, payload, sig = t.split('.')
    d['tokens']['access_token'] = '.'.join([head, payload, 'A' * len(sig)])   # signature destroyed, claims unchanged
fd = os.open(dest, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o400)
with os.fdopen(fd, 'w') as f: json.dump(d, f)
print('wrote', os.path.basename(dest), 'mode', mode, 'last_refresh', d['last_refresh'])
