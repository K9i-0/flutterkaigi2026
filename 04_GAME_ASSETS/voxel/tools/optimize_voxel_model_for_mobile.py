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
import json
import os
import struct
import sys

import bpy


IDENTITY_MATERIAL_MARKERS = ("face", "mask", "albedo", "surface", "screen")


def preserves_identity_texture(material: bpy.types.Material) -> bool:
    """Keep identity-critical panels out of vertex-color consolidation.

    Blender's glTF importer does not guarantee that every imported texture is
    connected directly to the Principled BSDF Base Color input.  Checking only
    that socket can therefore misclassify a face panel as a solid material.
    The image-node check is authoritative; material-name markers are a safety
    net for replaceable face/mask panels from the voxel character kit.
    """
    if any(marker in material.name.lower() for marker in IDENTITY_MATERIAL_MARKERS):
        return True
    if not material.use_nodes or material.node_tree is None:
        return False
    return any(
        node.type == "TEX_IMAGE" and getattr(node, "image", None) is not None
        for node in material.node_tree.nodes
    )


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
    if preserves_identity_texture(material):
        return False
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

        target_material_indices = []
        for polygon in mesh.polygons:
            old_index = min(polygon.material_index, len(old_materials) - 1)
            material = old_materials[old_index]
            if plain[old_index]:
                color = tuple(material.diffuse_color)
                target_material_indices.append(0)
                consolidated += 1
            else:
                color = (1.0, 1.0, 1.0, 1.0)
                target_material_indices.append(retained_index[material])
            for loop_index in polygon.loop_indices:
                colors.data[loop_index].color = color

        # Clearing slots resets polygon indices in Blender. Reapply the saved
        # mapping only after the replacement material table is complete.
        mesh.materials.clear()
        mesh.materials.append(shared)
        for material in retained:
            mesh.materials.append(material)
        for polygon, target_index in zip(mesh.polygons, target_material_indices):
            polygon.material_index = target_index
    return consolidated


def identity_material_names() -> set[str]:
    return {
        material.name
        for material in bpy.data.materials
        if preserves_identity_texture(material)
    }


def normalize_retained_material_colors(shared: bpy.types.Material) -> int:
    """Prevent vertex colors from tinting retained PBR/image materials.

    Mesh joining can fill a joined object's color attribute with black for a
    source primitive that did not own the active attribute. glTF multiplies
    COLOR_0 with the material/texture, which made Sobaya's mask fully black.
    Only the shared solid material consumes authored vertex colors; every
    retained material must therefore receive a white multiplier.
    """
    normalized_loops = 0
    for obj in (item for item in bpy.context.scene.objects if item.type == "MESH"):
        mesh = obj.data
        colors = mesh.color_attributes.get("VoxelMobileColor")
        if colors is None:
            continue
        for polygon in mesh.polygons:
            if polygon.material_index >= len(mesh.materials):
                continue
            material = mesh.materials[polygon.material_index]
            if material is None or material == shared:
                continue
            for loop_index in polygon.loop_indices:
                colors.data[loop_index].color = (1.0, 1.0, 1.0, 1.0)
                normalized_loops += 1
    return normalized_loops


def validate_identity_color_multipliers() -> None:
    for obj in (item for item in bpy.context.scene.objects if item.type == "MESH"):
        mesh = obj.data
        colors = mesh.color_attributes.get("VoxelMobileColor")
        if colors is None:
            continue
        for polygon in mesh.polygons:
            if polygon.material_index >= len(mesh.materials):
                continue
            material = mesh.materials[polygon.material_index]
            if material is None or not preserves_identity_texture(material):
                continue
            for loop_index in polygon.loop_indices:
                if min(colors.data[loop_index].color[:3]) < 0.999:
                    raise RuntimeError(
                        f"Identity texture on {obj.name} has a non-white "
                        f"vertex-color multiplier: {material.name}"
                    )


def embedded_identity_image_count() -> int:
    return len(
        {
            node.image.name
            for material in bpy.data.materials
            if preserves_identity_texture(material)
            and material.use_nodes
            and material.node_tree is not None
            for node in material.node_tree.nodes
            if node.type == "TEX_IMAGE" and getattr(node, "image", None) is not None
        }
    )


def resize_identity_images(max_size: int) -> list[str]:
    """Bound mobile texture memory without changing canonical source images."""
    if max_size <= 0:
        return []
    images = {
        node.image
        for material in bpy.data.materials
        if preserves_identity_texture(material)
        and material.use_nodes
        and material.node_tree is not None
        for node in material.node_tree.nodes
        if node.type == "TEX_IMAGE" and getattr(node, "image", None) is not None
    }
    resized = []
    for image in images:
        width, height = image.size
        longest = max(width, height)
        if longest <= max_size:
            continue
        scale = max_size / longest
        target_width = max(1, round(width * scale))
        target_height = max(1, round(height * scale))
        image.scale(target_width, target_height)
        image.update()
        resized.append(f"{image.name}:{width}x{height}->{target_width}x{target_height}")
    return sorted(resized)


def validate_exported_identity(
    output_path: str,
    expected_materials: set[str],
    expected_image_count: int,
) -> int:
    with open(output_path, "rb") as glb:
        data = glb.read()
    _, _, total_length = struct.unpack_from("<4sII", data, 0)
    offset = 12
    document = None
    while offset < total_length:
        chunk_length, chunk_type = struct.unpack_from("<II", data, offset)
        offset += 8
        chunk = data[offset : offset + chunk_length]
        offset += chunk_length
        if chunk_type == 0x4E4F534A:
            document = json.loads(chunk)
            break
    if document is None:
        raise RuntimeError(f"No JSON chunk found in exported GLB: {output_path}")

    exported_materials = {
        material.get("name", "") for material in document.get("materials", [])
    }
    missing_materials = expected_materials - exported_materials
    if missing_materials:
        raise RuntimeError(
            "Identity materials are not assigned in exported GLB: "
            f"{sorted(missing_materials)}"
        )
    image_count = len(document.get("images", []))
    if image_count < expected_image_count:
        raise RuntimeError(
            f"Expected {expected_image_count} embedded identity images, "
            f"exported {image_count}: {output_path}"
        )
    return image_count


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument(
        "--max-texture-size",
        type=int,
        default=256,
        help="Maximum edge length for images embedded in the mobile GLB; 0 disables resizing",
    )
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

    identity_materials_before = identity_material_names()
    identity_images_before = embedded_identity_image_count()
    if not identity_materials_before:
        raise RuntimeError(f"No identity texture material found in {input_path}")
    if identity_images_before < 1:
        raise RuntimeError(f"No embedded identity image found in {input_path}")

    shared_material = make_shared_solid_material()
    consolidated_faces = consolidate_plain_materials(shared_material)
    identity_materials_after = identity_material_names()
    missing_identity_materials = identity_materials_before - identity_materials_after
    if missing_identity_materials:
        raise RuntimeError(
            "Identity texture materials were lost during consolidation: "
            f"{sorted(missing_identity_materials)}"
        )
    before = sum(obj.type == "MESH" for obj in bpy.context.scene.objects)
    joined = join_direct_mesh_children(rig_roots[0])
    after = sum(obj.type == "MESH" for obj in bpy.context.scene.objects)
    normalized_loops = normalize_retained_material_colors(shared_material)
    validate_identity_color_multipliers()
    resized_images = resize_identity_images(args.max_texture_size)

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
    exported_image_count = validate_exported_identity(
        output_path,
        identity_materials_before,
        identity_images_before,
    )
    print(
        "VOXEL_MOBILE_OPTIMIZE_COMPLETE",
        input_path,
        output_path,
        f"meshes={before}->{after}",
        f"joined={joined}",
        f"solid_faces={consolidated_faces}",
        f"normalized_retained_loops={normalized_loops}",
        f"identity_materials={sorted(identity_materials_after)}",
        f"embedded_images={exported_image_count}",
        f"resized_images={resized_images}",
    )


if __name__ == "__main__":
    main()
