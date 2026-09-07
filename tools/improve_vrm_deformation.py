"""Blender: rebuild revised VRMs from immutable shared game geometry."""
import bpy,sys,json,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
from humanoid_deformation import smooth_shoulders
from build_humanoid_motion import use_action,clear_pose
import export_humanoid_vrm as vrm_export
from export_humanoid_vrm import export
def shape_signature(rig,meshes):
 data={'bones':[(b.name,[list(row) for row in b.matrix_local]) for b in rig.data.bones],
       'meshes':[(m.name,[list(v.co) for v in m.data.vertices],[list(p.vertices) for p in m.data.polygons],
                  [(k.name,[list(v.co) for v in k.data]) for k in m.data.shape_keys.key_blocks] if m.data.shape_keys else []) for m in meshes]}
 return hashlib.sha256(json.dumps(data,sort_keys=True).encode()).hexdigest()

report=[]
canonical_out=vrm_export.OUT
vrm_export.OUT=ROOT/'.local/dance_deformation/baseline/characters'
for name in ['sobaya','fukuchan']:export(name)
vrm_export.OUT=canonical_out
for name in ['sobaya','fukuchan']:
 bpy.ops.wm.read_factory_settings(use_empty=True)
 bpy.ops.import_scene.gltf(filepath=str(ROOT/f'04_GAME_ASSETS/3d/motion_library/{name}/{name}.glb'))
 rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
 for o in bpy.context.scene.objects:
  if o.animation_data:o.animation_data_clear()
 clear_pose(rig)
 meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
 before=shape_signature(rig,meshes)
 changed=sum(smooth_shoulders(m,rig) for m in meshes)
 assert before==shape_signature(rig,meshes),'Geometry, morph or bind bone changed'
 for m in meshes:
  if not any(mod.type=='ARMATURE' for mod in m.modifiers):continue
  for v in m.data.vertices:
   assert len(v.groups)<=4 and abs(sum(g.weight for g in v.groups)-1)<1e-5,(m.name,v.index,[(m.vertex_groups[g.group].name,g.weight) for g in v.groups])
 output=ROOT/f'.local/vrm-validation/{name}_deformation.glb'
 bpy.ops.export_scene.gltf(filepath=str(output),export_format='GLB',export_animations=False,export_skins=True,export_def_bones=False,export_extras=True)
 export(name,output)
 report.append({'character':name,'changedWeightVertices':changed,'smoothingIterations':3,'jointPositionsChanged':False,'geometryChanged':False,'shapeAndBindSha256':before})
(ROOT/'04_GAME_ASSETS/vrm/characters/deformation.json').write_text(json.dumps(report,indent=2)+'\n')
