"""Create a draw-call-consolidated mobile GLB from a canonical voxel GLB.

The character kit uses empty objects as rigid animation pivots.  Mesh objects
that share one pivot can therefore be joined without changing the silhouette,
materials, or runtime walk rig.  Blender keeps distinct material primitives in
the joined mesh, while Flutter Scene has far fewer nodes to traverse and cull.

Run with Blender:
  blender --background --python tools/optimize_voxel_model_for_mobile.py -- \
    --input models/sobaya.glb --output models/mobile/sobaya.glb
"""

from __future__ import annotations

import argparse
import os
import sys

import bpy


def make_shared_solid_material() -> bpy.types.Material:
    material = bpy.data.materials.new("VoxelMobile_VertexColorPBR")
    material.use_nodes = True
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (1.0, 1.0, 1.0, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.82
    vertex_color = material.node_tree.nodes.new("ShaderNodeVertexColor")
    vertex_color.layer_name = "VoxelMobileColor"
    material.node_tree.links.new(
        vertex_color.outputs["Color"], bsdf.inputs["Base Color"]
    )
    return material


def is_plain_opaque_material(material: bpy.types.Material) -> bool:
    if not material.use_nodes:
        return material.diffuse_color[3] >= 0.999
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    if bsdf is None:
        return False
    base_color = bsdf.inputs.get("Base Color")
    alpha = bsdf.inputs.get("Alpha")
    emission = bsdf.inputs.get("Emission Color")
    emission_strength = bsdf.inputs.get("Emission Strength")
    transmission = bsdf.inputs.get("Transmission Weight")
    return (
        base_color is not None
        and not base_color.is_linked
        and (alpha is None or (not alpha.is_linked and alpha.default_value >= 0.999))
        and (emission is None or not emission.is_linked)
        and (emission_strength is None or emission_strength.default_value <= 0.0001)
        and (transmission is None or transmission.default_value <= 0.0001)
        and material.diffuse_color[3] >= 0.999
    )


def consolidate_plain_materials(shared: bpy.types.Material) -> int:
    consolidated = 0
    for obj in [item for item in bpy.context.scene.objects if item.type == "MESH"]:
        mesh = obj.data
        old_materials = list(mesh.materials)
        if not old_materials:
            continue
        plain = [is_plain_opaque_material(material) for material in old_materials]
        if not any(plain):
            continue

        colors = mesh.color_attributes.get("VoxelMobileColor")
        if colors is None:
            colors = mesh.color_attributes.new(
                name="VoxelMobileColor",
                type="FLOAT_COLOR",
                domain="CORNER",
            )
        mesh.color_attributes.active_color = colors

        retained = []
        retained_index = {}
        for material, is_plain in zip(old_materials, plain):
            if is_plain or material in retained_index:
                continue
            retained_index[material] = len(retained) + 1
            retained.append(material)

        for polygon in mesh.polygons:
            old_index = min(polygon.material_index, len(old_materials) - 1)
            material = old_materials[old_index]
            if plain[old_index]:
                color = tuple(material.diffuse_color)
                polygon.material_index = 0
                consolidated += 1
            else:
                color = (1.0, 1.0, 1.0, 1.0)
                polygon.material_index = retained_index[material]
            for loop_index in polygon.loop_indices:
                colors.data[loop_index].color = color

        mesh.materials.clear()
        mesh.materials.append(shared)
        for material in retained:
            mesh.materials.append(material)
    return consolidated


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    script_args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    return parser.parse_args(script_args)


def join_direct_mesh_children(parent: bpy.types.Object) -> int:
    joined_count = 0
    for child in list(parent.children):
        if child.type == "EMPTY":
            joined_count += join_direct_mesh_children(child)

    meshes = [child for child in parent.children if child.type == "MESH"]
    if len(meshes) < 2:
        return joined_count

    bpy.ops.object.select_all(action="DESELECT")
    for mesh in meshes:
        mesh.select_set(True)
    active = meshes[0]
    bpy.context.view_layer.objects.active = active
    bpy.ops.object.join()
    active.name = f"{parent.name}_MobileMesh"
    joined_count += len(meshes) - 1
    return joined_count


def main() -> None:
    args = parse_args()
    input_path = os.path.abspath(args.input)
    output_path = os.path.abspath(args.output)
    os.makedirs(os.path.dirname(output_path), exist_ok=True)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=input_path)

    rig_roots = [
        obj
        for obj in bpy.context.scene.objects
        if obj.type == "EMPTY" and obj.get("voxel_rig_schema")
    ]
    if len(rig_roots) != 1:
        raise RuntimeError(
            f"Expected one voxel rig root in {input_path}, found {len(rig_roots)}"
        )

    consolidated_faces = consolidate_plain_materials(
        make_shared_solid_material()
    )
    before = sum(obj.type == "MESH" for obj in bpy.context.scene.objects)
    joined = join_direct_mesh_children(rig_roots[0])
    after = sum(obj.type == "MESH" for obj in bpy.context.scene.objects)

    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(
        filepath=output_path,
        export_format="GLB",
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_materials="EXPORT",
        export_extras=True,
        export_cameras=False,
        export_lights=False,
        export_apply=True,
    )
    print(
        "VOXEL_MOBILE_OPTIMIZE_COMPLETE",
        input_path,
        output_path,
        f"meshes={before}->{after}",
        f"joined={joined}",
        f"solid_faces={consolidated_faces}",
    )


if __name__ == "__main__":
    main()
