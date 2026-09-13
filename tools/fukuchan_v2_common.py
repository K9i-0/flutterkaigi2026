"""Shared paths, import, neutral studio and geometry utilities for Fukuchan v2."""
from pathlib import Path
import math
import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / '04_GAME_ASSETS/3d/characters/fukuchan/v2_20260913'

def bounds(obj):
    pts = [obj.matrix_world @ v.co for v in obj.data.vertices]
    return [min(p[i] for p in pts) for i in range(3)], [max(p[i] for p in pts) for i in range(3)]

def import_part(part, height, bottom):
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.fbx(filepath=str(OUT / part / 'raw/output_model_url.fbx'))
    meshes = [o for o in set(bpy.context.scene.objects)-before if o.type == 'MESH']
    assert len(meshes) == 1, (part, len(meshes))
    obj = meshes[0]
    obj.name = part.title()
    obj.data.transform(Matrix.Rotation(-math.pi/2, 4, 'Z') @ obj.matrix_world)
    obj.parent = None
    obj.matrix_world = Matrix.Identity(4)
    lo, hi = bounds(obj)
    s = height/(hi[2]-lo[2])
    obj.data.transform(Matrix.Translation((0,0,bottom)) @ Matrix.Scale(s,4) @ Matrix.Translation((-(lo[0]+hi[0])/2,-(lo[1]+hi[1])/2,-lo[2])))
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return obj

def prepare_materials():
    records = []
    for mat in bpy.data.materials:
        if not mat.use_nodes:
            continue
        bs = next((n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'), None)
        if not bs:
            continue
        maps={}
        for n in mat.node_tree.nodes:
            if n.type!='TEX_IMAGE' or not n.image:
                continue
            role=Path(n.image.filepath).stem.lower()
            maps[role]=n
            if role in ('roughness','metallic','normal'):
                n.image.colorspace_settings.name='Non-Color'
            n.image.pack()
        for role,slot in [('color','Base Color'),('roughness','Roughness'),('metallic','Metallic')]:
            if role in maps:
                mat.node_tree.links.new(maps[role].outputs['Color'],bs.inputs[slot])
        if 'normal' in maps:
            normal = next((n for n in mat.node_tree.nodes if n.type == 'NORMAL_MAP'),None)
            if normal is None:
                normal=mat.node_tree.nodes.new('ShaderNodeNormalMap')
            mat.node_tree.links.new(maps['normal'].outputs['Color'],normal.inputs['Color'])
            mat.node_tree.links.new(normal.outputs['Normal'],bs.inputs['Normal'])
            normal.inputs['Strength'].default_value=.35 if 'cc915a71' in mat.name else .65
        records.append({'material':mat.name,'maps':list(maps)})
    return records

def studio():
    sc=bpy.context.scene
    sc.render.engine='CYCLES'
    sc.cycles.samples=24
    sc.cycles.use_denoising=True
    sc.render.resolution_percentage=100
    sc.view_settings.view_transform='AgX'
    world=bpy.data.worlds.new('FukuchanV2Studio')
    world.use_nodes=True
    world.node_tree.nodes['Background'].inputs[0].default_value=(.42,.45,.48,1)
    world.node_tree.nodes['Background'].inputs[1].default_value=.55
    sc.world=world
    cam=bpy.data.objects.new('ReviewCamera',bpy.data.cameras.new('ReviewCamera'))
    sc.collection.objects.link(cam)
    cam.data.type='ORTHO'
    sc.camera=cam
    cam.location=(0,-5,.9)
    cam.rotation_euler=(Vector((0,0,.9))-cam.location).to_track_quat('-Z','Y').to_euler()
    cam.data.ortho_scale=3.6
    sc.render.resolution_x=1920;sc.render.resolution_y=1080
    for name,pos,power,size in [('Key',(-3,-4,5),550,5),('Fill',(4,-1,3),350,4),('Rim',(1,3,4),500,3)]:
        lamp=bpy.data.lights.new(name,'AREA');lamp.energy=power;lamp.shape='DISK';lamp.size=size
        o=bpy.data.objects.new(name,lamp);sc.collection.objects.link(o);o.location=pos
        o.rotation_euler=(Vector((0,0,1))-o.location).to_track_quat('-Z','Y').to_euler()
    return cam

def render_view(filename, direction=(0,-1,0), target=(0,0,.86), scale=2., size=(960,960)):
    sc=bpy.context.scene;cam=sc.camera
    target=Vector(target);cam.location=target+Vector(direction).normalized()*5
    cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()
    cam.data.ortho_scale=scale
    sc.render.resolution_x,sc.render.resolution_y=size
    sc.render.image_settings.file_format='PNG'
    path=OUT/'qa'/filename;path.parent.mkdir(exist_ok=True)
    sc.render.filepath=str(path)
    bpy.ops.render.render(write_still=True)
    return str(path)
