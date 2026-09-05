"""Fixed-view shoulder, face, grip and prop audit. Local evidence only."""
import bpy, sys, math, json
from pathlib import Path
from mathutils import Vector,Matrix
ROOT=Path(__file__).resolve().parent.parent;sys.path.insert(0,str(ROOT/'tools'))
import build_sobaya_rig_v2 as v2
OUT=ROOT/'21_SOBAYA_HAZARD_LAB/evidence/quality-v2';OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(v2.OUT/'sobaya_rig.blend'))
rig=bpy.data.objects['SobayaRig'];body=bpy.data.objects['SobayaBody'];rig.animation_data.action=None
bpy.ops.import_scene.gltf(filepath=str(ROOT/'04_GAME_ASSETS/3d/props/beer_mug_v2/beer_mug.glb'))
mug=bpy.data.objects['BeerMugRoot'];grip=bpy.data.objects['Grip'];bpy.context.view_layer.update()
attachment=grip.matrix_world.inverted()@mug.matrix_world
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True
scene.cycles.max_bounces=12;scene.cycles.transmission_bounces=8
scene.render.resolution_x=640;scene.render.resolution_y=800;scene.render.resolution_percentage=100
scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.16,.19,.20,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.65
scene.view_settings.view_transform='AgX'
def aim(o,p):o.rotation_euler=(Vector(p)-o.location).to_track_quat('-Z','Y').to_euler()
for name,pos,power,size in [('Key',(-3,-4,5),500,4),('Fill',(3,-1,3),220,3),('Rim',(0,3,4),400,3)]:
 d=bpy.data.lights.new(name,'AREA');d.energy=power;d.shape='DISK';d.size=size
 o=bpy.data.objects.new(name,d);scene.collection.objects.link(o);o.location=pos;aim(o,(0,0,1))
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.012));floor=bpy.context.object
mat=bpy.data.materials.new('Review floor');mat.diffuse_color=(.10,.14,.14,1);floor.data.materials.append(mat)
c=bpy.data.objects.new('Camera',bpy.data.cameras.new('Camera'));scene.collection.objects.link(c);scene.camera=c;c.data.type='ORTHO'
def camera(pos,target,scale):c.location=pos;aim(c,target);c.data.ortho_scale=scale
def render(name):scene.render.filepath=str(OUT/(name+'.png'));bpy.ops.render.render(write_still=True)
def show_mug(show):
 for o in [mug,*mug.children_recursive]:o.hide_render=not show
selected=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else ['poses','face','grip','mug','raise']
if 'poses' in selected:
 for name,phase in [('Run',.24),('Toast',.52),('DanceDisco',.26),('DanceVictory',.12),('MugAttack',.38),('MugAttack',.55),('ZombieWalk',.24),('Walk',.22),('DanceStep',.12)]:
  v2.pose(rig,name,phase);show_mug(name in ['Toast','MugAttack'])
  mug.matrix_world=rig.matrix_world@rig.pose.bones['PropSocket.R'].matrix@attachment
  camera((-3,-5,2.4),(0,-.03,1.05),2.65);render(f'{name}_{phase:.2f}')
if 'raise' in selected:
 show_mug(False)
 for angle in [0,45,90,135,160]:
  v2.base.pose(rig,'Idle',0);v2.base.rotate(rig,'UpperArm.R',x=-angle);bpy.context.view_layer.update();v2.shoulder_follow(rig)
  for side,pos in [('front',(0,-5,1.4)),('back',(0,5,1.4)),('side',(-5,0,1.4))]:
   camera(pos,(-.1,0,1.4),1.5);render(f'raise_{angle}_{side}')
if 'face' in selected:
 v2.pose(rig,'Idle',0);show_mug(False)
 for name,pos in [('front',(0,-4,1.66)),('oblique',(-2,-4,1.66))]:
  camera(pos,(0,-.05,1.66),.36);render('face_'+name)
if 'grip' in selected:
 v2.pose(rig,'Toast',.52);show_mug(True);mug.matrix_world=rig.matrix_world@rig.pose.bones['PropSocket.R'].matrix@attachment
 target=rig.pose.bones['Hand.R'].head.copy();target.z+=.02
 for name,offset in [('front',(-.4,-1,.3)),('back',(-.5,1,.3)),('top',(0,-.1,1))]:
  camera(target+Vector(offset),target,.40);render('grip_'+name)
 # Bone/handle local coordinates for contact diagnostics.
 inv=mug.matrix_world.inverted()
 (OUT/'grip.json').write_text(json.dumps({b.name:{'head':list(inv@b.head),'tail':list(inv@b.tail)} for b in rig.pose.bones if b.name.endswith('.R')},indent=2))
if 'mug' in selected:
 body.hide_render=True;show_mug(True);mug.matrix_world=Matrix.Identity(4)
 camera((.4,-.8,.4),(.025,0,.105),.38);render('beer_mug')
