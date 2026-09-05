"""Reusable 500 ml beer mug. Run with Blender --background --python this file."""
import bpy
import json
import math
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / '04_GAME_ASSETS/3d/props/beer_mug'


def material(name, color, roughness, alpha=1, metallic=0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, alpha)
    mat.use_nodes = True
    p = mat.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color, alpha)
    p.inputs['Roughness'].default_value = roughness
    p.inputs['Metallic'].default_value = metallic
    p.inputs['Alpha'].default_value = alpha
    mat.use_backface_culling = True
    if alpha < 1:
        mat.surface_render_method = 'BLENDED'
    return mat


def build():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    OUT.mkdir(parents=True, exist_ok=True)
    glass = material('Glass', (.58, .80, .85), .13, .10, .08)
    beer = material('Amber beer', (.83, .25, .008), .30, 1, 0)
    foam = material('Cream foam', (.96, .91, .74), .82)
    # Closed thickness, open mouth; shallow flutes catch highlights.
    profile = [(0, .007), (.066, .007), (.079, .017), (.078, .037),
               (.073, .185), (.079, .209), (.071, .211), (.067, .184),
               (.065, .028), (0, .028)]
    vertices, faces = [], []
    sides = 48
    for radius, z in profile:
        for i in range(sides):
            a = i * math.tau / sides
            r = radius + (.0016 * math.cos(a * 12) if .03 < z < .20 else 0)
            vertices.append((r * math.cos(a), r * math.sin(a), z))
    for row in range(len(profile)-1):
        for i in range(sides):
            j = (i+1) % sides
            faces.append((row*sides+i, row*sides+j, (row+1)*sides+j, (row+1)*sides+i))
    mesh = bpy.data.meshes.new('Thick fluted glass')
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new('Glass body', mesh)
    bpy.context.collection.objects.link(obj)
    mesh.materials.append(glass)
    for p in mesh.polygons: p.use_smooth = True
    # D handle, with the grip furthest from the body.
    points = [(.071,0,.177),(.112,0,.18),(.146,0,.166),(.155,0,.14),
              (.155,0,.095),(.144,0,.062),(.113,0,.051),(.070,0,.059)]
    curve = bpy.data.curves.new('Handle path', 'CURVE')
    curve.dimensions='3D'; curve.resolution_u=3
    curve.bevel_depth=.012; curve.bevel_resolution=2
    spline=curve.splines.new('BEZIER'); spline.bezier_points.add(len(points)-1)
    for p, co in zip(spline.bezier_points, points):
        p.co=co; p.handle_left_type='AUTO'; p.handle_right_type='AUTO'
    handle=bpy.data.objects.new('Glass handle',curve)
    bpy.context.collection.objects.link(handle); curve.materials.append(glass)
    bpy.context.view_layer.objects.active=handle
    handle.select_set(True); bpy.ops.object.convert(target='MESH'); handle.select_set(False)
    bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=.064, depth=.158, location=(0,0,.109))
    liquid=bpy.context.object; liquid.name='Beer'; liquid.data.materials.append(beer)
    bevel=liquid.modifiers.new('Liquid meniscus','BEVEL'); bevel.width=.003; bevel.segments=2
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    for p in liquid.data.polygons: p.use_smooth=True
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=8, radius=1, location=(0,0,.198))
    cap=bpy.context.object; cap.name='Foam head'; cap.scale=(.068,.068,.019); cap.data.materials.append(foam)
    for i in range(9):
        a=i*2.39996; r=.052*math.sqrt((i+.5)/9)
        bpy.ops.mesh.primitive_uv_sphere_add(segments=10,ring_count=6,radius=.012,location=(r*math.cos(a),r*math.sin(a),.211))
        bubble=bpy.context.object; bubble.name='Foam bubble'; bubble.scale.z=.55; bubble.data.materials.append(foam)
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
    # One mesh, three material primitives, no textures or physics dependencies.
    bpy.ops.object.select_all(action='DESELECT')
    for o in meshes: o.select_set(True)
    bpy.context.view_layer.objects.active=liquid
    bpy.ops.object.join()
    mug=bpy.context.object; mug.name='BeerMug'
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    for p in mug.data.polygons: p.use_smooth=True
    grip=bpy.data.objects.new('Grip',None)
    bpy.context.collection.objects.link(grip)
    grip.location=(.155,0,.117)
    grip['purpose']='Right-hand grip anchor; align its transform to a character socket.'
    mug['capacity_ml']=500
    mug['asset_version']='1.0'
    bpy.context.scene.unit_settings.system='METRIC'
    mug.data.calc_loop_triangles()
    report={'asset':'beer_mug.glb','version':1,'triangles':len(mug.data.loop_triangles),
            'materials':3,'units':'metres','grip_blender':list(grip.location),
            'grip_gltf':[.155,.117,0],'origin':'base centre','textures':0,
            'glass':'alpha blend, no refraction pass required','liquid':'static beer and foam'}
    (OUT/'asset.json').write_text(json.dumps(report,indent=2)+'\n')
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'beer_mug.blend'))
    bpy.ops.export_scene.gltf(filepath=str(OUT/'beer_mug.glb'),export_format='GLB',use_selection=True,export_animations=False,export_extras=True)
    print('BEER_MUG',json.dumps(report))


if __name__=='__main__': build()
