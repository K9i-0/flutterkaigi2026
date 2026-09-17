"""Validate speech deltas, skinning and original clip samples in game v3 GLB."""
import json, struct, math, hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'04_GAME_ASSETS/3d/hazard_adopted/v3_preview_20260917'
SOURCE=ROOT/'04_GAME_ASSETS/3d/characters/fukuchan/skin_even_20260917/fukuchan.glb'
def read(path):
 raw=path.read_bytes();size=struct.unpack_from('<I',raw,12)[0];g=json.loads(raw[20:20+size]);binary=raw[28+size:]
 def acc(index):
  a=g['accessors'][index];width={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']]
  fmt=struct.Struct('<'+{5121:'B',5123:'H',5125:'I',5126:'f'}[a['componentType']]*width)
  def unpack(view,offset,count,f):
   v=g['bufferViews'][view];start=v.get('byteOffset',0)+offset;stride=v.get('byteStride',f.size)
   return [f.unpack_from(binary,start+i*stride) for i in range(count)]
  rows=unpack(a['bufferView'],a.get('byteOffset',0),a['count'],fmt) if 'bufferView' in a else [(0,)*width]*a['count']
  if 'sparse' in a:
   sp=a['sparse'];ix=sp['indices'];val=sp['values'];f=struct.Struct('<'+{5121:'B',5123:'H',5125:'I'}[ix['componentType']])
   for (i,),v in zip(unpack(ix['bufferView'],ix.get('byteOffset',0),sp['count'],f),unpack(val['bufferView'],val.get('byteOffset',0),sp['count'],fmt)):rows[i]=v
  assert all(math.isfinite(v) for row in rows for v in row)
  return rows
 return g,acc
src,sa=read(SOURCE);dst,da=read(OUT/'fukuchan.glb')
def channels(g,a,acc):
 return {(g['nodes'][c['target']['node']]['name'],c['target']['path']):(acc(a['samplers'][c['sampler']]['input']),acc(a['samplers'][c['sampler']]['output'])) for c in a['channels']}
max_error=0
for a in src['animations']:
 b=next(b for b in dst['animations'] if b['name']==a['name']);ac=channels(src,a,sa);bc=channels(dst,b,da)
 assert ac.keys()==bc.keys(),a['name']
 for key,(times,rows) in ac.items():
  bt,br=bc[key];assert len(times)==len(bt) and len(rows)==len(br),(a['name'],key)
  assert max(abs(x[0]-y[0]) for x,y in zip(times,bt))<1e-5
  for x,y in zip(rows,br):
   delta=max(abs(v-w) for v,w in zip(x,y))
   if key[1]=='rotation':delta=min(delta,max(abs(v+w) for v,w in zip(x,y)))
   max_error=max(max_error,delta)
assert max_error<1e-4,max_error
moved={};max_delta=0
for mesh in dst['meshes']:
 names=mesh.get('extras',{}).get('targetNames',[])
 if not names:continue
 assert 'SpeechOpen' in names and 'SpeechNarrow' in names
 for p in mesh['primitives']:
  positions=da(p['attributes']['POSITION']);weights=da(p['attributes']['WEIGHTS_0'])
  assert all(abs(sum(w)-1)<1e-5 for w in weights)
  for name,target in zip(names,p['targets']):
   for pos,d in zip(positions,da(target['POSITION'])):
    length=math.sqrt(sum(x*x for x in d));max_delta=max(max_delta,length)
    if length>1e-6:
     # glTF is Y-up. Deltas must remain local to the mouth and chin.
     assert abs(pos[0])<.035 and 1.426<pos[1]<1.57,(name,pos)
     moved[name]=moved.get(name,0)+1
assert all(moved.get(n,0)>0 for n in ['SpeechOpen','SpeechNarrow'])
assert .005<max_delta<.006
assert not any('Teeth' in m.get('name','') for m in dst['materials'])
lining=[]
for mesh in dst['meshes']:
 for p in mesh['primitives']:
  if dst['materials'][p['material']]['name']=='FukuchanOralLining':
   assert 'COLOR_0' in p['attributes']
   lining.extend(da(p['attributes']['COLOR_0']))
assert lining and len(set(lining))>=2
assert all(c[0]>c[1]>c[2]>0 for c in lining)
assert max(c[0] for c in lining)>min(c[0] for c in lining)*3
report={'result':'PASS','sourceSha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'sha256':hashlib.sha256((OUT/'fukuchan.glb').read_bytes()).hexdigest(),'originalClips':len(src['animations']),'gameClips':len(dst['animations']),'maximumAnimationSampleError':max_error,'movedVertices':moved,'maximumMorphDisplacement':max_delta,'teeth':0,'oralGradientVerified':True,'scope':'finite localized mouth deltas, normalized weights, original animation sample comparison; visual QA separate'}
(OUT/'speech_validation.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
