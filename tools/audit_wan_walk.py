"""Dense round-trip check and side-view contact sheet of the new walk."""
from pathlib import Path
import sys,json,math
sys.path.insert(0,str(Path(__file__).resolve().parent))
from build_humanoid_motion import *
from humanoid_action_refinement import forward
folder=ROOT/'22_HUMANOID_MOTION_LAB/evidence/wan-walk';folder.mkdir(parents=True,exist_ok=True)
report={'characters':[]}
for name in ['sobaya','fukuchan']:
 bpy.ops.wm.read_factory_settings(use_empty=True);sc=bpy.context.scene;sc.render.fps=30
 bpy.ops.import_scene.gltf(filepath=str(OUT/name/f'{name}.glb'))
 rig=next(o for o in sc.objects if o.type=='ARMATURE');meshes=[o for o in sc.objects if o.type=='MESH']
 for t in list(rig.animation_data.nla_tracks):rig.animation_data.nla_tracks.remove(t)
 use_action(rig,None);clear_pose(rig);body=Body(rig,meshes,name)
 use_action(rig,bpy.data.actions['Wan_Walk']);floors=[];pitches=[];positions={s:[] for s in ['l','r']}
 profile=json.loads((OUT/name/'profile.json').read_text());speed=next(c for c in profile['clips'] if c['name']=='Wan_Walk')['groundSpeedMps']
 for i in range(161):
  f=i/4;sc.frame_set(int(f),subframe=f-int(f));floors.append(min(body.skin_floor('l'),body.skin_floor('r')));pitches.append(math.degrees(math.asin(forward(body).z)))
  for s in positions:positions[s].append(body.bone('foot_'+s).head.copy())
 errors=[]
 for s,offset in [('l',0),('r',.5)]:
  for i in range(1,160):
   a=((i-1)/160+offset)%1;b=(i/160+offset)%1
   if .12<a<b<.48:
    v=(positions[s][i]-positions[s][i-1])*120-Vector((0,speed,0));errors.append(math.hypot(v.x,v.y))
 item=dict(character=name,samples=161,minSoleM=min(floors),maxLowestSoleM=max(floors),gazePitchRangeDeg=[min(pitches),max(pitches)],midStanceAnkleSlipRmsMps=math.sqrt(sum(x*x for x in errors)/len(errors)),groundSpeedMps=speed)
 assert min(floors)>-.002 and max(floors)<.02 and item['midStanceAnkleSlipRmsMps']<.015,item
 report['characters'].append(item)
 sc.render.engine='CYCLES';sc.cycles.samples=8;sc.cycles.use_denoising=True;sc.render.resolution_x=360;sc.render.resolution_y=440;sc.render.resolution_percentage=100
 world=bpy.data.worlds.new('World');sc.world=world;world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.2,.23,.27,1);world.node_tree.nodes['Background'].inputs[1].default_value=.7
 def aim(o,p):o.rotation_euler=(Vector(p)-o.location).to_track_quat('-Z','Y').to_euler()
 d=bpy.data.lights.new('Softbox','AREA');d.energy=800;d.size=4;o=bpy.data.objects.new('Softbox',d);sc.collection.objects.link(o);o.location=(-3,-4,5);aim(o,(0,0,1))
 bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.006));m=bpy.data.materials.new('Floor');m.diffuse_color=(.1,.13,.15,1);bpy.context.object.data.materials.append(m)
 camera=bpy.data.objects.new('Camera',bpy.data.cameras.new('Camera'));sc.collection.objects.link(camera);sc.camera=camera;camera.data.type='ORTHO';camera.data.ortho_scale=2.1;camera.location=(-5,-.3,1.5);aim(camera,(0,0,.86))
 for i in range(8):
  sc.frame_set(i*5);sc.render.filepath=str(folder/f'{name}_{i}.png');bpy.ops.render.render(write_still=True)
(ROOT/'22_HUMANOID_MOTION_LAB/qa/wan-walk-20260907.json').write_text(json.dumps(report,indent=2)+'\n')
print('WAN_DENSE_QA',json.dumps(report))
