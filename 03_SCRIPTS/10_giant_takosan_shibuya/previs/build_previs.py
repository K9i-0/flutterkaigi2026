from __future__ import annotations

import math
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parent
BLEND_PATH = ROOT / "giant_takosan_battle_previs.blend"
VIDEO_PATH = ROOT / "giant_takosan_battle_previs"
STORYBOARD_DIR = ROOT / "storyboard_frames"
RENDER_DIR = ROOT / "render_frames"

FPS = 24
FRAME_END = 176  # 7.33 seconds: the 15.4-22.7 second battle block.


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (
        bpy.data.meshes,
        bpy.data.curves,
        bpy.data.materials,
        bpy.data.cameras,
        bpy.data.lights,
    ):
        for datablock in list(datablocks):
            if datablock.users == 0:
                datablocks.remove(datablock)


def material(
    name: str,
    color: tuple[float, float, float, float],
    *,
    emission: tuple[float, float, float, float] | None = None,
    emission_strength: float = 0.0,
    metallic: float = 0.0,
    roughness: float = 0.65,
) -> bpy.types.Material:
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if emission is not None:
        emission_input = bsdf.inputs.get("Emission Color") or bsdf.inputs.get("Emission")
        strength_input = bsdf.inputs.get("Emission Strength")
        if emission_input is not None:
            emission_input.default_value = emission
        if strength_input is not None:
            strength_input.default_value = emission_strength
    return mat


def add_cube(
    name: str,
    location: tuple[float, float, float],
    dimensions: tuple[float, float, float],
    mat: bpy.types.Material,
    *,
    rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    return obj


def add_uv_sphere(
    name: str,
    location: tuple[float, float, float],
    scale: tuple[float, float, float],
    mat: bpy.types.Material,
    *,
    segments: int = 24,
    rings: int = 12,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    return obj


def add_curve(
    name: str,
    points: list[tuple[float, float, float]],
    radius: float,
    mat: bpy.types.Material,
    *,
    parent: bpy.types.Object | None = None,
) -> tuple[bpy.types.Object, list[bpy.types.SplinePoint]]:
    curve = bpy.data.curves.new(name, type="CURVE")
    curve.dimensions = "3D"
    curve.resolution_u = 2
    curve.bevel_depth = radius
    curve.bevel_resolution = 2
    spline = curve.splines.new("POLY")
    spline.points.add(len(points) - 1)
    for point, coord in zip(spline.points, points):
        point.co = (*coord, 1.0)
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    curve.materials.append(mat)
    if parent is not None:
        obj.parent = parent
    return obj, list(spline.points)


def cylinder_between(
    name: str,
    start: tuple[float, float, float],
    end: tuple[float, float, float],
    radius: float,
    mat: bpy.types.Material,
) -> bpy.types.Object:
    p1 = Vector(start)
    p2 = Vector(end)
    delta = p2 - p1
    midpoint = (p1 + p2) * 0.5
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=radius, depth=delta.length, location=midpoint)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = delta.to_track_quat("Z", "Y")
    obj.rotation_mode = "XYZ"
    obj.data.materials.append(mat)
    return obj


def animate_visible(obj: bpy.types.Object, start: int, end: int) -> None:
    original_scale = obj.scale.copy()
    obj.scale = (0.001, 0.001, 0.001)
    obj.keyframe_insert(data_path="scale", frame=max(1, start - 1))
    obj.scale = original_scale
    obj.keyframe_insert(data_path="scale", frame=start)
    obj.keyframe_insert(data_path="scale", frame=end)
    obj.scale = (0.001, 0.001, 0.001)
    obj.keyframe_insert(data_path="scale", frame=min(FRAME_END, end + 1))


def animate_appears(obj: bpy.types.Object, frame: int) -> None:
    original_scale = obj.scale.copy()
    obj.scale = (0.001, 0.001, 0.001)
    obj.keyframe_insert(data_path="scale", frame=max(1, frame - 1))
    obj.scale = original_scale
    obj.keyframe_insert(data_path="scale", frame=frame)


def animate_disappears(obj: bpy.types.Object, frame: int) -> None:
    original_scale = obj.scale.copy()
    obj.scale = original_scale
    obj.keyframe_insert(data_path="scale", frame=max(1, frame - 1))
    obj.scale = (0.001, 0.001, 0.001)
    obj.keyframe_insert(data_path="scale", frame=frame)


def make_beam_pair(
    name: str,
    start: tuple[float, float, float],
    end: tuple[float, float, float],
    start_frame: int,
    end_frame: int,
    beam_mat: bpy.types.Material,
    core_mat: bpy.types.Material,
) -> None:
    for index, offset in enumerate((-0.22, 0.22), start=1):
        shifted_start = (start[0] + offset, start[1], start[2])
        shifted_end = (end[0] + offset, end[1], end[2])
        outer = cylinder_between(f"{name}_outer_{index}", shifted_start, shifted_end, 0.24, beam_mat)
        core = cylinder_between(f"{name}_core_{index}", shifted_start, shifted_end, 0.075, core_mat)
        animate_visible(outer, start_frame, end_frame)
        animate_visible(core, start_frame, end_frame)


def add_camera(
    name: str,
    location: tuple[float, float, float],
    target: tuple[float, float, float],
    lens: float,
    *,
    roll_degrees: float = 0.0,
) -> tuple[bpy.types.Object, bpy.types.Object, bpy.types.Object]:
    target_obj = bpy.data.objects.new(f"{name}_target", None)
    target_obj.location = target
    bpy.context.collection.objects.link(target_obj)

    rig = bpy.data.objects.new(f"{name}_rig", None)
    rig.location = location
    bpy.context.collection.objects.link(rig)
    constraint = rig.constraints.new(type="TRACK_TO")
    constraint.target = target_obj
    constraint.track_axis = "TRACK_NEGATIVE_Z"
    constraint.up_axis = "UP_Y"

    camera_data = bpy.data.cameras.new(name)
    camera_data.lens = lens
    camera_data.sensor_width = 36.0
    camera = bpy.data.objects.new(name, camera_data)
    bpy.context.collection.objects.link(camera)
    camera.parent = rig
    camera.location = (0.0, 0.0, 0.0)
    camera.rotation_euler = (0.0, 0.0, math.radians(roll_degrees))
    return camera, rig, target_obj


def add_marker(scene: bpy.types.Scene, name: str, frame: int, camera: bpy.types.Object) -> None:
    marker = scene.timeline_markers.new(name, frame=frame)
    marker.camera = camera


def build_scene() -> bpy.types.Scene:
    clear_scene()
    scene = bpy.context.scene
    scene.frame_start = 1
    scene.frame_end = FRAME_END
    scene.render.fps = FPS
    scene.render.resolution_x = 854
    scene.render.resolution_y = 480
    scene.render.resolution_percentage = 100
    scene.render.engine = "BLENDER_EEVEE"
    RENDER_DIR.mkdir(parents=True, exist_ok=True)
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(RENDER_DIR / "frame_")
    scene.render.film_transparent = False
    scene.world.color = (0.012, 0.018, 0.035)

    try:
        scene.view_settings.look = "AgX - Medium High Contrast"
    except TypeError:
        pass

    asphalt = material("Asphalt", (0.035, 0.045, 0.06, 1.0), roughness=0.95)
    concrete = material("Concrete", (0.24, 0.28, 0.34, 1.0), roughness=0.82)
    concrete_dark = material("ConcreteDark", (0.11, 0.14, 0.19, 1.0), roughness=0.85)
    window = material("Window", (0.045, 0.13, 0.2, 1.0), metallic=0.35, roughness=0.28)
    white = material("White", (0.86, 0.88, 0.88, 1.0), roughness=0.6)
    black = material("TakosanBlack", (0.008, 0.01, 0.015, 1.0), roughness=0.72)
    red_glow = material(
        "RedGlow",
        (0.5, 0.01, 0.005, 1.0),
        emission=(1.0, 0.015, 0.003, 1.0),
        emission_strength=14.0,
        roughness=0.25,
    )
    orange_glow = material(
        "OrangeGlow",
        (0.8, 0.08, 0.005, 1.0),
        emission=(1.0, 0.035, 0.002, 1.0),
        emission_strength=18.0,
        roughness=0.18,
    )
    beam_outer = material(
        "BeamOuter",
        (0.9, 0.02, 0.003, 1.0),
        emission=(1.0, 0.01, 0.002, 1.0),
        emission_strength=24.0,
        roughness=0.05,
    )
    beam_core = material(
        "BeamCore",
        (1.0, 0.9, 0.72, 1.0),
        emission=(1.0, 0.62, 0.32, 1.0),
        emission_strength=40.0,
        roughness=0.0,
    )
    screen_a_mat = material(
        "ScreenAFeed",
        (0.62, 0.06, 0.7, 1.0),
        emission=(0.52, 0.03, 0.7, 1.0),
        emission_strength=5.0,
    )
    screen_c_mat = material(
        "ScreenCFeed",
        (0.0, 0.48, 0.72, 1.0),
        emission=(0.0, 0.42, 0.85, 1.0),
        emission_strength=6.0,
    )
    smoke_mat = material("Smoke", (0.08, 0.09, 0.11, 1.0), roughness=1.0)

    # Shibuya-like blockout and crossing.
    add_cube("Ground", (0.0, 0.0, -0.35), (110.0, 110.0, 0.7), asphalt)
    for stripe in range(-7, 8):
        add_cube(f"Crossing_{stripe:+03d}", (stripe * 2.3, -3.0, 0.03), (1.25, 18.0, 0.06), white)
    add_cube("MainRoad", (0.0, 13.0, -0.02), (21.0, 80.0, 0.04), asphalt)

    # Background city blocks.
    block_specs = [
        (-38, 30, 11, 13, 26),
        (-40, -6, 14, 12, 34),
        (-34, -30, 16, 14, 24),
        (38, 27, 14, 12, 31),
        (41, 1, 13, 15, 27),
        (49, -7, 16, 14, 36),
    ]
    for index, (x, y, sx, sy, height) in enumerate(block_specs, start=1):
        add_cube(f"CityBlock_{index}", (x, y, height * 0.5), (sx, sy, height), concrete_dark)

    # Monitor A host building and display.
    add_cube("MonitorA_Host", (0.0, 29.0, 17.0), (14.0, 9.0, 34.0), concrete)
    add_cube("MonitorA_WindowBand", (0.0, 24.42, 25.0), (11.5, 0.18, 7.0), window)
    screen_a_dark = add_cube("ScreenA_Dark", (0.0, 24.22, 16.5), (8.6, 0.22, 6.8), black)
    screen_a_active = add_cube("ScreenA_Active", (0.0, 24.06, 16.5), (7.8, 0.12, 6.0), screen_a_mat)
    animate_disappears(screen_a_active, 27)

    # Monitor C host building and display.
    add_cube("MonitorC_Host", (-28.0, 18.0, 20.0), (13.0, 10.0, 40.0), concrete_dark)
    add_cube("MonitorC_WindowBand", (-28.0, 12.91, 29.0), (10.5, 0.18, 8.0), window)
    add_cube("ScreenC_Dark", (-28.0, 12.72, 19.0), (8.5, 0.22, 6.8), black)
    screen_c_active = add_cube("ScreenC_Active", (-28.0, 12.56, 19.0), (7.7, 0.12, 6.0), screen_c_mat)
    animate_appears(screen_c_active, 56)

    # Giant Takosan blockout. The neutral geometry is a motion and scale guide only.
    takosan_root = bpy.data.objects.new("GiantTakosan_Root", None)
    bpy.context.collection.objects.link(takosan_root)
    bpy.ops.mesh.primitive_cone_add(vertices=28, radius1=7.5, radius2=4.1, depth=16.0, location=(0.0, 0.0, 8.0))
    body = bpy.context.object
    body.name = "GiantTakosan_FusedMantle"
    body.data.materials.append(black)
    body.parent = takosan_root
    hood = add_uv_sphere("GiantTakosan_Hood", (0.0, 0.0, 20.0), (5.3, 4.8, 6.3), black)
    hood.parent = takosan_root
    face = add_uv_sphere("GiantTakosan_Face", (0.0, -4.05, 20.7), (3.3, 0.55, 3.2), white)
    face.parent = takosan_root
    for x in (-1.22, 1.22):
        eye = add_uv_sphere(f"GiantTakosan_Eye_{x:+.2f}", (x, -4.62, 21.25), (0.42, 0.22, 0.42), red_glow)
        eye.parent = takosan_root

    # Tiny separate arms stay idle; lower-body tentacles do all attacking.
    for side in (-1.0, 1.0):
        arm = cylinder_between(
            f"GiantTakosan_Arm_{side:+.0f}",
            (side * 4.7, -0.3, 14.0),
            (side * 6.0, -0.8, 10.8),
            0.65,
            black,
        )
        arm.parent = takosan_root
        hand = add_uv_sphere(
            f"GiantTakosan_TinyHand_{side:+.0f}",
            (side * 6.1, -0.85, 10.35),
            (0.82, 0.7, 0.82),
            white,
            segments=16,
            rings=8,
        )
        hand.parent = takosan_root

    for index, angle in enumerate((205, 230, 255, 285, 310, 335, 20, 55), start=1):
        rad = math.radians(angle)
        end = (math.cos(rad) * 15.0, math.sin(rad) * 15.0, 0.7)
        bend = (math.cos(rad + 0.18) * 8.0, math.sin(rad + 0.18) * 8.0, 1.2)
        add_curve(
            f"GiantTakosan_LowerTentacle_{index:02d}",
            [(0.0, 0.0, 1.0), bend, end],
            0.85,
            black,
            parent=takosan_root,
        )

    strike_curve, strike_points = add_curve(
        "GiantTakosan_LowerTentacle_Strike",
        [(0.0, 3.0, 1.2), (0.0, 8.0, 1.6), (-1.0, 13.0, 3.2), (0.0, 18.0, 7.0)],
        1.05,
        black,
        parent=takosan_root,
    )
    strike_poses = {
        1: [(0.0, 3.0, 1.2), (0.0, 7.0, 1.4), (-1.0, 11.0, 2.2), (-2.0, 14.0, 3.0)],
        20: [(0.0, 3.0, 1.2), (0.0, 8.0, 1.7), (-2.0, 14.0, 4.5), (-4.0, 18.0, 8.0)],
        27: [(0.0, 3.0, 1.2), (1.0, 10.0, 2.4), (2.0, 18.0, 9.5), (0.0, 24.0, 16.5)],
        45: [(0.0, 3.0, 1.2), (0.0, 8.0, 1.7), (-1.0, 12.0, 2.5), (-2.0, 15.0, 3.5)],
    }
    for frame, coords in strike_poses.items():
        for point, coord in zip(strike_points, coords):
            point.co = (*coord, 1.0)
            point.keyframe_insert(data_path="co", frame=frame)

    takosan_root.location = (0.0, 0.0, 0.0)
    takosan_root.keyframe_insert(data_path="location", frame=56)
    takosan_root.location = (-8.0, 0.0, 0.0)
    takosan_root.keyframe_insert(data_path="location", frame=68)
    takosan_root.keyframe_insert(data_path="location", frame=155)
    takosan_root.scale = (1.0, 1.0, 1.0)
    takosan_root.keyframe_insert(data_path="scale", frame=155)
    takosan_root.scale = (0.06, 0.06, 0.06)
    takosan_root.keyframe_insert(data_path="scale", frame=176)
    # Beam paths: Monitor A, rerouted Monitor C, then the destructive oversweep.
    make_beam_pair("Beam_A", (0.0, 23.8, 17.2), (0.0, -1.0, 14.0), 1, 25, beam_outer, beam_core)
    make_beam_pair("Beam_C_Hit", (-28.0, 12.35, 19.6), (-2.0, 0.0, 14.0), 56, 67, beam_outer, beam_core)
    make_beam_pair("Beam_C_Oversweep", (-28.0, 12.35, 19.6), (36.0, -31.0, 13.0), 68, 154, beam_outer, beam_core)
    make_beam_pair("Beam_C_Final", (-28.0, 12.35, 19.6), (-8.0, 0.0, 7.0), 155, 164, beam_outer, beam_core)

    # Surface impact on Takosan.
    for index, offset in enumerate(((-1.6, -4.8, 14.5), (0.0, -5.2, 15.5), (1.5, -4.7, 13.4)), start=1):
        spark = add_uv_sphere(f"TakosanImpact_{index}", offset, (0.8, 0.35, 0.8), orange_glow, segments=12, rings=6)
        animate_visible(spark, 11 + index, 20 + index)

    # Screen A local fragments. The host building remains intact.
    fragment_specs = [
        (-2.6, 23.4, 17.5, -1.8, -1.6),
        (-0.8, 23.3, 15.8, -0.6, -2.0),
        (1.0, 23.3, 17.3, 0.8, -1.4),
        (2.8, 23.4, 15.4, 1.8, -2.2),
    ]
    for index, (x, y, z, dx, dz) in enumerate(fragment_specs, start=1):
        frag = add_cube(f"ScreenA_Fragment_{index}", (x, y, z), (1.3, 0.5, 1.0), window)
        animate_appears(frag, 27)
        frag.location = (x, y, z)
        frag.keyframe_insert(data_path="location", frame=27)
        frag.rotation_euler = (0.0, 0.0, 0.0)
        frag.keyframe_insert(data_path="rotation_euler", frame=27)
        frag.location = (x + dx, y - 1.2, max(0.5, z + dz * 4.2))
        frag.rotation_euler = (1.7 * index, 0.6 * index, 1.1 * index)
        frag.keyframe_insert(data_path="location", frame=55)
        frag.keyframe_insert(data_path="rotation_euler", frame=55)

    # Two evacuated high-rises split at the red-hot kerf and collapse in one direction.
    collapse_specs = [
        ("CollapseTower_1", (15.0, -16.0), (10.0, 11.0), 13.0, 16.0, 0.0),
        ("CollapseTower_2", (29.0, -25.0), (11.0, 12.0), 15.0, 19.0, 0.12),
    ]
    for index, (name, (x, y), (sx, sy), lower_h, upper_h, delay) in enumerate(collapse_specs, start=1):
        add_cube(f"{name}_Lower", (x, y, lower_h * 0.5), (sx, sy, lower_h), concrete_dark)
        pivot = bpy.data.objects.new(f"{name}_Pivot", None)
        pivot.location = (x - sx * 0.5, y, lower_h)
        bpy.context.collection.objects.link(pivot)
        upper = add_cube(
            f"{name}_Upper",
            (x, y, lower_h + upper_h * 0.5),
            (sx, sy, upper_h),
            concrete,
        )
        upper.parent = pivot
        upper.matrix_parent_inverse = pivot.matrix_world.inverted()
        for window_z in (3.0, 6.5, 10.0):
            if window_z < lower_h - 0.8:
                add_cube(
                    f"{name}_LowerWindow_{window_z:.1f}",
                    (x, y - sy * 0.51, window_z),
                    (sx * 0.78, 0.2, 1.2),
                    window,
                )
        for upper_index, local_z in enumerate((3.0, 7.0, 11.0, 15.0), start=1):
            if local_z < upper_h - 0.7:
                upper_window = add_cube(
                    f"{name}_UpperWindow_{upper_index}",
                    (x, y - sy * 0.51, lower_h + local_z),
                    (sx * 0.78, 0.2, 1.25),
                    window,
                )
                upper_window.parent = pivot
                upper_window.matrix_parent_inverse = pivot.matrix_world.inverted()
        kerf = add_cube(
            f"{name}_HotKerf",
            (x, y - sy * 0.51, lower_h),
            (sx * 1.05, 0.28, 0.42),
            red_glow,
            rotation=(0.0, math.radians(5.0 + index * 2.0), 0.0),
        )
        animate_appears(kerf, 83)

        start_fall = 116 + int(delay * FPS)
        pivot.rotation_euler = (0.0, 0.0, 0.0)
        pivot.location = (x - sx * 0.5, y, lower_h)
        pivot.keyframe_insert(data_path="rotation_euler", frame=start_fall)
        pivot.keyframe_insert(data_path="location", frame=start_fall)
        pivot.rotation_euler = (math.radians(5.0), math.radians(72.0), math.radians(8.0))
        pivot.location = (x - sx * 0.5 + 4.5, y - 1.0, lower_h - 7.5)
        pivot.keyframe_insert(data_path="rotation_euler", frame=150 + index * 2)
        pivot.keyframe_insert(data_path="location", frame=150 + index * 2)

        rubble = add_cube(
            f"{name}_Rubble",
            (x + 8.0, y, 1.2),
            (sx * 1.4, sy * 1.1, 2.4),
            concrete_dark,
            rotation=(0.0, math.radians(12.0), math.radians(8.0)),
        )
        animate_appears(rubble, 148 + index * 2)

        for blast_index in range(3):
            blast_frame = 97 + index * 3 + blast_index * 4
            blast = add_uv_sphere(
                f"{name}_Explosion_{blast_index + 1}",
                (x - sx * 0.25 + blast_index * sx * 0.25, y - sy * 0.58, lower_h + blast_index * 0.35),
                (1.7, 1.0, 1.5),
                orange_glow,
                segments=12,
                rings=6,
            )
            animate_visible(blast, blast_frame, min(115, blast_frame + 5))

        smoke = add_uv_sphere(
            f"{name}_Smoke",
            (x + 3.5, y - 1.0, 7.0),
            (2.4, 1.8, 2.4),
            smoke_mat,
            segments=12,
            rings=6,
        )
        animate_appears(smoke, 124 + index * 2)
        smoke.scale = (1.0, 1.0, 1.0)
        smoke.keyframe_insert(data_path="scale", frame=126 + index * 2)
        smoke.scale = (1.8, 1.6, 1.7)
        smoke.keyframe_insert(data_path="scale", frame=176)

    # Cinematic blockout lighting.
    bpy.ops.object.light_add(type="SUN", location=(0.0, 0.0, 60.0))
    sun = bpy.context.object
    sun.name = "MoonKey"
    sun.data.energy = 2.0
    sun.rotation_euler = (math.radians(30.0), math.radians(-18.0), math.radians(25.0))
    bpy.ops.object.light_add(type="AREA", location=(0.0, -8.0, 32.0))
    area = bpy.context.object
    area.name = "CityFill"
    area.data.energy = 1400.0
    area.data.shape = "DISK"
    area.data.size = 32.0
    area.data.color = (0.24, 0.42, 0.72)
    bpy.ops.object.light_add(type="AREA", location=(22.0, -23.0, 38.0))
    collapse_fill = bpy.context.object
    collapse_fill.name = "CollapseFill"
    collapse_fill.data.energy = 2600.0
    collapse_fill.data.shape = "DISK"
    collapse_fill.data.size = 28.0
    collapse_fill.data.color = (0.46, 0.55, 0.72)

    # Camera plan mirrors the battle timing in script.md.
    cam_01, rig_01, _ = add_camera("CAM_01_SCREEN_A_100MM", (0.0, 12.0, 16.5), (0.0, 24.0, 16.5), 100.0)
    rig_01.location = (0.0, 10.0, 16.5)
    rig_01.keyframe_insert(data_path="location", frame=1)
    rig_01.location = (0.0, 14.0, 16.5)
    rig_01.keyframe_insert(data_path="location", frame=10)

    cam_02, _, _ = add_camera("CAM_02_IMPACT_35MM", (-13.0, -12.0, 2.2), (0.0, 0.0, 14.0), 35.0, roll_degrees=9.0)
    cam_03, _, _ = add_camera("CAM_03_TENTACLE_24MM", (15.0, 7.0, 4.0), (0.0, 20.0, 11.0), 24.0)
    cam_04, rig_04, target_04 = add_camera("CAM_04_OVERHEAD_18MM", (0.0, -8.0, 70.0), (0.0, 4.0, 0.0), 18.0)
    rig_04.location = (3.0, -12.0, 70.0)
    rig_04.keyframe_insert(data_path="location", frame=56)
    rig_04.location = (-5.0, -1.0, 68.0)
    rig_04.keyframe_insert(data_path="location", frame=82)
    target_04.location = (0.0, 5.0, 0.0)

    cam_05, _, _ = add_camera("CAM_05_KERF_135MM", (50.0, -55.0, 21.0), (24.0, -31.0, 14.0), 85.0)
    cam_06, _, _ = add_camera("CAM_06_EXPLOSION_35MM", (38.0, -53.0, 17.0), (24.0, -30.5, 13.0), 45.0, roll_degrees=-7.0)
    cam_07, rig_07, target_07 = add_camera("CAM_07_COLLAPSE_50MM", (54.0, -52.0, 42.0), (22.0, -27.0, 13.0), 50.0)
    rig_07.location = (54.0, -52.0, 42.0)
    rig_07.keyframe_insert(data_path="location", frame=116)
    rig_07.location = (8.0, -52.0, 28.0)
    rig_07.keyframe_insert(data_path="location", frame=154)
    target_07.location = (22.0, -27.0, 13.0)

    cam_08, rig_08, target_08 = add_camera("CAM_08_FINAL_HIT_70MM", (-5.0, -34.0, 8.0), (-8.0, 0.0, 8.0), 50.0)
    rig_08.location = (-5.0, -34.0, 8.0)
    rig_08.keyframe_insert(data_path="location", frame=155)
    rig_08.location = (-5.0, -11.0, 2.6)
    rig_08.keyframe_insert(data_path="location", frame=176)
    target_08.location = (-8.0, 0.0, 8.0)
    target_08.keyframe_insert(data_path="location", frame=155)
    target_08.location = (-8.0, 0.0, 1.0)
    target_08.keyframe_insert(data_path="location", frame=176)

    add_marker(scene, "15.4s_BEAM_PUNCH_IN", 1, cam_01)
    add_marker(scene, "15.8s_IMPACT", 11, cam_02)
    add_marker(scene, "16.5s_LOWER_TENTACLE_SMASH", 27, cam_03)
    add_marker(scene, "17.7s_HELICOPTER_OVERHEAD", 56, cam_04)
    add_marker(scene, "18.8s_HOT_KERF", 83, cam_05)
    add_marker(scene, "19.4s_DELAYED_EXPLOSIONS", 97, cam_06)
    add_marker(scene, "20.2s_GRAVITY_COLLAPSE", 116, cam_07)
    add_marker(scene, "21.8s_FINAL_HIT_AND_SHRINK", 155, cam_08)
    scene.camera = cam_01

    return scene


def render_storyboard(scene: bpy.types.Scene) -> None:
    STORYBOARD_DIR.mkdir(parents=True, exist_ok=True)
    for existing_frame in STORYBOARD_DIR.glob("*.png"):
        existing_frame.unlink()
    storyboard_frames = [
        (1, "01_15_4s_beam_punch_in.png"),
        (11, "02_15_8s_impact.png"),
        (27, "03_16_5s_lower_tentacle_smash.png"),
        (56, "04_17_7s_helicopter_overhead.png"),
        (83, "05_18_8s_hot_kerf.png"),
        (101, "06_19_6s_delayed_explosions.png"),
        (132, "07_20_9s_gravity_collapse.png"),
        (176, "08_22_7s_normal_size.png"),
    ]
    scene.render.image_settings.file_format = "PNG"
    for frame, filename in storyboard_frames:
        scene.frame_set(frame)
        scene.render.filepath = str(STORYBOARD_DIR / filename)
        bpy.ops.render.render(write_still=True)


def restore_animation_settings(scene: bpy.types.Scene) -> None:
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(RENDER_DIR / "frame_")
    scene.frame_set(1)


def main() -> None:
    scene = build_scene()
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))
    render_storyboard(scene)
    restore_animation_settings(scene)
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))
    print(f"PREVIS_BLEND={BLEND_PATH}")
    print(f"PREVIS_VIDEO={VIDEO_PATH}.mp4")
    print(f"STORYBOARD_DIR={STORYBOARD_DIR}")


if __name__ == "__main__":
    main()
