"""Normal chikuwa quality study: image-aligned displacement and detail normals.
Input images are retained, unmodified. Blender bakes seam-safe surface materials.
Run with Blender --background --factory-startup --python tools/build_chikuwa_v3.py
"""
from pathlib import Path
import bpy, math, json
from mathutils import Vector, noise
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'04_GAME_ASSETS/3d/props/chikuwa/v3'
OUT.mkdir(parents=True,exist_ok=True)
L=2.8;R=.30;B=8;N=160;M=320;MI=48
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)

# The generated height is interpreted as DATA, never as sRGB luminance.
height_image=bpy.data.images.load(str(OUT/'inputs/skin_height.png'))
height_image.colorspace_settings.name='Non-Color'
hw,hh=height_image.size
pixels=np.array(height_image.pixels[:],dtype=np.float32).reshape(hh,hw,4)
height=pixels[:,:,:3].mean(axis=2)
# Gaussian filtering splits real silhouette displacement from fine bump detail.
fy=np.fft.fftfreq(hh)[:,None];fx=np.fft.fftfreq(hw)[None,:]
low=np.fft.ifft2(np.fft.fft2(height)*np.exp(-2*np.pi**2*10.0**2*(fx*fx+fy*fy))).real
mid=np.fft.ifft2(np.fft.fft2(height)*np.exp(-2*np.pi**2*2.0**2*(fx*fx+fy*fy))).real
micro=mid-low
micro_image=bpy.data.images.new('skin_micro_height',width=hw,height=hh,alpha=False)
micro_image.colorspace_settings.name='Non-Color'
rgba=np.ones((hh,hw,4),dtype=np.float32);rgba[:,:,:3]=np.clip(.5+micro[:,:,None],0,1)
micro_image.pixels.foreach_set(rgba.ravel())

def sample_height(u,v):
    def sample(x):
        xx=(x%1)*(hw-1);yy=np.clip(v,0,1)*(hh-1)
        x0=int(xx);y0=int(yy);x1=min(hw-1,x0+1);y1=min(hh-1,y0+1)
        tx=xx-x0;ty=yy-y0
        return (1-ty)*((1-tx)*low[y0,x0]+tx*low[y0,x1])+ty*((1-tx)*low[y1,x0]+tx*low[y1,x1])
    value=sample(u);edge=min(u%1,1-u%1)
    if edge<.035:
        t=.5*(1-edge/.035)
        value=(1-t)*value+t*sample(1-(u%1))
    return float(value)

def grain(a,z,scale):
    return noise.noise_vector(Vector((math.cos(a)*R*scale+4.7,math.sin(a)*R*scale-2.1,z*scale+8.9)))[0]
def radial(a,z,inside=False):
    v=z/L+.5
    body=.006*grain(a,z,5)+.002*grain(a,z,22)
    if inside:return .121+.010*math.sin(a*3+.4)+.004*math.sin(a*5-.7)+body*.6
    # Pale paste stays gently irregular; toasted skin uses registered blisters.
    u=((a-.5*math.pi)/math.tau)%1
    h=sample_height(u,v)
    end_soft=min(1,max(0,min(v,1-v)/.025))
    displacement=(h-.55)*.10*end_soft
    broad=.007*grain(a,z,7)+.0025*grain(a,z,23)
    return R+.010*(1-(2*v-1)**2)+.004*math.sin(a*3+.9)+broad+displacement

def center(z):
    return (.006*math.sin(z*2.3),.005*math.cos(z*3.1))
verts=[];uvs=[];rings=[]
# The UV seam is below the chikuwa in its intended horizontal presentation.
for j in range(M+1):rings.append(('outer',-L/2+.025+j*(L-.05)/M,0))
for j in range(1,9):rings.append(('top',L/2-.025,j/9))
for j in range(MI+1):rings.append(('inner',L/2-.025-j*(L-.05)/MI,0))
for j in range(1,9):rings.append(('bottom',-L/2+.025,j/9))
for kind,z,t in rings:
    for i in range(N+1):
        u=i/N;a=u*math.tau+.5*math.pi
        ro=radial(a,z);ri=radial(a,z,True)
        zz=z
        if kind=='outer':r=ro;v=z/L+.5
        elif kind=='inner':r=ri;v=.035+.015*(z/L+.5) # untoasted inner wall
        else:
            ro-=.002;mid=(ro+ri)/2;half=(ro-ri)/2
            r=mid+half*math.cos(math.pi*t) if kind=='top' else mid-half*math.cos(math.pi*t)
            zz=z+(.025*math.sin(math.pi*t))*(1 if kind=='top' else -1)+.0025*grain(a,z+t*.2,18)*math.sin(math.pi*t)
            v=.97 if kind=='top' else .03
        cx,cy=center(z)
        verts.append((cx+r*math.cos(a),cy+r*math.sin(a),zz));uvs.append((u,v))
faces=[]
for j in range(len(rings)):
    j2=(j+1)%len(rings)
    for i in range(N):
        a=j*(N+1)+i;b=a+1;c=j2*(N+1)+i+1;d=c-1;faces.append((a,b,c,d))
mesh=bpy.data.meshes.new('ContinuousFishPaste');mesh.from_pydata(verts,[],faces);mesh.update()
obj=bpy.data.objects.new('Chikuwa',mesh);bpy.context.collection.objects.link(obj)
uv=mesh.uv_layers.new(name='UVMap')
for p in mesh.polygons:
    p.use_smooth=True
    for li in p.loop_indices:uv.data[li].uv=uvs[mesh.loops[li].vertex_index]

# Shader baking for a narrow seam crossfade. It leaves source images untouched.
# All shape detail is shared by both color variants.
scene=bpy.context.scene
try:scene.render.engine='CYCLES'
except TypeError as e:raise RuntimeError('Cycles is required for material baking') from e
scene.cycles.samples=1
bpy.context.view_layer.objects.active=obj;obj.select_set(True)

def bake_color(path,name):
    mat=bpy.data.materials.new(name);mat.use_nodes=True;nt=mat.node_tree
    p=next(n for n in nt.nodes if n.type=='BSDF_PRINCIPLED')
    tex=nt.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(path));tex.interpolation='Linear'
    # Imagegen textures are almost seamless; blend each edge with its opposite.
    uvnode=nt.nodes.new('ShaderNodeTexCoord');sep=nt.nodes.new('ShaderNodeSeparateXYZ');nt.links.new(uvnode.outputs['UV'],sep.inputs[0])
    inv=nt.nodes.new('ShaderNodeMath');inv.operation='SUBTRACT';inv.inputs[0].default_value=1;nt.links.new(sep.outputs['X'],inv.inputs[1])
    mirrored=nt.nodes.new('ShaderNodeCombineXYZ');nt.links.new(inv.outputs[0],mirrored.inputs['X']);nt.links.new(sep.outputs['Y'],mirrored.inputs['Y'])
    tex2=nt.nodes.new('ShaderNodeTexImage');tex2.image=tex.image;nt.links.new(mirrored.outputs[0],tex2.inputs['Vector'])
    minimum=nt.nodes.new('ShaderNodeMath');minimum.operation='MINIMUM';nt.links.new(sep.outputs['X'],minimum.inputs[0]);nt.links.new(inv.outputs[0],minimum.inputs[1])
    ramp=nt.nodes.new('ShaderNodeMapRange');ramp.inputs['From Min'].default_value=0;ramp.inputs['From Max'].default_value=.035;ramp.inputs['To Min'].default_value=.5;ramp.inputs['To Max'].default_value=0;nt.links.new(minimum.outputs[0],ramp.inputs['Value'])
    mix=nt.nodes.new('ShaderNodeMixRGB');nt.links.new(ramp.outputs[0],mix.inputs[0]);nt.links.new(tex.outputs['Color'],mix.inputs[1]);nt.links.new(tex2.outputs['Color'],mix.inputs[2])
    # Bake on a UV unit quad, not overlapping rim/inside mesh UVs.
    bpy.ops.mesh.primitive_plane_add(size=2)
    plane=bpy.context.object;plane.data.materials.append(mat)
    baked=bpy.data.images.new(name+'_baked',width=1024,height=1536,alpha=False)
    target=nt.nodes.new('ShaderNodeTexImage');target.image=baked;nt.nodes.active=target
    output=next(n for n in nt.nodes if n.type=='OUTPUT_MATERIAL')
    emission=nt.nodes.new('ShaderNodeEmission');nt.links.new(mix.outputs[0],emission.inputs['Color']);nt.links.new(emission.outputs[0],output.inputs['Surface'])
    bpy.ops.object.select_all(action='DESELECT');plane.select_set(True);bpy.context.view_layer.objects.active=plane
    bpy.ops.object.bake(type='EMIT',margin=0,use_clear=True)
    bpy.data.objects.remove(plane,do_unlink=True)
    baked.filepath_raw=str(OUT/(name+'_baked.png'));baked.file_format='PNG';baked.save()
    # Export a standard material with baked color, no special runtime shader.
    for n in list(nt.nodes):
        if n not in [p,output,target]:nt.nodes.remove(n)
    nt.links.new(p.outputs['BSDF'],output.inputs['Surface']);nt.links.new(target.outputs['Color'],p.inputs['Base Color'])
    p.inputs['Roughness'].default_value=.40
    return mat
materials=[bake_color(OUT.parent/'v2/inputs/normal_basecolor.png','normal')]
# Food paste is softly matte; thin roasted skin is smoother and a little moist.
base=bpy.data.images.get('normal_baked')
base_rgb=np.array(base.pixels[:],dtype=np.float32).reshape(1536,1024,4)[:,:,:3]
luminance=(base_rgb*np.array([.2126,.7152,.0722])).sum(axis=2)
roughness=.27+.19*np.clip((luminance-.24)/.54,0,1)
rough=bpy.data.images.new('skin_roughness',width=1024,height=1536,alpha=False)
rough.colorspace_settings.name='Non-Color'
rough_rgba=np.ones((1536,1024,4),dtype=np.float32);rough_rgba[:,:,:3]=roughness[:,:,None]
rough.pixels.foreach_set(rough_rgba.ravel())
rough.filepath_raw=str(OUT/'skin_roughness.png');rough.file_format='PNG';rough.save()
for mat in materials:
    nt=mat.node_tree;p=next(n for n in nt.nodes if n.type=='BSDF_PRINCIPLED')
    roughtex=nt.nodes.new('ShaderNodeTexImage');roughtex.image=rough;nt.links.new(roughtex.outputs['Color'],p.inputs['Roughness'])

# Soft, nonperiodic surface micro-normal baked from 3D noise; no checker grain.
mat=materials[0];nt=mat.node_tree;p=next(n for n in nt.nodes if n.type=='BSDF_PRINCIPLED')
tex_height=nt.nodes.new('ShaderNodeTexImage');tex_height.image=micro_image
bump=nt.nodes.new('ShaderNodeBump');bump.inputs['Strength'].default_value=1.0;bump.inputs['Distance'].default_value=.014
nt.links.new(tex_height.outputs['Color'],bump.inputs['Height']);nt.links.new(bump.outputs['Normal'],p.inputs['Normal'])
# Shader normal baking on the actual mesh UV. Interior shares a pale color strip;
# omit it from the bake to avoid multiple surfaces writing the same UV region.
normal=bpy.data.images.new('shared_normal',width=1024,height=1536,alpha=False);normal.colorspace_settings.name='Non-Color'
target=nt.nodes.new('ShaderNodeTexImage');target.image=normal;nt.nodes.active=target
mesh.materials.clear();mesh.materials.append(mat)
bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
# Use a separate bake mesh with only the outer quads for a single-valued UV domain.
bake_mesh=mesh.copy();bake_obj=bpy.data.objects.new('OuterBake',bake_mesh);bpy.context.collection.objects.link(bake_obj)
import bmesh
bm=bmesh.new();bm.from_mesh(bake_mesh);bm.faces.ensure_lookup_table();bmesh.ops.delete(bm,geom=list(bm.faces)[M*N:],context='FACES');bm.to_mesh(bake_mesh);bm.free()
obj.select_set(False);bake_obj.select_set(True);bpy.context.view_layer.objects.active=bake_obj
bpy.ops.object.bake(type='NORMAL',margin=16,use_clear=True)
bpy.data.objects.remove(bake_obj,do_unlink=True)
normal.filepath_raw=str(OUT/'shared_normal.png');normal.file_format='PNG';normal.save()
for mat in materials:
    nt=mat.node_tree;p=next(n for n in nt.nodes if n.type=='BSDF_PRINCIPLED')
    for link in list(p.inputs['Normal'].links):nt.links.remove(link)
    tex=nt.nodes.new('ShaderNodeTexImage');tex.image=normal
    nm=nt.nodes.new('ShaderNodeNormalMap');nm.inputs['Strength'].default_value=1;nt.links.new(tex.outputs['Color'],nm.inputs['Color']);nt.links.new(nm.outputs['Normal'],p.inputs['Normal'])

arm=bpy.data.armatures.new('ChikuwaRig');rig=bpy.data.objects.new('ChikuwaRig',arm);bpy.context.collection.objects.link(rig)
bpy.context.view_layer.objects.active=rig;rig.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
r=arm.edit_bones.new('Root');r.head=(0,0,-L/2);r.tail=(0,0,-L/2-.2);parent=r
for k in range(B):
    b=arm.edit_bones.new(f'Bend_{k+1:02d}');b.head=(0,0,-L/2+k*L/B);b.tail=(0,0,-L/2+(k+1)*L/B);b.parent=parent;parent=b
bpy.ops.object.mode_set(mode='OBJECT')
for k in range(B):obj.vertex_groups.new(name=f'Bend_{k+1:02d}')
for idx,co in enumerate(verts):
    t=(co[2]+L/2)/(L/B)-.5;ks=sorted(range(B),key=lambda k:abs(k-t))[:4]
    weights=[math.exp(-((t-k)/.72)**2) for k in ks];total=sum(weights)
    for k,w in zip(ks,weights):obj.vertex_groups[k].add([idx],w/total,'REPLACE')
mod=obj.modifiers.new('Skin','ARMATURE');mod.object=rig;obj.parent=rig
scene.render.fps=30;scene.frame_start=0;scene.frame_end=48
for frame in range(49):
    phase=frame/48*math.tau
    for k in range(B):
        p=rig.pose.bones[f'Bend_{k+1:02d}'];p.rotation_mode='XYZ'
        p.rotation_euler=(.12*math.sin(phase-k*.78),0,.055*math.sin(phase-k*.78+.9));p.keyframe_insert('rotation_euler',frame=frame,group=p.name)
rig.animation_data.action.name='Wiggle';scene.frame_set(0)
cut=bpy.data.materials.new('Cut fish paste');cut.use_nodes=True
cut_p=next(n for n in cut.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
cut_p.inputs['Base Color'].default_value=(.78,.70,.57,1)
cut_p.inputs['Roughness'].default_value=.48
cut_tex=cut.node_tree.nodes.new('ShaderNodeTexImage');cut_tex.image=base
cut.node_tree.links.new(cut_tex.outputs['Color'],cut_p.inputs['Base Color'])
# Cut-face UVs sample only the pale fish paste, never the toasted middle.
for poly in mesh.polygons:
    if poly.index>=M*N:
        for li in poly.loop_indices:
            x,y,z=mesh.vertices[mesh.loops[li].vertex_index].co
            u0=uv.data[li].uv.x
            rr=math.hypot(x,y)
            uv.data[li].uv=(u0,.025+.045*max(0,min(1,(rr-.11)/.22)))
inner=bpy.data.materials.new('Interior fish paste');inner.use_nodes=True
inner_p=next(n for n in inner.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
inner_p.inputs['Base Color'].default_value=(.78,.70,.57,1);inner_p.inputs['Roughness'].default_value=.48
for mat,name in zip(materials,['chikuwa']):
    mesh.materials.clear();mesh.materials.append(mat);mesh.materials.append(cut);mesh.materials.append(inner)
    for poly in mesh.polygons:
        row=poly.index//N
        poly.material_index=0 if row<M else 2 if M+9<=row<M+9+MI else 1
    bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);rig.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_animations=True,export_skins=True,export_force_sampling=True,export_frame_range=True)
(OUT/'build_info.json').write_text(json.dumps({'version':3,'vertices':len(verts),'triangles':len(faces)*2,'deformBones':B,'totalBones':B+1,'animation':'Wiggle','durationSeconds':1.6,'textureSize':[1024,1536],'length':L,'source':'Imagegen target/basecolor/height + Blender displacement and skin','displacementStrength':.10,'normalStrength':1.0,'microDistance':.014,'heightSmoothingPixels':10},indent=2)+'\n')
print('V3 COMPLETE',OUT)
