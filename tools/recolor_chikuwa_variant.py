"""Transfer only baked base color to an approved GLB, preserving all geometry bytes."""
import json, struct
from pathlib import Path

def load(path):
    data=Path(path).read_bytes();n=struct.unpack_from('<I',data,12)[0]
    return json.loads(data[20:20+n]),data[28+n:]

def recolor(normal, colored, output):
    doc, binary=load(normal);source, source_binary=load(colored)
    binary=bytearray(binary)
    replaced={}
    for target, donor in zip(doc['materials'],source['materials'],strict=True):
        p=target.get('pbrMetallicRoughness',{});q=donor.get('pbrMetallicRoughness',{})
        if 'baseColorFactor' in q:p['baseColorFactor']=q['baseColorFactor']
        if 'baseColorTexture' not in p:continue
        ti=doc['textures'][p['baseColorTexture']['index']]['source']
        if ti in replaced:continue
        si=source['textures'][q['baseColorTexture']['index']]['source']
        image=source['images'][si];view=source['bufferViews'][image['bufferView']]
        chunk=source_binary[view.get('byteOffset',0):view.get('byteOffset',0)+view['byteLength']]
        while len(binary)%4:binary.append(0)
        index=len(doc['bufferViews'])
        doc['bufferViews'].append({'buffer':0,'byteOffset':len(binary),'byteLength':len(chunk)})
        binary.extend(chunk)
        doc['images'][ti]={'mimeType':image['mimeType'],'bufferView':index,'name':'toxic_basecolor'}
        replaced[ti]=index
    while len(binary)%4:binary.append(0)
    doc['buffers'][0]['byteLength']=len(binary)
    encoded=json.dumps(doc,separators=(',',':')).encode()
    encoded+=b' '*(-len(encoded)%4)
    Path(output).write_bytes(struct.pack('<III',0x46546c67,2,28+len(encoded)+len(binary))+struct.pack('<II',len(encoded),0x4e4f534a)+encoded+struct.pack('<II',len(binary),0x004e4942)+binary)

if __name__=='__main__':
    root=Path(__file__).resolve().parents[1]/'assets/3d/props/chikuwa/v3'
    recolor(root/'chikuwa.glb',root/'chikuwa_toxic.glb',root/'chikuwa_toxic.glb')
