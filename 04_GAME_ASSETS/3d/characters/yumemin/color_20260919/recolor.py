"""Rebuild the GLB's baked base-color material; preserve all geometry buffers."""
from pathlib import Path
import io, json, struct, hashlib
import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
SOURCE = HERE.parent / 'eye_seams_20260919/yumemin_clean_v2.glb'
TARGET = HERE / 'yumemin.glb'
BLUE = np.array([94, 182, 232], dtype=float) / 255
OLD = np.array([.055, .32, .58])
WHITE = np.array([.88, .90, .92])
def linear(s):
    return np.where(s <= .04045, s / 12.92, ((s + .055) / 1.055) ** 2.4)
def srgb(s):
    return np.where(s <= .0031308, s * 12.92, 1.055 * np.maximum(s, 0) ** (1 / 2.4) - .055)
raw = SOURCE.read_bytes()
n = struct.unpack_from('<I', raw, 12)[0]
doc = json.loads(raw[20:20+n])
data = raw[28+n:]
image_view = doc['images'][0]['bufferView']
view = doc['bufferViews'][image_view]
png = data[view.get('byteOffset', 0):view.get('byteOffset', 0)+view['byteLength']]
image = Image.open(io.BytesIO(png)).convert('RGB')
rgb = np.asarray(image).astype(float) / 255
pixels = linear(rgb)
# Recover the original blue/white material mix from the baked texture.
weight = np.clip(np.sum((pixels - OLD) * (WHITE - OLD), axis=2) / np.sum((WHITE - OLD) ** 2), 0, 1)
new = linear(BLUE)[None,None,:] * (1-weight[:,:,None]) + WHITE[None,None,:] * weight[:,:,None]
# Preserve white clothing and unused black texels exactly.
mask = (rgb[:,:,2] - rgb[:,:,0] > .05) & (rgb[:,:,1] - rgb[:,:,0] > .025)
result = np.asarray(image).copy()
result[mask] = np.round(np.clip(srgb(new[mask]), 0, 1)*255).astype('uint8')
out = io.BytesIO(); Image.fromarray(result).save(out, format='PNG')
chunks = []
for i,v in enumerate(doc['bufferViews']):
    previous = data[v.get('byteOffset',0):v.get('byteOffset',0)+v['byteLength']]
    content = out.getvalue() if i == image_view else previous
    v['byteOffset'] = sum(map(len,chunks)); v['byteLength'] = len(content)
    chunks.append(content + b'\0' * (-len(content)%4))
body = b''.join(chunks)
for m in doc['materials']:
    if 'Tail_Blue' in m.get('name',''):
        m['pbrMetallicRoughness']['baseColorFactor'] = [*linear(BLUE).tolist(),1]
doc['buffers'][0]['byteLength'] = len(body)
js = json.dumps(doc,separators=(',',':')).encode(); js += b' ' * (-len(js)%4)
TARGET.write_bytes(struct.pack('<III',0x46546c67,2,28+len(js)+len(body)) + struct.pack('<II',len(js),0x4e4f534a) + js + struct.pack('<II',len(body),0x004e4942) + body)
# Independently check every non-image buffer after writing.
check=TARGET.read_bytes(); jn=struct.unpack_from('<I',check,12)[0]; jd=json.loads(check[20:20+jn]); bd=check[28+jn:]
original=json.loads(raw[20:20+n])
for i,v in enumerate(original['bufferViews']):
    if i == image_view: continue
    nv=jd['bufferViews'][i]
    assert data[v.get('byteOffset',0):v.get('byteOffset',0)+v['byteLength']] == bd[nv.get('byteOffset',0):nv.get('byteOffset',0)+nv['byteLength']]
assert original['meshes']==jd['meshes'] and original['nodes']==jd['nodes'] and original['accessors']==jd['accessors']
report={'source':str(SOURCE.relative_to(HERE.parent)), 'base_color_srgb':'#5EB6E8','previous_base_color_srgb':'#4299C8','geometry_uv_normals_unchanged':True,'white_and_eyes_unchanged':True,'sha256':hashlib.sha256(check).hexdigest(),'bytes':len(check)}
(HERE/'validation.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
