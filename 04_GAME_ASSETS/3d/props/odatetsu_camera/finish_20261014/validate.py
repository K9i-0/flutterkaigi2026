"""Independent GLB structural/coordinate audit; Python standard library only."""
import hashlib
import json
import math
import struct
from pathlib import Path

HERE = Path(__file__).resolve().parent
ASSET = json.loads((HERE/'asset.json').read_text())
data = (HERE/ASSET['file']).read_bytes()
assert data[:4] == b'glTF'
assert struct.unpack_from('<II',data,4) == (2,len(data))
json_len, json_type = struct.unpack_from('<II',data,12)
assert json_type == 0x4e4f534a
doc = json.loads(data[20:20+json_len])
binary_len, binary_type = struct.unpack_from('<II',data,20+json_len)
assert binary_type == 0x004e4942
binary = data[28+json_len:28+json_len+binary_len]
assert len(binary) == binary_len
assert len(doc['buffers']) == 1 and 'uri' not in doc['buffers'][0]
assert not doc.get('animations') and not doc.get('skins')

def accessor(index):
    a = doc['accessors'][index]
    assert not a.get('sparse'), 'Unexpected sparse accessor'
    view = doc['bufferViews'][a['bufferView']]
    format_, size = {5120:('b',1),5121:('B',1),5122:('h',2),5123:('H',2),5125:('I',4),5126:('f',4)}[a['componentType']]
    count = {'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']]
    start = view.get('byteOffset',0) + a.get('byteOffset',0)
    stride = view.get('byteStride',size*count)
    assert start+(a['count']-1)*stride+size*count <= len(binary)
    return [struct.unpack_from('<'+format_*count,binary,start+i*stride) for i in range(a['count'])]

IDENTITY = [[1 if x==y else 0 for y in range(4)] for x in range(4)]
def multiply(a,b):
    return [[sum(a[i][k]*b[k][j] for k in range(4)) for j in range(4)] for i in range(4)]

def matrix(node):
    if 'matrix' in node:
        return [[node['matrix'][4*j+i] for j in range(4)] for i in range(4)]
    x,y,z,w = node.get('rotation',[0,0,0,1])
    scale = node.get('scale',[1,1,1])
    translation = node.get('translation',[0,0,0])
    r = [[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],
         [2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],
         [2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]]
    return [[r[i][j]*scale[j] for j in range(3)]+[translation[i]] for i in range(3)]+[[0,0,0,1]]

world = {}
def traverse(index,parent):
    world[index] = multiply(parent,matrix(doc['nodes'][index]))
    for child in doc['nodes'][index].get('children',[]):
        traverse(child,world[index])
for root in doc['scenes'][doc.get('scene',0)]['nodes']:
    traverse(root,IDENTITY)
all_points = []
body_points = []
triangle_count = vertex_count = 0
for node_id,node in enumerate(doc['nodes']):
    if 'mesh' not in node:
        continue
    for primitive in doc['meshes'][node['mesh']]['primitives']:
        assert primitive.get('mode',4) == 4
        positions = accessor(primitive['attributes']['POSITION'])
        assert all(all(math.isfinite(v) for v in p) for p in positions)
        indices = [i[0] for i in accessor(primitive['indices'])]
        assert len(indices)%3 == 0 and max(indices) < len(positions)
        triangle_count += len(indices)//3
        vertex_count += len(positions)
        transform = world[node_id]
        transformed = [[sum(transform[i][k]*(p[k] if k<3 else 1) for k in range(4)) for i in range(3)] for p in positions]
        all_points.extend(transformed)
        if node['name'] == 'OdatetsuCamera':
            body_points = [p for p in transformed if p[2] < .026]
        if 'TEXCOORD_0' in primitive['attributes']:
            assert all(all(math.isfinite(v) for v in p) for p in accessor(primitive['attributes']['TEXCOORD_0']))

def bounds(points):
    lo = [min(p[i] for p in points) for i in range(3)]
    hi = [max(p[i] for p in points) for i in range(3)]
    return {'min':lo,'max':hi,'size':[hi[i]-lo[i] for i in range(3)]}

measured = bounds(all_points)
body = bounds(body_points)
assert abs(body['size'][0]-.1303)<.0002, body
assert .32 < measured['size'][2] < .36, measured
assert .13 < measured['size'][0] < .17, measured
for axis in range(3):
    for boundary in ('min','max'):
        assert abs(measured[boundary][axis]-ASSET['bounds'][boundary][axis]) < .001
anchor_checks = {}
for name,spec in ASSET['anchors'].items():
    found = [(i,n) for i,n in enumerate(doc['nodes']) if n.get('name')==name]
    assert len(found)==1, name
    i,node = found[0]
    assert 'mesh' not in node, name
    m = world[i]
    assert max(abs(m[a][b]-(1 if a==b else 0)) for a in range(3) for b in range(3)) < 1e-6
    distance = math.dist([m[a][3] for a in range(3)],spec['position'])
    assert distance < 1e-7, (name,distance)
    anchor_checks[name] = {'position':[m[a][3] for a in range(3)],'identity_axes':True,'error_metres':distance}
images=[]
for im in doc.get('images',[]):
    assert 'uri' not in im and 'bufferView' in im
    view = doc['bufferViews'][im['bufferView']]
    start = view.get('byteOffset',0)
    payload = binary[start:start+view['byteLength']]
    assert len(payload)==view['byteLength']
    images.append({'name':im.get('name'),'mime_type':im['mimeType'],'bytes':len(payload),
                   'sha256':hashlib.sha256(payload).hexdigest()})
assert images
names = {n.get('name') for n in doc['nodes']}
assert {'BrandLabel','ModelLabel','LensBadge','FocusRing'} <= names
sha = hashlib.sha256(data).hexdigest()
assert sha==ASSET['sha256']
report={'passed':True,'sha256':sha,'file_bytes':len(data),'mesh_count':len(doc['meshes']),
        'vertices_after_export_splits':vertex_count,'triangles':triangle_count,
        'bounds':measured,'body_bounds':body,'anchors':anchor_checks,'embedded_images':images,
        'checks':['GLB chunk lengths and embedded buffer','finite mesh/UV data and valid triangle indices',
                  'body width and assembled length','identity anchor axes and documented positions',
                  'exact-label mesh presence','embedded textures','asset SHA matches'],
        'visual_audit':'Separate rendered views; structural validation does not recognize text or certify watertight geometry.'}
(HERE/'validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(report,ensure_ascii=False,indent=2))
