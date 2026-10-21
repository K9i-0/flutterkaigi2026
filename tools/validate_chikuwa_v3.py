"""Validate the high-detail normal chikuwa asset independently of its builder."""
import json,math,struct
from pathlib import Path
path=Path(__file__).resolve().parents[1]/'assets/3d/props/chikuwa/v3/chikuwa.glb'
data=path.read_bytes();length=struct.unpack_from('<I',data,12)[0];j=json.loads(data[20:20+length]);blob=data[28+length:]
def values(i):
    a=j['accessors'][i];v=j['bufferViews'][a['bufferView']]
    dim={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']];fmt={5126:'f',5125:'I',5123:'H',5121:'B'}[a['componentType']]
    size=struct.calcsize(fmt)*dim;offset=v.get('byteOffset',0)+a.get('byteOffset',0)
    return [struct.unpack_from('<'+fmt*dim,blob,offset+k*v.get('byteStride',size)) for k in range(a['count'])]
triangles=0
for primitive in j['meshes'][0]['primitives']:
    attrs=primitive['attributes'];positions=values(attrs['POSITION']);normals=values(attrs['NORMAL'])
    assert all(math.isfinite(x) for p in positions for x in p)
    assert all(abs(sum(x*x for x in n)-1)<1e-4 for n in normals)
    assert all(0<=i[0]<len(positions) for i in values(primitive['indices']))
    assert all(abs(sum(w)-1)<1e-5 for w in values(attrs['WEIGHTS_0']))
    assert all(0<=i<9 for ids in values(attrs['JOINTS_0']) for i in ids)
    triangles+=len(values(primitive['indices']))//3
assert triangles==123520
assert len(j['skins'][0]['joints'])==9
for sampler in j['animations'][0]['samplers']:
    t=values(sampler['input']);v=values(sampler['output'])
    assert abs(t[-1][0]-t[0][0]-1.6)<1e-5
    assert max(abs(x-y) for x,y in zip(v[0],v[-1]))<1e-5
assert len(j['meshes'][0]['primitives'])==3
print(json.dumps({'status':'pass','triangles':triangles,'bones':9,'duration':1.6,'materials':len(j['materials']),'bytes':len(data),'checks':['finite vertices','unit normals','valid indices','normalized skin weights','bone index range','loop endpoints','separate skin and cut surface']},indent=2))
