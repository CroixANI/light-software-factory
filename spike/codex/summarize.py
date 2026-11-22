# Spike 3.3 throwaway: print command / message / error items of a `codex exec --json` stream.
import sys, json
for l in open(sys.argv[1]):
    try: d = json.loads(l)
    except Exception: continue
    it = d.get('item', {})
    t = it.get('type')
    if t == 'command_execution': print(' cmd:', it.get('command'), '| status:', it.get('status'), '| exit:', it.get('exit_code'), '| out:', (it.get('aggregated_output') or '')[:300].replace('\n', '\\n'))
    elif t == 'agent_message': print(' msg:', it['text'][:300].replace('\n', '\\n'))
    elif t == 'error' or d.get('type') == 'error': print(' err:', (d.get('message') or it.get('message') or '')[:200])
    elif d.get('type') == 'turn.completed': print(' usage:', json.dumps(d.get('usage')))
    elif t and t not in ('reasoning',): print(' item:', t, json.dumps(it)[:200])
