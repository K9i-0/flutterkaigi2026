"""Reusable thick-glass mug with transmissive beer and GPU liquid morphs.

Blender --background --factory-startup --python tools/build_beer_mug_v2.py
Dimensions are in metres; +X handle and Grip are shared with the v1 prop.
"""
import bpy, json, math, random
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
OUT=ROOT/'04_GAME_ASSETS/3d/props/beer_mug_v2'


def material(name,color,roughness,transmission=0,ior=1.5,thickness=0,distance=1):
    m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(*color,1)
    n=m.node_tree.nodes;p=n.get('Principled BSDF')
    p.inputs['Base Color'].default_value=(*((1,1,1) if transmission else color),1)
    p.inputs['Roughness'].default_value=roughness;p.inputs['Metallic'].default_value=0
    p.inputs['Transmission Weight'].default_value=transmission;p.inputs['IOR'].default_value=ior
    m.use_backface_culling=True
    if thickness:
        group=bpy.data.node_groups.get('glTF Material Output')
        if group is None:
            group=bpy.data.node_groups.new('glTF Material Output','ShaderNodeTree')
            group.interface.new_socket(name='Thickness',in_out='INPUT',socket_type='NodeSocketFloat')
        settings=n.new('ShaderNodeGroup');settings.node_tree=group;settings.inputs['Thickness'].default_value=thickness
        volume=n.new('ShaderNodeVolumeAbsorption');volume.inputs['Color'].default_value=(*color,1)
        volume.inputs['Density'].default_value=1/distance
        m.node_tree.links.new(volume.outputs[0],n.get('Material Output').inputs['Volume'])
    return m


def lathe(name,profile,mat,sides=64,flute=0):
    verts=[];faces=[]
    for r,z in profile:
        for i in range(sides):
            a=math.tau*i/sides
            rr=r+(flute*(.5+.5*math.cos(16*a)) if .04<z<.175 else 0)
            verts.append((rr*math.cos(a),rr*math.sin(a),z))
    for row in range(len(profile)-1):
        for i in range(sides):
            j=(i+1)%sides
            faces.append((row*sides+i,row*sides+j,(row+1)*sides+j,(row+1)*sides+i))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);mesh.materials.append(mat)
    for p in mesh.polygons:p.use_smooth=True
    return o


def liquid_morphs(o,volume=False):
    o.shape_key_add(name='Basis')
    for name in ['TiltX','TiltZ','Fill']:
        key=o.shape_key_add(name=name);key.slider_min=-1;key.slider_max=1;key.value=0
        for v,k in zip(o.data.vertices,key.data):
            factor=max(0,min(1,(v.co.z-.03)/.15)) if volume else 1
            if name=='TiltX':k.co.z+=v.co.x*.46875*factor
            elif name=='TiltZ':k.co.z+=v.co.y*.46875*factor
            else:k.co.z-=.13*factor
    o['liquid_morphs']='TiltX/TiltZ: 0.46875 slope; Fill: lower top by 0.13m'


def build():
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    OUT.mkdir(parents=True,exist_ok=True)
    glass=material('Clear soda lime glass',(.98,.995,1),.045,1,1.5,.007,1)
    beer=material('Amber beer volume',(.96,.46,.085),.06,1,1.333,.11,.14)
    surface=material('Beer meniscus',(.98,.70,.32),.045,.96,1.333,.004,.14)
    foam=material('Fine cream foam',(.94,.87,.68),.83)
    root=bpy.data.objects.new('BeerMugRoot',None);bpy.context.collection.objects.link(root)
    body=lathe('GlassBody',[(0,.006),(.050,.006),(.070,.008),(.075,.013),(.076,.025),
        (.072,.043),(.070,.174),(.073,.199),(.074,.207),(.073,.211),(.070,.213),
        (.067,.211),(.066,.207),(.066,.199),(.064,.174),(.064,.040),(.061,.026),(0,.026)],glass,64,.001)
    # Rounded handle: vertical contact section spanning all four fingers.
    points=[(.069,0,.182),(.108,0,.187),(.142,0,.175),(.155,0,.15),
            (.155,0,.083),(.141,0,.058),(.108,0,.048),(.07,0,.054)]
    curve=bpy.data.curves.new('Handle sweep','CURVE');curve.dimensions='3D';curve.resolution_u=5
    curve.bevel_depth=.011;curve.bevel_resolution=3;curve.use_fill_caps=True
    spline=curve.splines.new('BEZIER');spline.bezier_points.add(len(points)-1)
    for p,co in zip(spline.bezier_points,points):p.co=co;p.handle_left_type='AUTO';p.handle_right_type='AUTO'
    handle=bpy.data.objects.new('Handle',curve);bpy.context.collection.objects.link(handle);curve.materials.append(glass)
    bpy.ops.object.select_all(action='DESELECT');handle.select_set(True);bpy.context.view_layer.objects.active=handle
    bpy.ops.object.convert(target='MESH');handle=bpy.context.object
    liquid=lathe('BeerVolume',[(0,.027),(.062,.027),(.063,.04),(.063,.18),(0,.18)],beer)
    liquid_morphs(liquid,True)
    top=lathe('LiquidSurface',[(0,.1805),(.060,.1805),(.063,.182),(.063,.18),(0,.18)],surface)
    # Reverse this thin top shell's winding (the profile travels outward).
    for p in top.data.polygons:p.flip()
    liquid_morphs(top)
    froth=lathe('Foam',[(0,.181),(.060,.181),(.063,.184),(.063,.188),(.060,.192),(0,.194)],foam)
    # Small, irregular bubbles merge into a shallow foam head, not marshmallows.
    rng=random.Random(260905)
    parts=[froth]
    for i in range(70):
        a=rng.random()*math.tau;r=.059*math.sqrt(rng.random());size=rng.uniform(.001,.0035)
        bpy.ops.mesh.primitive_uv_sphere_add(segments=8,ring_count=4,radius=size,
            location=(r*math.cos(a),r*math.sin(a),.192+.001*(1-r/.06)))
        b=bpy.context.object;b.scale.z=.35;b.data.materials.append(foam);parts.append(b)
    bpy.ops.object.select_all(action='DESELECT')
    for o in parts:o.select_set(True)
    bpy.context.view_layer.objects.active=froth;bpy.ops.object.join()
    liquid_morphs(froth)
    # Fine carbonation uses one instanced-friendly mesh; animated in the lab.
    bubbles=[]
    for i in range(18):
        a=rng.random()*math.tau;r=rng.uniform(.025,.057)
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=rng.uniform(.0006,.0014),
            location=(r*math.cos(a),r*math.sin(a),rng.uniform(.04,.16)))
        o=bpy.context.object;o.data.materials.append(surface);bubbles.append(o)
    bpy.ops.object.select_all(action='DESELECT')
    for o in bubbles:o.select_set(True)
    bpy.context.view_layer.objects.active=bubbles[0];bpy.ops.object.join()
    bubbles[0].name='Carbonation';bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    grip=bpy.data.objects.new('Grip',None);bpy.context.collection.objects.link(grip);grip.location=(.155,0,.117)
    total=0
    for o in list(bpy.context.scene.objects):
        if o==root:continue
        o.parent=root
        if o.type=='MESH':
            o.data.calc_loop_triangles();total+=len(o.data.loop_triangles)
            for p in o.data.polygons:p.use_smooth=True
    root['asset_version']='2.0';root['capacity_ml']=500
    report={'version':2,'triangles':total,'units':'metres','grip_blender':[.155,0,.117],
        'grip_gltf':[.155,.117,0],'nodes':['GlassBody','Handle','BeerVolume','LiquidSurface','Foam','Carbonation','Grip'],
        'materials':{'glass':{'transmission':1,'ior':1.5,'thickness':.007},
                     'beer':{'transmission':1,'ior':1.333,'thickness':.11,'attenuation_distance':.14}},
        'liquid':{'bottom':.027,'surface':.18,'radius':.063,'fill_drop':.13,'slope_per_weight':.46875}}
    (OUT/'asset.json').write_text(json.dumps(report,indent=2)+'\n')
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'beer_mug.blend'))
    bpy.ops.export_scene.gltf(filepath=str(OUT/'beer_mug.glb'),export_format='GLB',use_selection=True,
        export_animations=False,export_extras=True,export_morph=True)
    print('BEER_MUG_V2',json.dumps(report),flush=True)

if __name__=='__main__':build()
