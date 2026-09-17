"""Update the existing speech GLB's matching cheek atlas without re-exporting motion."""
from pathlib import Path
import struct,json,hashlib,copy
O=Path(__file__).resolve().parent;ROOT=O.parents[4];GAME=ROOT/'04_GAME_ASSETS/3d/hazard_adopted/v3_preview_20260917'
def read(p):
 d=p.read_bytes();n=struct.unpack_from('<I',d,12)[0];return json.loads(d[20:20+n]),d[28+n:]
def image(g,b):
 m=next(m for m in g['materials'] if m['name']=='Front faithful skin');i=g['textures'][m['pbrMetallicRoughness']['baseColorTexture']['index']]['source'];vi=g['images'][i]['bufferView'];v=g['bufferViews'][vi];return vi,b[v.get('byteOffset',0):v.get('byteOffset',0)+v['byteLength']]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
src=O/'fukuchan.glb';g,b=read(src);_,atlas=image(g,b)
p=GAME/'fukuchan.glb';g,b=read(p);before=copy.deepcopy(g);vi,old=image(g,b)
original,originalbin=read(O.parent/'rig_v3_20260917/fukuchan.glb');_,expected=image(original,originalbin)
assert old in (expected,atlas),'Unexpected game texture; refusing to overwrite another edit'
oldsha=sha(p)
if old!=atlas:
 (O/'game_before.glb').write_bytes(p.read_bytes())
 offset=len(b);padding=b'\0'*((-offset)%4);offset+=len(padding);binary=b+padding+atlas;binary+=b'\0'*((-len(binary))%4)
 g['bufferViews'][vi]={'buffer':0,'byteOffset':offset,'byteLength':len(atlas)};g['buffers'][0]['byteLength']=len(binary)
 j=json.dumps(g,separators=(',',':')).encode();j+=b' '*((-len(j))%4);p.write_bytes(struct.pack('<4sII',b'glTF',2,28+len(j)+len(binary))+struct.pack('<I4s',len(j),b'JSON')+j+struct.pack('<I4s',len(binary),b'BIN\0')+binary)
 after,ab=read(p);assert ab[:len(b)]==b
 for key in before:
  if key not in ('bufferViews','buffers'):assert before[key]==after[key],key
 for i,v in enumerate(before['bufferViews']):
  if i!=vi:assert v==after['bufferViews'][i]
 report={'beforeSha256':oldsha,'sha256':sha(p),'nonImageBuffersExact':True,'geometryWeightsMorphsAnimationsExact':True,'clips':len(g['animations'])};(O/'game_validation.json').write_text(json.dumps(report,indent=2)+'\n')
r=json.loads((GAME/'speech_build.json').read_text());r.update(source=str(src.relative_to(ROOT)),sourceSha256=sha(src),sha256=sha(p));(GAME/'speech_build.json').write_text(json.dumps(r,indent=2)+'\n')
mp=ROOT/'04_GAME_ASSETS/3d/hazard_adopted/manifest.json';r=json.loads(mp.read_text());r['fukuchan'].update(source=str(src.relative_to(ROOT)),sourceSha256=sha(src),sha256=sha(p));mp.write_text(json.dumps(r,indent=2,ensure_ascii=False)+'\n')
print('Game texture updated; 23 clips and speech morph buffers preserved.')
