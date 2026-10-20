"""Rebuild matched chikuwa GLBs with real toasted wrinkles and eight deform bones.
Run: Blender --background --factory-startup --python tools/build_chikuwa.py
"""
from pathlib import Path
import bpy, math, json
import numpy as np
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'04_GAME_ASSETS/3d/props/chikuwa'
OUT.mkdir(parents=True,exist_ok=True)
L=2.6; R=.34; N=48; M=80; B=8

def fields(u,v):
    a=u*2*np.pi
    edge=.265+.026*np.sin(3*a)+.016*np.sin(7*a+1)
    band=np.clip((.5-np.abs(v-.5)-(.5-edge))/.055,0,1)
    band=band*band*(3-2*band)
    wrinkle=np.sin(v*2*np.pi*14 + 1.7*np.sin(3*a+v*12)+.75*np.sin(7*a-v*24)+.5*np.sin(v*41+a))
    ridge=np.maximum(0,wrinkle)**3 * (.65+.25*np.sin(5*a-v*29)+.10*np.sin(9*a+v*53))
    grain=(np.sin(19*a+v*122)*np.sin(11*a-v*213)+np.sin(31*a+v*97)*.5)/1.5
    blotch=(np.sin(5*a+v*47)+np.sin(9*a-v*31)+np.sin(3*a+v*81))/3
    return band,ridge,grain,blotch

def radius(u,v,inner=False):
    band,ridge,grain,blotch=fields(u,v); a=u*2*math.pi
    irregular=.009*math.sin(a*3+v*9)+.006*math.sin(a*7-v*13)
    if inner: return .137+irregular*.35+.006*math.sin(v*23+a*4)
    endround=.025*math.exp(-min(v,1-v)*L/.035)
    return R+irregular-endround+float(band)*(.016+.038*float(ridge)+.012*float(blotch))+.0018*float(grain)

def image(name,rgb,data=False):
    h,w=rgb.shape[:2]; im=bpy.data.images.new(name,width=w,height=h,alpha=False)
    im.colorspace_settings.name='Non-Color' if data else 'sRGB'
    rgb=np.clip(rgb,0,1)
    if not data: rgb=np.where(rgb<=.04045,rgb/12.92,((rgb+.055)/1.055)**2.4)
    arr=np.ones((h,w,4),dtype=np.float32);arr[:,:,:3]=rgb
    im.pixels.foreach_set(arr.ravel());im.filepath_raw=str(OUT/(name+'.png'));im.file_format='PNG';im.save();return im

W=1024;H=1024
u,v=np.meshgrid((np.arange(W)+.5)/W,(np.arange(H)+.5)/H)
band,ridge,grain,blotch=fields(u,v)
rng=np.random.default_rng(88)
fine=rng.normal(0,.009,(H,W))
# Browning follows the raised toasted skin, with uneven char and pale blisters.
char=np.clip(.30+.27*blotch+.19*ridge+.06*grain,0,1)
pale=np.clip((blotch-.35)*2,0,.55)
rough=.58-.06*band+.04*grain+.025*blotch
roughim=image('roughness',np.repeat(rough[:,:,None],3,axis=2),data=True);roughim.colorspace_settings.name='Non-Color'
# Micro-relief tangent normal, shared by both finishes.
du=np.gradient(grain,axis=1)*1.5;dv=np.gradient(grain,axis=0)*1.5
normal=np.dstack((-du,-dv,np.ones_like(du)));normal/=np.linalg.norm(normal,axis=2)[:,:,None]
normalim=image('normal',normal*.5+.5,data=True);normalim.colorspace_settings.name='Non-Color'
textures={}
for toxic in [False,True]:
    base=np.array([.86,.76,.55] if not toxic else [.49,.14,.48])
    golden=np.array([.78,.43,.15] if not toxic else [.40,.055,.22])
    dark=np.array([.26,.08,.025] if not toxic else [.13,.012,.07])
    toast=golden[None,None,:]*(1-char[:,:,None])+dark[None,None,:]*char[:,:,None]
    toast=toast*(1-pale[:,:,None])+np.array([.77,.51,.22])[None,None,:]*pale[:,:,None]
    rgb=base[None,None,:]*(1-band[:,:,None])+toast*band[:,:,None]
    rgb+=grain[:,:,None]*.023+fine[:,:,None]
    textures[toxic]=image('toxic_basecolor' if toxic else 'normal_basecolor',rgb)

bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
verts=[];uvs=[];faces=[]
# Duplicated seam vertices provide clean UVs; same coordinates at u=0/1.
for inner in [False,True]:
    for j in range(M+1):
        v=j/M
        for i in range(N+1):
            u=i/N;a=u*math.tau;r=radius(u,v,inner)
            verts.append((r*math.cos(a),r*math.sin(a),(v-.5)*L));uvs.append((u,v))
S=(M+1)*(N+1)
for inner in [False,True]:
    off=S if inner else 0
    for j in range(M):
        for i in range(N):
            a=off+j*(N+1)+i;b=a+1;c=b+N+1;d=a+N+1
            faces.append((d,c,b,a) if inner else (a,b,c,d))
for j in [0,M]:
    for i in range(N):
        a=j*(N+1)+i;b=a+1
        faces.append((b,a,a+S,b+S) if j==0 else (a,b,b+S,a+S))
mesh=bpy.data.meshes.new('Chikuwa_shared_surface');mesh.from_pydata(verts,[],faces);mesh.update()
obj=bpy.data.objects.new('Chikuwa',mesh);bpy.context.collection.objects.link(obj)
uv=mesh.uv_layers.new(name='UVMap')
for p in mesh.polygons:
    p.use_smooth=True
    for li in p.loop_indices:uv.data[li].uv=uvs[mesh.loops[li].vertex_index]
arm=bpy.data.armatures.new('ChikuwaRig');rig=bpy.data.objects.new('ChikuwaRig',arm);bpy.context.collection.objects.link(rig)
bpy.context.view_layer.objects.active=rig;rig.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
r=arm.edit_bones.new('Root');r.head=(0,0,-L/2);r.tail=(0,0,-L/2-.2)
parent=r
for k in range(B):
    b=arm.edit_bones.new(f'Bend_{k+1:02d}');b.head=(0,0,-L/2+k*L/B);b.tail=(0,0,-L/2+(k+1)*L/B);b.parent=parent;parent=b
bpy.ops.object.mode_set(mode='OBJECT')
for k in range(B):obj.vertex_groups.new(name=f'Bend_{k+1:02d}')
for idx,co in enumerate(verts):
    t=(co[2]+L/2)/(L/B)-.5
    ks=sorted(range(B),key=lambda k:abs(k-t))[:4]
    weights=[math.exp(-((t-k)/.72)**2) for k in ks];total=sum(weights)
    for k,w in zip(ks,weights):obj.vertex_groups[k].add([idx],w/total,'REPLACE')
mod=obj.modifiers.new('Skin','ARMATURE');mod.object=rig;obj.parent=rig
scene=bpy.context.scene;scene.render.fps=30;scene.frame_start=0;scene.frame_end=48
for frame in range(49):
    phase=frame/48*math.tau
    for k in range(B):
        p=rig.pose.bones[f'Bend_{k+1:02d}'];p.rotation_mode='XYZ'
        p.rotation_euler=(.12*math.sin(phase-k*.78),0,.055*math.sin(phase-k*.78+.9))
        p.keyframe_insert('rotation_euler',frame=frame,group=p.name)
rig.animation_data.action.name='Wiggle'
scene.frame_set(0)
for toxic in [False,True]:
    mat=bpy.data.materials.new('Toxic baked skin' if toxic else 'Roasted chikuwa');mat.use_nodes=True
    nt=mat.node_tree;p=next(n for n in nt.nodes if n.type=='BSDF_PRINCIPLED')
    tex=nt.nodes.new('ShaderNodeTexImage');tex.image=textures[toxic];nt.links.new(tex.outputs['Color'],p.inputs['Base Color'])
    roughnode=nt.nodes.new('ShaderNodeTexImage');roughnode.image=roughim;nt.links.new(roughnode.outputs['Color'],p.inputs['Roughness'])
    normtex=nt.nodes.new('ShaderNodeTexImage');normtex.image=normalim
    norm=nt.nodes.new('ShaderNodeNormalMap');norm.inputs['Strength'].default_value=.18
    nt.links.new(normtex.outputs['Color'],norm.inputs['Color']);nt.links.new(norm.outputs['Normal'],p.inputs['Normal'])
    mesh.materials.clear();mesh.materials.append(mat)
    bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);rig.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(OUT/('chikuwa_toxic.glb' if toxic else 'chikuwa.glb')),export_format='GLB',use_selection=True,export_animations=True,export_skins=True,export_force_sampling=True,export_frame_range=True)
(OUT/'build_info.json').write_text(json.dumps({'vertices':len(verts),'triangles':len(faces)*2,'deformBones':B,'totalBones':B+1,'animation':'Wiggle','durationSeconds':1.6,'textureSize':1024,'length':L,'seed':88},indent=2)+'\n')
print('CHIKUWA BUILD COMPLETE',OUT)
