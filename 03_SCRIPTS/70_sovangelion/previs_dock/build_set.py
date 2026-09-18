"""Blender 5.x: reproducible scale/camera/beer-level previs, no character likeness."""
import bpy, math, sys
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
s=bpy.context.scene;s.unit_settings.system='METRIC'
def mat(name,color):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);return m
steel=mat('Neutral structural grey',(0.23,.28,.32)); dark=mat('Deep grey',(.10,.13,.16)); rail=mat('Human scale safety yellow',(.85,.58,.09)); beer=mat('Beer surface opaque amber',(.62,.29,.035));foam=mat('Sparse foam ivory',(.85,.77,.55));proxy=mat('Giant neutral proxy',(.52,.57,.60));human=mat('Human cylinders orange',(.95,.22,.055))
def box(name,loc,size,m):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.name=name;o.dimensions=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(m);return o
def cyl(name,loc,r,depth,m,verts=16):
 bpy.ops.mesh.primitive_cylinder_add(vertices=verts,radius=r,depth=depth,location=loc);o=bpy.context.object;o.name=name;o.data.materials.append(m);return o
# 60 m giant: shoulder top 49m, liquid 48.5m, head top 60m.
box('Tank floor',(0,4,20),(40,52,1),dark)
for x in [-21,21]:
 box('Shaft side wall',(x,4,48),(2,52,58),steel)
 for y in range(-20,30,6):box('Wall rib',(x*.94,y,49),(1,1,55),dark)
box('Rear wall',(0,31,48),(44,2,58),steel)
for z in [31,41,51,61,71]:
 for x in [-19.4,19.4]:box('Side service catwalk',(x,4,z),(2.5,52,.35),dark)
# Torso and shoulders remain below liquid except half-metre upper cap.
cyl('GIANT torso proxy height 43m',(0,9,24.5),7,43,proxy)
shoulder=box('GIANT shoulder envelope top 49m',(0,9,46),(18,9,6),proxy)
bevel=shoulder.modifiers.new('Rounded shoulder envelope','BEVEL');bevel.width=1.2;bevel.segments=2
cyl('GIANT neck proxy',(0,9,50),2.3,3,proxy)
cyl('GIANT head cylinder NO FACE',(0,9,55.5),4.8,9,proxy)
box('BEER LEVEL 48.5m shoulder immersion',(0,4,48.35),(39.8,51,.3),beer)
# Foam strips along walls and restrained shoulders; flat, not waves/waterfall.
for x in [-19,19]:box('Wall foam strip',(x,4,48.53),(.45,50,.035),foam)
for x in [-8.1,8.1]:box('Shoulder liquid contact foam',(x,9,48.53),(.4,9,.035),foam)
for x in [-11,11]:
 box('Shoulder clamp',(x,9,50),(4,8,3),steel)
 box('Clamp support',(x,15,50),(4,10,2),dark)
 box('Clamp hazard panel',(x,4.95,50),(3.8,.12,.5),rail)
# Foreground bridge normal-human dimensions, 1.1 m handrails and 1.7 m cylinders.
Z=49.2;Y=1.0  # Inner bridge edge y=2.5, shoulder front y=4.5: 2m clearance.
box('Bridge 3m width',(0,Y,Z-.25),(40,3,.5),steel)
for y in [Y-1.4,Y+1.4]:
 for x in range(-19,20,2):box('Railing post 1.1m',(x,y,Z+.55),(.07,.07,1.1),rail)
 box('Railing top',(0,y,Z+1.1),(40,.07,.07),rail)
 box('Railing middle',(0,y,Z+.55),(40,.05,.05),rail)
for name,x,y in [('Yametaro position',-2,Y),('Fukuchan position',1,Y+.3)]:
 cyl(name+' HUMAN 1.7m cylinder',(x,y,Z+.85),.28,1.7,human)
# One visibly separate peripheral prop cylinder, no staged character image.
cyl('Mug placeholder rack',(15,16,53),1.8,5,rail)
box('Mug rack',(15,16,50),(5,6,.5),steel)
# Eight-second continuous crane/orbit/dive. Target animation avoids Euler flips.
bpy.ops.object.camera_add();cam=bpy.context.object;cam.name='CAM_DOCK_REVEAL';s.camera=cam;cam.data.clip_end=500
bpy.ops.object.empty_add();aim=bpy.context.object;aim.name='Camera aim'
track=cam.constraints.new('TRACK_TO');track.target=aim;track.track_axis='TRACK_NEGATIVE_Z';track.up_axis='UP_Y'
# Side close-up, crane reveal, then pass ABOVE the bridge to its outer side.
# End facing back toward the giant, with bridge people in the foreground.
shots=[
 (1,(15,5,56.5),(0,9,55.5),32),
 (25,(15,3,57),(0,9,55.5),32),
 (66,(13,-6,69),(0,5,51),28),
 (96,(7,-3,77),(0,0,49),24),
 (112,(5,-3,76),(0,-1,49),24),
 (150,(2,-7,63),(0,3,52),28),
 (176,(-.5,-4.8,51.5),(-.5,9,51.9),30),
 (192,(-.5,-4,51.1),(-.5,9,51.5),30),
]
for fr,pos,target,lens in shots:
 cam.location=pos;cam.keyframe_insert(data_path='location',frame=fr)
 aim.location=target;aim.keyframe_insert(data_path='location',frame=fr)
 cam.data.lens=lens;cam.data.keyframe_insert(data_path='lens',frame=fr)
for block in [cam,aim,cam.data]:
 action=block.animation_data.action
 for layer in action.layers:
  for strip in layer.strips:
   for bag in strip.channelbags:
    for curve in bag.fcurves:
     for key in curve.keyframe_points:
      key.interpolation='BEZIER';key.handle_left_type='AUTO_CLAMPED';key.handle_right_type='AUTO_CLAMPED'
s.frame_start=1;s.frame_end=192;s.render.fps=24;s.render.resolution_x=1280;s.render.resolution_y=720;s.render.resolution_percentage=100
s.render.engine='BLENDER_WORKBENCH';s.display.shading.light='STUDIO';s.display.shading.studiolight_rotate_z=.4;s.display.shading.color_type='MATERIAL';s.display.shading.show_shadows=True;s.display.shading.show_cavity=True;s.display.shading.cavity_type='BOTH';s.display.shading.show_specular_highlight=True;s.display.shading.background_type='WORLD';s.world.color=(.06,.07,.09)
s.render.image_settings.file_format='PNG';s.view_settings.view_transform='Standard'
s.frame_set(1);bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'dock_scale_set.blend'))
if '--animation' in sys.argv:
 (OUT/'frames').mkdir(exist_ok=True);s.render.filepath=str(OUT/'frames/frame_');bpy.ops.render.render(animation=True)
else:
 for fr in [1,96,192]:s.frame_set(fr);s.render.filepath=str(OUT/f'preview_{fr:03d}.png');bpy.ops.render.render(write_still=True)
