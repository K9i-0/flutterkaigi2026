"""Remove the small inward spur visible on Takosan's rear-right silhouette.

Blender --factory-startup --background --python tools/clean_takosan_tentacle_spur.py
Uses the adopted v4 source, preserves surviving vertices/UVs/weights and clips.
"""
from pathlib import Path
import hashlib
import json
import bpy
import bmesh

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / '04_GAME_ASSETS/3d/characters/takosan/rig_radial_v4_hands/takosan.blend'
OUT = SOURCE.parent.parent / 'rig_radial_v5_clean'
OUT.mkdir(exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
body = bpy.data.objects['TakosanBody']
rig = bpy.data.objects['TakosanRig']
mesh = body.data
bm = bmesh.new()
bm.from_mesh(mesh)
# This narrow branch is leftover generated geometry on the inside of the
# negative-X lateral tentacle, rather than one of the six curled limbs.
selected = [v for v in bm.verts if -.216 < v.co.x < -.17
            and .025 < v.co.y < .105 and v.co.z < .265]
assert len(selected) == 14, 'Unexpected source geometry; inspect before editing'
old_boundaries = {e for e in bm.edges if e.is_boundary}
unchanged = {v: v.co.copy() for v in bm.verts if v not in selected}
bmesh.ops.delete(bm, geom=selected, context='VERTS')
cut = [e for e in bm.edges if e.is_boundary and e not in old_boundaries]
assert len(cut) == 9, 'Expected one nine-edge cut'
# The spur meets an existing open seam left by the earlier center cleanup.
# Follow that same local boundary to close the entire connected opening.
closure = set(cut)
stack = list(cut)
while stack:
    edge = stack.pop()
    for vertex in edge.verts:
        for neighbor in vertex.link_edges:
            if neighbor.is_boundary and neighbor not in closure:
                closure.add(neighbor)
                stack.append(neighbor)
assert len(closure) == 25
assert all(v.co.z < .32 and v.co.xy.length < .33 for e in closure for v in e.verts)
faces = bmesh.ops.holes_fill(bm, edges=list(closure), sides=0)['faces']
assert len(faces) == 1
for face in faces:
    face.material_index = 1  # Existing matte dark lining, no stretched UVs.
    face.smooth = True
assert all(not e.is_boundary for e in cut)
assert all(v.co == co for v, co in unchanged.items())
bmesh.ops.recalc_face_normals(bm, faces=faces)
bm.to_mesh(mesh)
bm.free()
mesh.update()
mesh.calc_loop_triangles()
report = {
    'source': str(SOURCE.relative_to(ROOT)),
    'source_glb_sha256': hashlib.sha256(SOURCE.with_suffix('.glb').read_bytes()).hexdigest(),
    'change': 'Remove inward dangling spur on negative-X lateral tentacle; close local cut',
    'removed_vertices': 14, 'cut_edges': 9, 'cap_faces': len(faces), 'closed_boundary_edges': len(closure),
    'triangles': len(mesh.loop_triangles), 'bones': len(rig.data.bones),
    'clips': [a.name for a in bpy.data.actions],
    'preserved': ['all surviving vertex positions', 'six tentacles', 'UVs', 'skin weights', 'materials', 'animation keys'],
}
(OUT / 'revision.json').write_text(json.dumps(report, indent=2) + '\n')
(OUT / '.gitignore').write_text('*.blend\n*.blend1\npreview_*.png\n')
bpy.ops.object.select_all(action='DESELECT')
body.select_set(True)
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'takosan.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT / 'takosan.glb'), export_format='GLB',
    use_selection=True, export_animations=True, export_animation_mode='ACTIONS',
    export_frame_range=False, export_anim_slide_to_zero=True,
    export_anim_single_armature=True, export_skins=True, export_force_sampling=True)
print('TENTACLE_CLEANUP', json.dumps(report))
