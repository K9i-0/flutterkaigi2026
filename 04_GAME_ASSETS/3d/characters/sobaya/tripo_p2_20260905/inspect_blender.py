"""Run with Blender --background --factory-startup --python this_file.py."""

import bpy
from collections import Counter
import json
import math
from mathutils import Vector
from pathlib import Path

HERE = Path(__file__).resolve().parent
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.fbx(filepath=str(HERE / "raw/output_model_url.fbx"))
meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
report = {"source": "raw/output_model_url.fbx", "objects": [], "images": []}
for obj in meshes:
    mesh = obj.data
    mesh.calc_loop_triangles()
    report["objects"].append({
        "name": obj.name, "vertices": len(mesh.vertices),
        "polygons": len(mesh.polygons), "triangles": len(mesh.loop_triangles),
        "polygon_sides": dict(Counter(len(face.vertices) for face in mesh.polygons)),
        "uv_layers": len(mesh.uv_layers), "materials": len(mesh.materials),
        "source_dimensions": list(obj.dimensions),
    })
for img in bpy.data.images:
    if img.packed_file:
        report["images"].append({"name": img.name, "size": list(img.size), "packed": True})
report["armatures"] = sum(obj.type == "ARMATURE" for obj in bpy.context.scene.objects)
report["animations"] = len(bpy.data.actions)

# Tripo default is X-forward; normalize to Blender -Y-forward and 1.80 m.
obj = meshes[0]
obj.name = "Sobaya"
obj.rotation_euler.z -= math.pi / 2
bpy.context.view_layer.update()
scale = 1.80 / obj.dimensions.z
obj.scale *= scale
bpy.context.view_layer.update()
corners = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
obj.location -= Vector(((min(p.x for p in corners)+max(p.x for p in corners))/2,
                        (min(p.y for p in corners)+max(p.y for p in corners))/2,
                        min(p.z for p in corners)))
bpy.context.view_layer.objects.active = obj
obj.select_set(True)
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
bpy.context.scene.unit_settings.system = "METRIC"
bpy.context.scene.unit_settings.scale_length = 1.0
report["normalized_dimensions_m"] = list(obj.dimensions)
report["normalization"] = "1.80 m tall, feet at Z=0, Blender -Y forward / glTF +Z forward"
(HERE / "audit.json").write_text(json.dumps(report, indent=2)+"\n")
bpy.ops.wm.save_as_mainfile(filepath=str(HERE / "sobaya_source.blend"))
bpy.ops.export_scene.gltf(filepath=str(HERE / "sobaya_preview.glb"), export_format="GLB",
                          use_selection=True, export_animations=False, export_image_format="AUTO")

# Separate review scene; lights and camera are not part of delivered asset.
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 16
scene.cycles.use_denoising = True
scene.render.resolution_x = 768
scene.render.resolution_y = 1024
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.14, 0.14, 0.14, 1)
scene.world.node_tree.nodes["Background"].inputs[1].default_value = 0.8
scene.view_settings.view_transform = "AgX"

def aim(obj, target):
    obj.rotation_euler = (Vector(target)-obj.location).to_track_quat("-Z", "Y").to_euler()

for name, position, power, size in (
    ("Key", (2,-3,4), 350, 4), ("Fill", (-3,-1,2), 250, 4),
    ("Back", (0,3,3), 350, 3),
):
    light=bpy.data.lights.new(name,"AREA")
    light.energy=power
    light.shape="DISK"
    light.size=size
    light_obj=bpy.data.objects.new(name,light)
    scene.collection.objects.link(light_obj)
    light_obj.location=position
    aim(light_obj,(0,0,0.9))
camera_data=bpy.data.cameras.new("ReviewCamera")
camera=bpy.data.objects.new("ReviewCamera",camera_data)
scene.collection.objects.link(camera)
scene.camera=camera
camera_data.type="ORTHO"
camera_data.ortho_scale=2.05
review=HERE/"review"
review.mkdir(exist_ok=True)
for name,position in (("front",(0,-4,0.95)),("side",(4,0,0.95)),("back",(0,4,0.95))):
    camera.location=position
    aim(camera,(0,0,0.9))
    scene.render.filepath=str(review/(name+".png"))
    bpy.ops.render.render(write_still=True)
print("SOBAYA_AUDIT",json.dumps(report))
