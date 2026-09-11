import collections,json,pathlib
root=pathlib.Path(__file__).resolve().parent.parent/'tmp'/'hst-audit'
files=sorted((p for p in root.glob('*.json') if p.stem.isdigit()),key=lambda p:int(p.stem))
effects=collections.Counter()
for file in files:
    try: data=json.loads(file.read_text(encoding='utf-8-sig'))
    except (ValueError,OSError): continue
    local=collections.Counter()
    def walk(p):
        if p is None:return
        if p.get('match')=='ADBE Effect Parade':
            for fx in p.get('children',[]):
                if fx:local[fx['match']]+=1
        for child in p.get('children',[]):walk(child)
    for c in data.get('compositions',[]):
        for l in c['layers']:
            for p in l['properties']:walk(p)
    effects.update(local.keys())
    if file.stem=='0':
        print('FIRST PROJECT',data['path'])
        print('COMPS',[(c['name'],len(c['layers']),c['duration']) for c in data.get('compositions',[])])
        print('EFFECTS',dict(local))
print('INSPECTED',len(files),'EFFECT USAGE BY PROJECT',dict(effects))
