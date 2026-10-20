"""Check shared mesh/rig/animation, valid skin weights and loop endpoints."""
import json,struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]/'04_GAME_ASSETS/3d/props/chikuwa'
def load(name):
    data=(ROOT/name).read_bytes();length=struct.unpack_from('<I',data,12)[0]
    j=json.loads(data[20:20+length]);start=20+length
    return j,data[start+8:]
def values(asset,i):
    j,blob=asset;a=j['accessors'][i];v=j['bufferViews'][a['bufferView']]
    dim={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']]
    fmt={5126:'f',5125:'I',5123:'H',5121:'B'}[a['componentType']]
    size=struct.calcsize(fmt)*dim;offset=v.get('byteOffset',0)+a.get('byteOffset',0)
    return [struct.unpack_from('<'+fmt*dim,blob,offset+k*v.get('byteStride',size)) for k in range(a['count'])]
a,b=load('chikuwa.glb'),load('chikuwa_toxic.glb')
for key in ['nodes','skins','animations']:assert a[0][key]==b[0][key],key
p=a[0]['meshes'][0]['primitives'][0];q=b[0]['meshes'][0]['primitives'][0]
for k,i in p['attributes'].items():assert values(a,i)==values(b,q['attributes'][k]),k
assert values(a,p['indices'])==values(b,q['indices'])
assert all(abs(sum(w)-1)<1e-5 for w in values(a,p['attributes']['WEIGHTS_0']))
assert len(a[0]['skins'][0]['joints'])==9
assert max(max(j) for j in values(a,p['attributes']['JOINTS_0']))<9
for sampler in a[0]['animations'][0]['samplers']:
    t=values(a,sampler['input']);v=values(a,sampler['output'])
    assert abs(t[-1][0]-t[0][0]-1.6)<1e-5
    assert max(abs(x-y) for x,y in zip(v[0],v[-1]))<1e-5
print('PASS: identical mesh, UVs, weights, rig and animation; 9 bones; normalized weights; seamless 1.6s loop')
