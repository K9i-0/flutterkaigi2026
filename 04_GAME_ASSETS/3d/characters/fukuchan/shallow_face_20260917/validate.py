import json,struct,hashlib
from pathlib import Path
P=Path(__file__).resolve().parent
report={}
for name in ['mild','shallow','balanced']:
 b=(P/f'fukuchan_{name}.glb').read_bytes();magic,version,length=struct.unpack_from('<4sII',b);assert magic==b'glTF' and version==2 and length==len(b)
 n=struct.unpack_from('<I',b,12)[0];g=json.loads(b[20:20+n]);assert len(g['meshes'])==1 and not g.get('skins') and not g.get('animations');assert all('bufferView' in im and 'uri' not in im for im in g['images'])
 report[name]={'bytes':len(b),'sha256':hashlib.sha256(b).hexdigest(),'meshes':len(g['meshes']),'primitives':len(g['meshes'][0]['primitives']),'embedded_images':len(g['images'])}
 if name=='balanced':
  for m in g['materials']:
   if m['name'] in ['Front faithful skin','Natural sclera','Balanced forehead skin']:
    assert m['pbrMetallicRoughness']['baseColorFactor']==[.45,.45,.45,1]
    assert abs(m['emissiveFactor'][0]-.55)<1e-6
(P/'validation.json').write_text(json.dumps(report,indent=2)+'\n');print(report)
