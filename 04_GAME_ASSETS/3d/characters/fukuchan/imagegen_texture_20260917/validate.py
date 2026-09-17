"""Validate the standalone exported GLB; no external dependencies."""
import json, struct, hashlib
from pathlib import Path
p=Path(__file__).resolve().parent
path=p/'fukuchan_texture_fixed.glb'; data=path.read_bytes()
magic,version,length=struct.unpack_from('<4sII',data)
assert magic==b'glTF' and version==2 and length==len(data)
n,kind=struct.unpack_from('<II',data,12);assert kind==0x4e4f534a
g=json.loads(data[20:20+n]);assert len(g['meshes'])==1
assert all('uri' not in a for a in g['buffers'])
assert all('bufferView' in a and 'uri' not in a for a in g['images'])
report={'file':path.name,'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest(),'meshes':len(g['meshes']),'primitives':sum(len(m['primitives']) for m in g['meshes']),'embedded_images':len(g['images']),'skins':len(g.get('skins',[])),'animations':len(g.get('animations',[]))}
(p/'glb_validation.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
