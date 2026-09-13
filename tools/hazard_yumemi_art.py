"""Yumemi island art pass: shared opaque materials, authored Japanese landmarks.

Invoked before JSON/export so physical additions and visible geometry agree.
Existing routes, pickup positions and window apertures remain usable.
"""
import math
from pathlib import Path


def dress_yumemi(region, api):
    box, face, cylinder, solid = (api[k] for k in ('box', 'face', 'cylinder', 'solid'))
    wood, boards, stone, metal, plaster, roof = (api[k] for k in ('wood', 'boards', 'stone', 'metal', 'plaster', 'roof'))
    mats, groups = api['mats'], api['groups']
    material = api['material']
    concrete = material('Yumemi salt worn concrete', (.48, .51, .49), pattern='plaster')
    vermilion = material('Yumemi faded shrine red', (.36, .12, .085), pattern='wood')
    blue = material('Yumemi faded indigo cloth', (.12, .23, .28))
    enamel = material('Yumemi cream enamel signs', (.85, .81, .68))
    ep = mats[enamel].node_tree.nodes.get('Principled BSDF')
    ep.inputs['Emission Color'].default_value = (.85, .81, .68, 1)
    ep.inputs['Emission Strength'].default_value = .16
    gray_tiles = material('Yumemi gray roof tiles', (.34, .38, .39), pattern='roof')
    mats[roof] = mats[gray_tiles]

    def sign(name, text, x, z, h, width=3.2, height=.65):
        # Flat vector glyphs remain crisp without a unique 4K texture per sign.
        # Convert and join by material in make_objects' shared export stage.
        import bpy
        fontpath = '/System/Library/Fonts/Supplemental/Arial Unicode.ttf'
        font = bpy.data.fonts.load(fontpath) if Path(fontpath).exists() else None
        box(name, enamel, (x, z+.06, h), (width, .13, height))
        curve = bpy.data.curves.new(name+'_letters', 'FONT')
        curve.body = text; curve.align_x = 'CENTER'; curve.align_y = 'CENTER'
        curve.size = min(height*.63, width/max(len(text), 1)*.85)
        curve.resolution_u = 2
        if font: curve.font = font
        ob = bpy.data.objects.new(name+'_letters', curve); bpy.context.collection.objects.link(ob)
        ob.location = (x, z-.025, h); ob.rotation_euler = (math.pi/2, 0, 0)
        bpy.context.view_layer.objects.active = ob; ob.select_set(True)
        bpy.ops.object.convert(target='MESH')
        mesh = ob.data; transform = ob.matrix_world.copy()
        for poly in mesh.polygons:
            vs = [tuple(transform @ mesh.vertices[i].co) for i in poly.vertices]
            face(name, metal, vs, [(0, 0)]*len(vs))
        bpy.data.objects.remove(ob, do_unlink=True)

    # Tile ridges, broad eaves and thin wooden slats establish Japanese houses.
    for h in api['houses']:
        x,z,w,d,hh = (h[k] for k in ('x','z','w','d','height'))
        rg='Roof_'+h['id'];g='House_'+h['id']
        # Broad hipped tile roofs replace the high plaster gables and chimney.
        # Four simple slopes carry the detail in the shared tile texture.
        groups.pop(rg, None)
        rise=min(w,d)*.30
        a=(x-w/2-.55,z-d/2-.6,hh)
        b=(x+w/2+.55,z-d/2-.6,hh)
        c=(x+w/2+.55,z+d/2+.6,hh)
        dd=(x-w/2-.55,z+d/2+.6,hh)
        r1=(x-w*.25,z,hh+rise);r2=(x+w*.25,z,hh+rise)
        for vs in [[a,b,r2,r1],[b,c,r2],[c,dd,r1,r2],[dd,a,r1]]:
            face(rg,roof,vs,[(v[0],v[1]) for v in vs])
        box(rg,roof,(x,z,hh+rise+.08),(w*.5+.25,.28,.2))
        for side in [-1,1]:
            box(rg, wood, (x+side*(w/2+.28),z,hh-.08), (.20,d+1,.30))
        # A long lintel/eave avoids doors and usable vault openings.
        box(g, wood, (x,z-d/2-.36,2.65),(w+.5,.62,.13))
        for xx in [-w*.29,w*.29]:
            # Slim muntins inside the existing window area, never the vault.
            if xx<0 and w>=7: continue
            for i in [-.34,0,.34]:
                box(g, wood, (x+xx+i,z-d/2-.26,1.55),(.035,.035,1.1))

    if region=='village':
        # Remove forest cards on the sea side of the new quay.
        for name,parts in list(groups.items()):
            if not name.startswith('PinePatch_'): continue
            for data in parts.values():
                keep=[i for i,f in enumerate(data['f'])
                      if sum(data['v'][j][1] for j in f)/len(f)>-24]
                data['f']=[data['f'][i] for i in keep]
                data['uv']=[data['uv'][i] for i in keep]
            if not any(data['f'] for data in parts.values()): groups.pop(name)
        # Water visible immediately from the arrival courtyard, beyond its
        # existing south boundary. The pier is background, not a false route.
        sea=material('Yumemi harbor water',(.12,.23,.27),rough=.65)
        box('YumemiHarbor',sea,(0,-51,-.58),(150,48,.16))
        box('YumemiPier',concrete,(0,-32,-.15),(6.4,13,.48))
        box('YumemiQuay',concrete,(0,-24.95,-.3),(62,.5,.6))
        for x in [-35,30,55]:
            cylinder('HarborIslands',stone,(x,-70,1.8),12,4.5,9,r2=3)
        for x in [-2.8,2.8]:
            for z in [-27,-31,-35]:
                cylinder('YumemiPier',metal,(x,z,.24),.13,.5,8)
        sign('YumemiWelcome','ゆめみ村',-4.8,-22.3,2.25,3.5,.85)
        sign('YumemiWelcome','歓迎',-4.8,-22.31,1.62,2,.4)
        for x in [-6.2,-3.4]:
            box('YumemiWelcome',metal,(x,-22.2,1.1),(.09,.12,2.2));solid(x,-22.2,.12,.14,2.2)
        for h in api['houses']:
            title={'Entrance':'ゆめみ港 待合所','Barn':'漁具倉庫','West':'漁業組合','Shotgun':'港湾事務所','East':'荷扱所'}[h['id']]
            sign('PortSigns',title,h['x'],h['z']-h['d']/2-.4,2.83,min(h['w']-.5,4),.4)
        sign('PortSigns','商店街 →',11.5,23.1,3.6,3.8,.6)
        for x,z in [(-18,-18),(18,-16),(18,18)]:
            # Fish crates and bundled fishing poles occupy matching colliders.
            box('FishingGear',blue,(x,z,.35),(1.4,.8,.7));solid(x,z,1.4,.8,.7)
            for dx in [-.4,0,.4]:box('FishingGear',wood,(x+dx,z,.8),(.05,.05,1.6))
        # Remove the European bell; its arch becomes a practical port gate.
        groups.pop('Bell',None)
    elif region=='farm':
        for h in api['houses']:
            title={'SaveHut':'ゆめみ村 商店街','Tools':'旧管理室','NorthShed':'診療所','Barn':'村民集会所'}[h['id']]
            sign('VillageSigns',title,h['x'],h['z']-h['d']/2-.4,2.82,min(h['w']-.5,4),.42)
        # Shop backdrop behind the authored merchant at (-13,-17.8).
        box('TakosanShop',wood,(-13,-16.95,1.15),(3.4,.18,2.3))
        solid(-13,-16.95,3.4,.18,2.3)
        sign('TakosanShop','たこさん商店',-13,-17.1,2.55,3.9,.58)
        for i in range(6):box('TakosanShop',blue,(-14.42+i*.57,-17.45,2.02),(.53,.04,.48))
        box('TakosanShop',boards,(-13,-17.05,.28),(3.5,.8,.55))
        for i in range(8):box('TakosanShop',api['paper'],(-14.35+i*.37,-17.23,.64),(.24,.2,.18))
        sign('VillageSigns','神社 →',19.8,-11.9,2.5,2.4,.48)
        # No animal pen scenery: its fences now border an abandoned allotment.
        groups.pop('Hay bales',None)
        sign('VillageSigns','着任受付',8,-14.35,2.28,1.4,.43)
    else:
        # The former gathering house is a shrine office; the combat yard is
        # the precinct. A torii spans the approach without narrowing it.
        for x in [2.2,7.8]:
            cylinder('YumemiTorii',vermilion,(x,-.3,2.1),.22,4.2,10,r2=.18)
            solid(x,-.3,.42,.42,4.2)
        box('YumemiTorii',vermilion,(5,-.3,3.35),(6.3,.25,.25))
        box('YumemiTorii',vermilion,(5,-.3,4.2),(7,.45,.3))
        box('YumemiTorii',roof,(5,-.3,4.4),(7.5,.6,.17))
        sign('ShrineSigns','ゆめみ神社',13,9.1,2.75,3.2,.48)
        for x,z in [(4,9),(17,2)]:
            # Existing matching yard-cover footprints support stone lanterns.
            cylinder('StoneLanterns',stone,(x,z,1.65),.21,1,8)
            box('StoneLanterns',stone,(x,z,2.2),(.6,.6,.5))
            box('StoneLanterns',roof,(x,z,2.5),(.95,.95,.18))
            solid(x,z,.95,.95,1.3,bottom=1.3)
        # A modest sanctuary on the existing floor, behind the normal entrance.
        box('ShrineAltar',wood,(13,17.95,.65),(2.5,.5,1.3));solid(13,17.95,2.5,.5,1.3)
        cylinder('ShrineMirror',api['brass'],(13,17.66,1.5),.22,.035,16,axis=(0,1,0))
        # Reveal reached from the eastern management lane after the boss.
        box('FacilityEntrance',concrete,(21.1,18.8,2.25),(4.4,1.0,4.5));solid(21.1,18.8,4.4,1,4.5)
        box('FacilityEntrance',metal,(21.1,18.25,1.75),(3.25,.08,3.5))
        sign('FacilityEntrance','ACCIDENCHUA',21.1,18.13,3.85,4.1,.62)
        for x in [19.25,22.95]:
            cylinder('FacilityDucts',metal,(x,19,5),.28,3,10)
        box('FacilityStatus',api['amber'],(19.6,18.05,2.5),(.12,.08,.16))
