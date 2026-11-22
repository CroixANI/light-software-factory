import json,collections,sys
c=collections.Counter(); up=0; down=0
for l in open(sys.argv[1]):
    try: d=json.loads(l)
    except Exception: continue
    if d.get('ev')=='open': c[d['host']+':'+str(d['port'])]+=1
    if d.get('ev')=='close': up+=d.get('bytes_up',0); down+=d.get('bytes_down',0)
print(dict(c), "bytes_up",up,"bytes_down",down)
