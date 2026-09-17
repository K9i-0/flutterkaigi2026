"""Blender: verify immutable approved geometry/UVs and exported material factors."""
import bpy,json,struct,hashlib
from pathlib import Path
P=Path(__file__).resolve().parent
def snapshot(path):
 bpy.ops.wm.open_mainfile(filepath=str(path));o=next(o for o in bpy.context.scene.objects if o.type=='MESH');m=o.data
 return {'vertices':[tuple(o.matrix_world@v.co) for v in m.vertices],'polygons':[(tuple(p.vertices),p.material_index) for p in m.polygons],'uv':[tuple(v.uv) for v in m.uv_layers[0].data]}
a=snapshot(P.parent/'shallow_face_20260917/fukuchan_balanced.blend');b=snapshot(P/'fukuchan_final.blend');assert a==b,'Geometry, material assignment or UV changed'
data=(P/'fukuchan_final.glb').read_bytes();magic,version,length=struct.unpack_from('<4sII',data);assert magic==b'glTF' and version==2 and length==len(data)
n=struct.unpack_from('<I',data,12)[0];g=json.loads(data[20:20+n]);assert len(g['meshes'])==1 and not g.get('skins') and not g.get('animations');assert all('bufferView' in im and 'uri' not in im for im in g['images'])
for mat in g['materials']:
 if mat['name'] in ['Front faithful skin','Natural sclera','Balanced forehead skin']:
  assert mat['pbrMetallicRoughness']['baseColorFactor']==[.36,.36,.36,1]
  assert all(abs(v-.44)<1e-6 for v in mat['emissiveFactor'])
report={'geometry_topology_material_assignment_uv_exact_match':True,'vertices':len(a['vertices']),'polygons':len(a['polygons']),'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest(),'meshes':len(g['meshes']),'primitives':len(g['meshes'][0]['primitives']),'embedded_images':len(g['images']),'rigged':False}
(P/'validation.json').write_text(json.dumps(report,indent=2)+'\n');print(report)
