"""Replace a GLB's mesh, retaining its original skeleton and animation bytes.

python3 tools/replace_glb_skinned_mesh.py original.glb mesh.glb output.glb
"""
import copy, json, struct, sys
from pathlib import Path

class Glb:
    def __init__(self,path):
        raw=Path(path).read_bytes();n=struct.unpack_from('<I',raw,12)[0]
        self.doc=json.loads(raw[20:20+n]);size=struct.unpack_from('<I',raw,20+n)[0]
        self.bin=bytearray(raw[28+n:28+n+size])
    def rows(self,index):
        a=self.doc['accessors'][index];v=self.doc['bufferViews'][a['bufferView']]
        width={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']]
        fmt='<'+{5121:'B',5123:'H',5125:'I',5126:'f'}[a['componentType']]*width
        base=v.get('byteOffset',0)+a.get('byteOffset',0);stride=v.get('byteStride',struct.calcsize(fmt))
        return [(base+i*stride,struct.unpack_from(fmt,self.bin,base+i*stride),fmt) for i in range(a['count'])]
    def write(self,path):
        self.doc['buffers'][0]['byteLength']=len(self.bin)
        text=json.dumps(self.doc,separators=(',',':')).encode();text+=b' '*(-len(text)%4)
        binary=self.bin+b'\0'*(-len(self.bin)%4)
        Path(path).write_bytes(struct.pack('<III',0x46546c67,2,28+len(text)+len(binary))+struct.pack('<I4s',len(text),b'JSON')+text+struct.pack('<I4s',len(binary),b'BIN\0')+binary)

def compact(g):
    """Drop replaced geometry and textures while copying retained bytes exactly."""
    d=g.doc
    primitives=[p for m in d['meshes'] for p in m['primitives']]
    def keep(key,used):
        used=sorted(set(used));mapping={old:new for new,old in enumerate(used)}
        d[key]=[d[key][i] for i in used]
        return mapping
    remap=keep('materials',[p['material'] for p in primitives])
    for p in primitives:p['material']=remap[p['material']]
    infos=[]
    def find(obj):
        if isinstance(obj,dict):
            for k,v in obj.items():
                if k.endswith('Texture') and isinstance(v,dict) and 'index' in v:infos.append(v)
                else:find(v)
        elif isinstance(obj,list):
            for v in obj:find(v)
    find(d['materials'])
    remap=keep('textures',[v['index'] for v in infos])
    for v in infos:v['index']=remap[v['index']]
    remap=keep('images',[t['source'] for t in d['textures'] if 'source' in t])
    for t in d['textures']:
        if 'source' in t:t['source']=remap[t['source']]
    remap=keep('samplers',[t['sampler'] for t in d['textures'] if 'sampler' in t])
    for t in d['textures']:
        if 'sampler' in t:t['sampler']=remap[t['sampler']]
    refs=[]
    for p in primitives:
        refs.append((p,'indices'))
        refs.extend((p['attributes'],k) for k in p['attributes'])
        for target in p.get('targets',[]):refs.extend((target,k) for k in target)
    refs.extend((s,'inverseBindMatrices') for s in d.get('skins',[]) if 'inverseBindMatrices' in s)
    for a in d.get('animations',[]):
        for s in a['samplers']:refs.extend([(s,'input'),(s,'output')])
    remap=keep('accessors',[obj[k] for obj,k in refs])
    for obj,k in refs:obj[k]=remap[obj[k]]
    refs=[]
    for a in d['accessors']:
        if 'bufferView' in a:refs.append((a,'bufferView'))
        if 'sparse' in a:
            for k in ('indices','values'):refs.append((a['sparse'][k],'bufferView'))
    refs.extend((im,'bufferView') for im in d['images'] if 'bufferView' in im)
    remap=keep('bufferViews',[obj[k] for obj,k in refs])
    for obj,k in refs:obj[k]=remap[obj[k]]
    packed=bytearray()
    for v in d['bufferViews']:
        packed.extend(b'\0'*(-len(packed)%4));offset=v.get('byteOffset',0)
        data=g.bin[offset:offset+v['byteLength']];v['byteOffset']=len(packed);packed.extend(data)
    g.bin=packed

def replace(source,mesh_source,destination):
    old,new=Glb(source),Glb(mesh_source)
    names=lambda g:[g.doc['nodes'][i]['name'] for i in g.doc['skins'][0]['joints']]
    old_names,new_names=names(old),names(new)
    assert set(new_names)<=set(old_names),(old_names,new_names)
    mapping=[old_names.index(n) for n in new_names]
    old_ib=[row for _,row,_ in old.rows(old.doc['skins'][0]['inverseBindMatrices'])]
    new_ib=[row for _,row,_ in new.rows(new.doc['skins'][0]['inverseBindMatrices'])]
    assert max(abs(a-b) for i,row in enumerate(new_ib) for a,b in zip(row,old_ib[mapping[i]]))<1e-4,'Rest transforms differ'
    seen=set()
    for mesh in new.doc['meshes']:
        for primitive in mesh['primitives']:
            idx=primitive['attributes']['JOINTS_0']
            if idx in seen:continue
            seen.add(idx)
            for offset,row,fmt in new.rows(idx):struct.pack_into(fmt,new.bin,offset,*[mapping[j] for j in row])
    keys=['bufferViews','accessors','images','samplers','textures','materials']
    offsets={k:len(old.doc.setdefault(k,[])) for k in keys}
    old.bin.extend(b'\0'*(-len(old.bin)%4));base=len(old.bin)
    for view in new.doc['bufferViews']:
        view['buffer']=0;view['byteOffset']=view.get('byteOffset',0)+base
    for a in new.doc['accessors']:
        if 'bufferView' in a:a['bufferView']+=offsets['bufferViews']
        if 'sparse' in a:
            for k in ('indices','values'):a['sparse'][k]['bufferView']+=offsets['bufferViews']
    for im in new.doc.get('images',[]):im['bufferView']+=offsets['bufferViews']
    for texture in new.doc.get('textures',[]):
        if 'source' in texture:texture['source']+=offsets['images']
        if 'sampler' in texture:texture['sampler']+=offsets['samplers']
    def textures(obj):
        if isinstance(obj,dict):
            for k,v in obj.items():
                if k.endswith('Texture') and isinstance(v,dict) and 'index' in v:v['index']+=offsets['textures']
                else:textures(v)
        elif isinstance(obj,list):
            for v in obj:textures(v)
    for material in new.doc['materials']:textures(material)
    mesh=copy.deepcopy(new.doc['meshes'][0])
    for p in mesh['primitives']:
        p['indices']+=offsets['accessors'];p['material']+=offsets['materials']
        p['attributes']={k:v+offsets['accessors'] for k,v in p['attributes'].items()}
        for t in p.get('targets',[]):
            for k in t:t[k]+=offsets['accessors']
    old.doc['meshes'][0]=mesh
    for k in keys:old.doc[k].extend(new.doc.get(k,[]))
    for key in ('extensionsUsed','extensionsRequired'):
        if key in new.doc:old.doc[key]=sorted(set(old.doc.get(key,[])+new.doc[key]))
    # Explicit unlit material survives even exporters that drop zero emission.
    for material in old.doc['materials']:
        if material.get('name','').startswith('SobayaEyeInteriorBlack'):
            material['pbrMetallicRoughness']={'baseColorFactor':[0,0,0,1],'metallicFactor':0,'roughnessFactor':1}
            material.setdefault('extensions',{})['KHR_materials_unlit']={}
    old.doc['extensionsUsed']=sorted(set(old.doc.get('extensionsUsed',[])+['KHR_materials_unlit']))
    old.bin.extend(new.bin);compact(old);old.write(destination)
    print(json.dumps({'output':str(destination),'joints':len(old_names),'animations':len(old.doc.get('animations',[]))}))

if __name__=='__main__':replace(*sys.argv[1:])
