"""Render round-tripped GLB clips, including the independently loaded mug."""
import bpy
import json
import sys
from pathlib import Path
from mathutils import Vector

ROOT=Path(__file__).resolve().parent.parent
OUT=ROOT/'21_SOBAYA_HAZARD_LAB/evidence/rig-review'
OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'04_GAME_ASSETS/3d/characters/sobaya/rig_v1/sobaya_rig.glb'))
rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
body=next(o for o in bpy.context.scene.objects if o.type=='MESH')
character_objects=list(bpy.context.scene.objects)
actions={a.name:a for a in bpy.data.actions}
print('ACTIONS',[(a.name,list(a.frame_range)) for a in actions.values()],flush=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'04_GAME_ASSETS/3d/props/beer_mug/beer_mug.glb'))
mug=bpy.data.objects['BeerMug']; grip=bpy.data.objects['Grip']
bpy.context.view_layer.update()
attachment=grip.matrix_world.inverted()@mug.matrix_world

scene=bpy.context.scene; scene.render.engine='CYCLES'
scene.cycles.samples=12; scene.cycles.use_denoising=True
scene.render.resolution_x=576; scene.render.resolution_y=768
scene.render.resolution_percentage=100
scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.16,.19,.20,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.65
scene.view_settings.view_transform='AgX'
def aim(obj,target): obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()
for name,pos,power,size in [('Key',(-3,-4,5),500,4),('Fill',(3,-1,3),220,3),('Rim',(0,3,4),400,3)]:
    light=bpy.data.lights.new(name,'AREA'); light.energy=power; light.shape='DISK'; light.size=size
    obj=bpy.data.objects.new(name,light); scene.collection.objects.link(obj); obj.location=pos; aim(obj,(0,0,1))
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.012))
floor=bpy.context.object
mat=bpy.data.materials.new('Review floor'); mat.diffuse_color=(.10,.14,.14,1); floor.data.materials.append(mat)
camera=bpy.data.objects.new('Review camera',bpy.data.cameras.new('Review camera'))
scene.collection.objects.link(camera); scene.camera=camera
camera.data.type='ORTHO'; camera.data.ortho_scale=2.65
camera.location=(-3,-5,2.4); aim(camera,(0,-.03,1.05))
poses=[('Walk',.22),('Toast',.52),('MugAttack',.38),('MugAttack',.55),
       ('Run',.24),('ZombieWalk',.24),('DanceStep',.12),('DanceDisco',.26),('DanceVictory',.12)]
if '--' in sys.argv:
    selected=sys.argv[sys.argv.index('--')+1:]
    poses=[p for p in poses if p[0] in selected]
audit=[]
for name,phase in poses:
    action=next(a for a in actions.values() if a.name==name or a.name.startswith(name+'_'))
    rig.animation_data.action=action
    rig.animation_data.action_slot=next(iter(action.slots))
    start,end=action.frame_range
    frame=start+(end-start)*phase
    scene.frame_set(int(frame),subframe=frame-int(frame))
    bpy.context.view_layer.update()
    mug.hide_render=name not in ['Toast','MugAttack']
    mug.matrix_world=rig.matrix_world@rig.pose.bones['PropSocket.R'].matrix@attachment
    scene.render.filepath=str(OUT/f'{name}_{phase:.2f}.png')
    depsgraph=bpy.context.evaluated_depsgraph_get()
    evaluated=body.evaluated_get(depsgraph)
    coords=[evaluated.matrix_world@v.co for v in evaluated.data.vertices]
    audit.append({'clip':name,'phase':phase,'bounds':[[min(p[i] for p in coords),max(p[i] for p in coords)] for i in range(3)],
                  'socket':[list(row) for row in rig.pose.bones['PropSocket.R'].matrix]})
    bpy.ops.render.render(write_still=True)
for o in character_objects: o.hide_render=True
mug.hide_render=False; mug.matrix_world=attachment.copy(); mug.location=(0,0,0)
camera.data.ortho_scale=.38; camera.location=(.4,-.8,.4); aim(camera,(.025,0,.105))
scene.render.filepath=str(OUT/'beer_mug.png'); bpy.ops.render.render(write_still=True)
(OUT/'roundtrip.json').write_text(json.dumps(audit,indent=2)+'\n')
