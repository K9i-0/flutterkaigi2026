import bpy, json, numpy as np
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent
BASE=OUT.parent/'wan_multiview_20260917'
bpy.ops.wm.open_mainfile(filepath=str(BASE/'fukuchan_wholebody.blend'))
s=bpy.context.scene
o=next(o for o in s.objects if o.type=='MESH')
m=o.data
m.calc_loop_triangles()
P=np.array([tuple(o.matrix_world@v.co) for v in m.vertices])
np.savez(OUT/'source_mesh.npz',positions=P,triangles=np.array([list(t.vertices) for t in m.loop_triangles]),uv=np.array([[tuple(m.uv_layers.active.data[i].uv) for i in t.loops] for t in m.loop_triangles]))
mat=o.data.materials[0]
bs=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
tex=bs.inputs['Base Color'].links[0].from_node
tex.image.filepath_raw=str(OUT/'source_color.png');tex.image.file_format='PNG';tex.image.save()
for im in bpy.data.images:
    if im.size[0]>64:
        print('IMAGE',im.name,tuple(im.size),im.colorspace_settings.name)
out=next(n for n in mat.node_tree.nodes if n.type=='OUTPUT_MATERIAL')
em=mat.node_tree.nodes.new('ShaderNodeEmission')
mat.node_tree.links.new(tex.outputs['Color'],em.inputs['Color'])
mat.node_tree.links.new(em.outputs[0],out.inputs['Surface'])
s.view_settings.view_transform='Standard'
s.render.film_transparent=True
s.render.resolution_x=s.render.resolution_y=1024
s.cycles.samples=8
cam=s.camera
def render(name,direction,target,scale):
    target=Vector(target);cam.location=target+Vector(direction)*5
    cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()
    cam.data.ortho_scale=scale
    s.render.image_settings.color_mode='RGBA'
    s.render.filepath=str(OUT/(name+'.png'));bpy.ops.render.render(write_still=True)
render('face_albedo_front',(0,-1,0),(0,0,1.535),.43)
render('face_albedo_left',(1,0,0),(0,0,1.535),.43)
render('badge_albedo_front',(0,-1,0),(0,0,.99),.26)
(OUT/'projection.json').write_text(json.dumps({'face_front':{'target':[0,0,1.535],'scale':.43,'size':[1024,1024]},'mesh':o.name,'bounds':[P.min(0).tolist(),P.max(0).tolist()]},indent=2)+'\n')
print('PREPARE_DONE')
