"""Estimate diffuse illumination on the fitted 3D surface; remove its duplication."""
import bpy,numpy as np
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(OUT/'fukuchan_front_faithful.glb'))
sc=bpy.context.scene;sc.render.engine='CYCLES';sc.cycles.samples=48;sc.cycles.use_denoising=True
sc.render.resolution_x=sc.render.resolution_y=900;sc.render.resolution_percentage=100;sc.view_settings.view_transform='Standard'
w=bpy.data.worlds.new('Studio');w.use_nodes=True;w.node_tree.nodes['Background'].inputs[0].default_value=(.42,.45,.48,1);w.node_tree.nodes['Background'].inputs[1].default_value=.49;sc.world=w
cam=bpy.data.objects.new('Calibrated',bpy.data.cameras.new('Calibrated'));sc.collection.objects.link(cam);cam.data.type='ORTHO';cam.data.ortho_scale=180/590;sc.camera=cam
point=Vector(((414-411)/590,0,1.7-(110-24.5)/590));cam.location=point+Vector((0,-5,0));cam.rotation_euler=(point-cam.location).to_track_quat('-Z','Y').to_euler()
for name,pos,power,size in [('Key',(-1,-5,2.5),280,5),('Fill',(3,-4,2),140,5),('Rim',(1,3,4),105,4)]:
    l=bpy.data.lights.new(name,'AREA');l.energy=power;l.shape='DISK';l.size=size;o=bpy.data.objects.new(name,l);sc.collection.objects.link(o);o.location=pos;o.rotation_euler=(Vector((0,0,1))-o.location).to_track_quat('-Z','Y').to_euler()
for mat in bpy.data.materials:
    if not any(k in mat.name for k in ['faithful skin','Direct front','Natural sclera']):continue
    b=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    for link in list(b.inputs['Base Color'].links):mat.node_tree.links.remove(link)
    b.inputs['Base Color'].default_value=(.5,.5,.5,1);b.inputs['Specular IOR Level'].default_value=0
sc.render.image_settings.file_format='OPEN_EXR';sc.render.image_settings.color_depth='32';sc.render.filepath=str(OUT/'diffuse_calibration.exr');bpy.ops.render.render(write_still=True)
cal=bpy.data.images.load(str(OUT/'diffuse_calibration.exr'));c=np.array(cal.pixels[:],np.float32).reshape(900,900,4)
# Use only broad diffuse illumination; do not invert sharp occlusion shadows.
g=c[:,:,:3].mean(2)
for _ in range(3):
    for axis in [0,1]:
        pads=[(0,0),(0,0)];pads[axis]=(16,16)
        a=np.pad(g,pads,mode='edge');a=np.cumsum(a,axis=axis);a=np.concatenate([np.zeros_like(np.take(a,[0],axis=axis)),a],axis=axis)
        g=(np.take(a,range(33,a.shape[axis]),axis=axis)-np.take(a,range(a.shape[axis]-33),axis=axis))/33
def lin(v):return np.where(v<=.04045,v/12.92,((v+.055)/1.055)**2.4)
def srgb(v):return np.where(v<=.0031308,v*12.92,1.055*np.maximum(v,0)**(1/2.4)-.055)
ref=bpy.data.images.load(str(OUT.parent/'wan_multiview_20260917/inputs/front.png'));W,H=ref.size;orig=np.array(ref.pixels[:],np.float32).reshape(H,W,4);out=orig.copy()
for yt in range(65,190):
    for x in range(357,477):
        # EXR and source image pixels use a bottom-left origin.
        rx=int((x+.5-324)*5);ry=899-int((yt+.5-20)*5)
        if not 0<=rx<900 or not 0<=ry<900:continue
        factor=np.clip(g[ry,rx]/.5,.85,1.6)
        alpha=min(1,(x-357)/8,(477-x)/8,(yt-65)/8,(190-yt)/8)
        out[H-1-yt,x,:3]=orig[H-1-yt,x,:3]*(1-alpha)+np.clip(srgb(lin(orig[H-1-yt,x,:3])/factor),0,1)*alpha
im=bpy.data.images.new('Reference illumination corrected',width=W,height=H,alpha=True);im.pixels.foreach_set(out.ravel());im.filepath_raw=str(OUT/'front_illumination_corrected.png');im.file_format='PNG';im.save()
print('DELIGHT_DONE',flush=True)
