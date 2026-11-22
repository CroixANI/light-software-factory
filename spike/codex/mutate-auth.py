# Spike 3.3 throwaway (E2): write a MUTATED COPY of a codex auth.json so refresh paths can be exercised without touching the owner's real
# refresh token. The refresh token is always replaced by a dummy, so a refresh attempt can only fail and cannot rotate the real one.
# Usage: python3 -I mutate-auth.py <src auth.json> <dest> <mode>   modes: dummy-refresh | old-last-refresh | bad-access-token | both
#        python3 -I mutate-auth.py <src auth.json> show-exp   prints hours until `exp` of the access and id token (no token values)
# dummy-refresh = only the refresh token is replaced (what lib.sh `step` installs); the others also change last_refresh / the access-token signature.
# Prints only field NAMES and non-secret facts, never token values.
import json, sys, datetime, os
d = json.load(open(sys.argv[1]))
if sys.argv[2] == 'show-exp':
    import base64, time
    for k in ('access_token', 'id_token'):
        p = d['tokens'][k].split('.')[1]; p += '=' * (-len(p) % 4); c = json.loads(base64.urlsafe_b64decode(p))
        print(k, 'exp in hours: %.1f' % ((c['exp'] - time.time()) / 3600), 'age in hours: %.1f' % ((time.time() - c['iat']) / 3600))
    print('last_refresh', d['last_refresh']); sys.exit(0)
dest, mode = sys.argv[2:4]
d['tokens']['refresh_token'] = 'rt_DUMMY_for_spike_not_a_real_token'
if mode in ('old-last-refresh', 'both'):
    d['last_refresh'] = (datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=30)).strftime('%Y-%m-%dT%H:%M:%S.%fZ')
if mode in ('bad-access-token', 'both'):
    t = d['tokens']['access_token']; head, payload, sig = t.split('.')
    d['tokens']['access_token'] = '.'.join([head, payload, 'A' * len(sig)])   # signature destroyed, claims unchanged
if os.path.exists(dest): os.unlink(dest)   # an existing 0400 file cannot be opened for writing
fd = os.open(dest, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o400)
with os.fdopen(fd, 'w') as f: json.dump(d, f)
print('wrote', os.path.basename(dest), 'mode', mode, 'last_refresh', d['last_refresh'])
