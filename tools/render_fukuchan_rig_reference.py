"""Render an exact game-rig clay first frame; no inferred or image-generated bones.
Blender --background --python tools/render_fukuchan_rig_reference.py
"""
import sys,json,math,hashlib
from pathlib import Path
import bpy
from mathutils import Vector,Matrix
from bpy_extras.object_utils import world_to_camera_view
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
from build_humanoid_motion import Body,use_action,clear_pose
OUT=ROOT/'03_SCRIPTS/62_hazard_motion_reference_wan3'
SOURCE=ROOT/'04_GAME_ASSETS/3d/motion_library/fukuchan/fukuchan.glb'
bpy.ops.wm.read_factory_settings(use_empty=True);sc=bpy.context.scene
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
rig=next(o for o in sc.objects if o.type=='ARMATURE');meshes=[o for o in sc.objects if o.type=='MESH']
for t in list(rig.animation_data.nla_tracks):rig.animation_data.nla_tracks.remove(t)
use_action(rig,None);clear_pose(rig);body=Body(rig,meshes,'fukuchan')
# Relaxed standing pose, exact same anatomical joint lengths as the game.
hips=body.bone('pelvis');pos=body.point('pelvis');pos.z-=.022
hips.matrix=Matrix.Translation(pos)@body.rest[hips.name].to_3x3().to_4x4();bpy.context.view_layer.update()
for side,sign in [('l',1),('r',-1)]:
 foot=body.point('foot_'+side);body.leg_ik(side,foot,body.rest[body.inverse['foot_'+side]].to_3x3());body.ground_leg(side)
 shoulder=body.bone('upperarm_'+side).head.copy()
 wrist=shoulder+Vector((sign*.045,-.035,-body.arm*.965))
 body.ik(['upperarm_'+side,'lowerarm_'+side,'hand_'+side],wrist,Vector((sign*.15,-1,0)))

def mat(name,color,emission=False):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True;bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*color,1);bs.inputs['Roughness'].default_value=.88
 if emission:bs.inputs['Emission Color'].default_value=(*color,1);bs.inputs['Emission Strength'].default_value=.8
 return m
clay=mat('Opaque neutral gray clay',(.43,.45,.46))
for mesh in meshes:
 mesh.data.materials.clear();mesh.data.materials.append(clay)
 for poly in mesh.data.polygons:poly.material_index=0
sc.render.engine='CYCLES';sc.cycles.samples=24;sc.cycles.use_denoising=True
sc.render.resolution_x=1536;sc.render.resolution_y=864;sc.render.resolution_percentage=100
world=bpy.data.worlds.new('Studio');sc.world=world;world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.45,.48,.5,1);world.node_tree.nodes['Background'].inputs[1].default_value=.7
camera=bpy.data.objects.new('Camera',bpy.data.cameras.new('Camera'));sc.collection.objects.link(camera);sc.camera=camera;camera.data.type='ORTHO';camera.data.ortho_scale=5.8
view=Vector((-6,-2.2,1.0)).normalized();orientation=(-view).to_track_quat('-Z','Y');right=orientation@Vector((1,0,0));target=Vector((0,0,.93))+right*1.82
camera.location=target+view*8;camera.rotation_euler=orientation.to_euler()
for location,power in [((-3,-4,5),650),((4,-1,3),300)]:
 d=bpy.data.lights.new('Softbox','AREA');d.energy=power;d.size=5;o=bpy.data.objects.new('Softbox',d);sc.collection.objects.link(o);o.location=location;o.rotation_euler=(Vector((0,0,.9))-o.location).to_track_quat('-Z','Y').to_euler()
floor=mat('Studio floor',(.25,.28,.30));bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.005));bpy.context.object.data.materials.append(floor)
colors={'center':mat('Center yellow',(.95,.7,.03),True),'l':mat('LEFT cyan',(.02,.85,.95),True),'r':mat('RIGHT magenta',(.95,.03,.38),True)}
points={b.name:rig.matrix_world@b.head for b in rig.pose.bones}
# Parallel camera-space displacement keeps each exact projected joint in front of opaque clay.
offset=view*.8
edges=[]
for b in rig.pose.bones:
 if not b.parent or b.parent.name=='Root':continue
 a=points[b.parent.name]+offset;z=points[b.name]+offset;delta=z-a
 if delta.length<.0001:continue
 side='l' if b.name.startswith('Left') else 'r' if b.name.startswith('Right') else 'center';material=colors[side]
 bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=.009,depth=delta.length,location=(a+z)/2);o=bpy.context.object;o.rotation_euler=delta.to_track_quat('Z','Y').to_euler();o.data.materials.append(material)
 edges.append([b.parent.name,b.name])
for name,p in points.items():
 if name=='Root':continue
 side='l' if name.startswith('Left') else 'r' if name.startswith('Right') else 'center'
 bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=8,radius=.021,location=p+offset);bpy.context.object.data.materials.append(colors[side])
# Three physically stationary high-contrast framing markers.
black=mat('Fixed black markers',(.015,.015,.015))
for u in [.07,.50,.93]:
 p=target+right*((u-.5)*5.8)+(orientation@Vector((0,1,0)))*1.42-view*1
 bpy.ops.mesh.primitive_cube_add(size=.09,location=p);bpy.context.object.rotation_euler=orientation.to_euler();bpy.context.object.data.materials.append(black)
bpy.context.view_layer.update()
records=[]
for b in rig.pose.bones:
 ndc=world_to_camera_view(sc,camera,points[b.name]);records.append({'name':b.name,'parent':b.parent.name if b.parent else None,'restHeadM':list(body.rest[b.name].translation),'posedHeadWorldM':list(points[b.name]),'imageUV':[ndc.x,1-ndc.y]})
(OUT/'fukuchan_rig_input.json').write_text(json.dumps({'source':str(SOURCE.relative_to(ROOT)),'sourceSha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'bones':len(records),'legM':body.leg,'armM':body.arm,'shoulderM':body.width,'coordinateSystem':'Blender: Z up, forward -Y; meters','boneRepresentation':'actual parent-head to child-head segments; leaf bone display lengths are not anatomical segments','colors':{'left':'cyan','right':'magenta','center':'yellow'},'camera':'orthographic, 20 degrees toward front from pure side','joints':records,'edges':edges,'material':'original game mesh geometry, including clothing, with all surface textures replaced by opaque gray clay','overlay':'exact orthographic joint projections; deform joint markers visible through body. Root is a non-anatomical floor controller and is omitted from the visible overlay.'},ensure_ascii=False,indent=2)+'\n')
sc.render.filepath=str(OUT/'walk_clay_rig_start_v1.png');bpy.ops.render.render(write_still=True)
print('RIG_REFERENCE',len(records),sc.render.filepath)
