"""Validate shared topology, skin and animation for both game-ready variants."""
import json, math, struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]/'04_GAME_ASSETS/3d/props/chikuwa'
def load(path):
    data=path.read_bytes();length=struct.unpack_from('<I',data,12)[0]
    return json.loads(data[20:20+length]),data[28+length:]
def values(asset,i):
    j,blob=asset;a=j['accessors'][i];v=j['bufferViews'][a['bufferView']]
    dim={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']]
    fmt={5126:'f',5125:'I',5123:'H',5121:'B'}[a['componentType']]
    size=struct.calcsize(fmt)*dim;offset=v.get('byteOffset',0)+a.get('byteOffset',0)
    return [struct.unpack_from('<'+fmt*dim,blob,offset+k*v.get('byteStride',size)) for k in range(a['count'])]
for folder in ['game_v3','v3']:
    a,b=[load(ROOT/folder/(name+'.glb')) for name in ['chikuwa','chikuwa_toxic']]
    triangles=0
    for p,q in zip(a[0]['meshes'][0]['primitives'],b[0]['meshes'][0]['primitives'],strict=True):
        for key,i in p['attributes'].items():
            assert values(a,i)==values(b,q['attributes'][key]),(folder,key)
        assert values(a,p['indices'])==values(b,q['indices'])
        pos=values(a,p['attributes']['POSITION'])
        assert all(math.isfinite(x) for v in pos for x in v)
        assert all(0<=v[0]<len(pos) for v in values(a,p['indices']))
        assert all(abs(sum(w)-1)<1e-5 for w in values(a,p['attributes']['WEIGHTS_0']))
        triangles+=len(values(a,p['indices']))//3
    assert a[0]['nodes']==b[0]['nodes']
    assert len(a[0]['skins'][0]['joints'])==9
    for aa,bb in zip(a[0]['animations'],b[0]['animations'],strict=True):
        assert aa['channels']==bb['channels']
        for sa,sb in zip(aa['samplers'],bb['samplers'],strict=True):
            for key in ['input','output']:assert values(a,sa[key])==values(b,sb[key])
            t=values(a,sa['input']);v=values(a,sa['output'])
            assert abs(t[-1][0]-t[0][0]-1.6)<1e-5
            assert max(abs(x-y) for x,y in zip(v[0],v[-1]))<1e-5
    result={'status':'pass','triangles':triangles,'bones':9,'duration':1.6,'checks':['identical geometry / UV / normals / weights','identical bones and animation','finite positions and valid indices','normalized weights','loop endpoints']}
    (ROOT/folder/'variants_validation.json').write_text(json.dumps(result,indent=2)+'\n')
    print(folder,result)
