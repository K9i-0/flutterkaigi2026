"""Validate exported liquid morphs against the physical inner-wall envelope."""
import hashlib,json,math,struct
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent;DIR=ROOT/'04_GAME_ASSETS/3d/props/beer_mug_v2'
raw=(DIR/'beer_mug.glb').read_bytes();size=struct.unpack_from('<I',raw,12)[0];g=json.loads(raw[20:20+size]);binary=raw[28+size:]
def accessor(i):
 a=g['accessors'][i];n={'SCALAR':1,'VEC3':3}[a['type']]
 def read(view_index,offset,count,fmt):
  view=g['bufferViews'][view_index];layout=struct.Struct('<'+fmt)
  start=view.get('byteOffset',0)+offset
  return [layout.unpack_from(binary,start+k*view.get('byteStride',layout.size)) for k in range(count)]
 values=read(a['bufferView'],a.get('byteOffset',0),a['count'],'f'*n) if 'bufferView' in a else [(0,)*n for _ in range(a['count'])]
 if 'sparse' in a:
  sparse=a['sparse'];idx=sparse['indices'];val=sparse['values']
  indices=read(idx['bufferView'],idx.get('byteOffset',0),sparse['count'],{5121:'B',5123:'H',5125:'I'}[idx['componentType']])
  replacements=read(val['bufferView'],val.get('byteOffset',0),sparse['count'],'f'*n)
  for (index,),value in zip(indices,replacements):values[index]=value
 return values
assert {'KHR_materials_transmission','KHR_materials_volume'}<=set(g['extensionsUsed'])
materials={m['name']:m for m in g['materials']}
assert materials['Clear soda lime glass']['pbrMetallicRoughness'].get('metallicFactor')==0
samples=0;highest=0;lowest=1
for mesh in g['meshes']:
 if mesh['name'] not in ['BeerVolume','LiquidSurface','Foam']:continue
 assert mesh['weights']==[0,0,0]
 assert mesh['extras']['targetNames']==['TiltX','TiltZ','Fill']
 for p in mesh['primitives']:
  positions=accessor(p['attributes']['POSITION']);deltas=[accessor(t['POSITION']) for t in p['targets']]
  for fill in [.1,.5,1]:
   height=.18-.13*(1-fill);limit=min(.207-(height+.014),height-.033)/.063
   for angle in range(0,360,45):
    a=math.radians(angle);weights=[limit*math.cos(a)/.46875,limit*math.sin(a)/.46875,1-fill]
    for index,xyz in enumerate(positions):
     value=[xyz[k]+sum(weights[j]*deltas[j][index][k] for j in range(3)) for k in range(3)]
     assert all(math.isfinite(v) for v in value)
     # glTF is Y-up; deformations may change height only.
     assert abs(value[0]-xyz[0])<1e-7 and abs(value[2]-xyz[2])<1e-7
     assert .0269<=value[1]<=.2075,(mesh['name'],fill,value)
     assert math.hypot(value[0],value[2])<=.0641
     lowest=min(lowest,value[1]);highest=max(highest,value[1]);samples+=1
report={'result':'PASS','sha256':hashlib.sha256(raw).hexdigest(),'bytes':len(raw),
 'deformed_vertex_samples':samples,'minimum_height':lowest,'maximum_height':highest,
 'checks':['zero default morph weights','nonmetal transmission + volume','fill .1/.5/1 at 8 tilt azimuths','fixed radius and inner floor/rim bounds']}
(DIR/'validation.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
