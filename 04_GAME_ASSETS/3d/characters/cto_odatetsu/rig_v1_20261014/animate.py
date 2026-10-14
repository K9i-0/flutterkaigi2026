"""Retarget the canonical Fukugyun v3's 20 clips onto CTO Odatetsu.

Run after build.py with Blender 5.1. This only reads the reference character;
all generated files remain in this CTO Odatetsu directory. No API is used.
"""
from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path
import struct
import sys

import bpy
from mathutils import Matrix
import numpy as np

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]
sys.path.insert(0, str(ROOT / "tools"))
from build_humanoid_motion import clear_pose, use_action

FPS = 30
SOURCE = ROOT / "04_GAME_ASSETS/3d/characters/fukuchan/web_v3_20260917/fukuchan.glb"
INPUT = HERE / "cto_odatetsu_rig.blend"
OUTPUT_BLEND = HERE / "cto_odatetsu_animated.blend"
OUTPUT_GLB = HERE / "cto_odatetsu_rig.glb"
LOOPING = {
    "Idle", "Walk", "Run", "Aim", "AimShotgun",
    "DanceStep", "DanceDisco", "DanceVictory",
}
EXPECTED = LOOPING | {
    "ReloadHandgun", "ReloadShotgun", "Hit", "Evade", "Kick", "Climb",
    "Vault", "Struggle", "BreakFree", "Greeting", "GyunGyun", "GyunGyunPose",
}
DIGITS = ("Thumb", "Index", "Middle", "Ring", "Little")


def glb_json(path):
    data = path.read_bytes()
    magic, version, length = struct.unpack_from("<4sII", data)
    assert magic == b"glTF" and version == 2 and length == len(data)
    size, kind = struct.unpack_from("<II", data, 12)
    assert kind == 0x4E4F534A
    return json.loads(data[20:20 + size])


def clip_seconds(gltf, clip):
    times = [gltf["accessors"][s["input"]] for s in clip["samplers"]]
    assert all(abs(a.get("min", [0])[0]) < 1e-6 for a in times)
    return max(a["max"][0] for a in times)


class SoleSampler:
    """Exact LBS evaluation of sole vertices, including all retained weights."""

    def __init__(self, rig, meshes, rest, names):
        self.names = names
        indices = {name: i for i, name in enumerate(names)}
        points, joints, weights = [], [], []
        for mesh in meshes:
            for vertex in mesh.data.vertices:
                p = mesh.matrix_world @ vertex.co
                influences = [
                    (mesh.vertex_groups[g.group].name, g.weight)
                    for g in vertex.groups
                    if mesh.vertex_groups[g.group].name in indices and g.weight > 0
                ]
                foot_weight = sum(w for n, w in influences if n.endswith(("Foot", "ToeBase")))
                if p.z >= .06 or foot_weight <= .6:
                    continue
                assert len(influences) <= 4, "Input must already have at most four influences"
                row_j = [indices[n] for n, _ in influences]
                row_w = [w for _, w in influences]
                points.append([*p, 1.])
                joints.append(row_j + [0] * (4 - len(row_j)))
                weights.append(row_w + [0.] * (4 - len(row_w)))
        assert points, "No actual shoe-sole vertices available for floor correction"
        self.points = np.asarray(points, dtype=np.float64)
        self.joints = np.asarray(joints, dtype=np.int32)
        self.weights = np.asarray(weights, dtype=np.float64)
        self.inverse = np.asarray([rest[n].inverted() for n in names], dtype=np.float64)

    def floor(self, pose):
        skin = np.asarray([pose[n] for n in self.names], dtype=np.float64) @ self.inverse
        z = np.einsum("nkij,nj->nki", skin[self.joints], self.points)[:, :, 2]
        return float(np.min(np.sum(z * self.weights, axis=1)))


def read_source():
    gltf = glb_json(SOURCE)
    clips = {c["name"]: clip_seconds(gltf, c) for c in gltf["animations"]}
    assert set(clips) == EXPECTED and len(clips) == 20, sorted(clips)
    previous_objects = set(bpy.data.objects)
    previous_actions = set(bpy.data.actions)
    bpy.ops.import_scene.gltf(filepath=str(SOURCE))
    imported = set(bpy.data.objects) - previous_objects
    rigs = [o for o in imported if o.type == "ARMATURE"]
    assert len(rigs) == 1
    rig = rigs[0]
    meshes = [o for o in imported if o.type == "MESH"]
    imported_actions = set(bpy.data.actions) - previous_actions
    actions = {a.name: a for a in imported_actions}
    assert set(clips) <= set(actions), sorted(actions)
    rig.animation_data_clear()
    clear_pose(rig)
    bind = rig.matrix_world.copy()
    names = [b.name for b in rig.data.bones]
    assert len(names) == 54
    rest = {b.name: bind @ b.matrix_local for b in rig.data.bones}
    parents = {b.name: b.parent.name if b.parent else None for b in rig.data.bones}
    source_local = {
        n: rest[parents[n]].inverted() @ m if parents[n] else m.copy()
        for n, m in rest.items()
    }
    soles = SoleSampler(rig, meshes, rest, names)
    records = {}
    bpy.context.scene.render.fps = FPS
    for name, duration in clips.items():
        frame_count = round(duration * FPS)
        assert abs(frame_count / FPS - duration) < 1e-6, (name, duration)
        use_action(rig, None)
        clear_pose(rig)
        rig.matrix_world = bind.copy()
        action = actions[name]
        use_action(rig, action)
        start, end = map(float, action.frame_range)
        assert abs((end - start) / FPS - duration) < 1e-5, (name, start, end)
        samples, floors = [], []
        for frame in range(frame_count + 1):
            time = start + (end - start) * frame / frame_count
            bpy.context.scene.frame_set(math.floor(time), subframe=time % 1)
            sample = {b.name: rig.matrix_world @ b.matrix for b in rig.pose.bones}
            samples.append(sample)
            floors.append(soles.floor(sample))
        records[name] = {
            "seconds": duration, "frames": frame_count, "samples": samples, "floors": floors,
        }
        print("SOURCE_SAMPLED", name, frame_count + 1, flush=True)
    for obj in imported:
        bpy.data.objects.remove(obj, do_unlink=True)
    for action in imported_actions:
        bpy.data.actions.remove(action)
    return rest, source_local, parents, records


def leg_length(rest):
    return sum((rest[a].translation - rest[b].translation).length for a, b in [
        ("LeftUpLeg", "LeftLeg"), ("LeftLeg", "LeftFoot"),
    ])


def parent_order(rig):
    ordered = []

    def append(bone):
        ordered.append(bone.name)
        for child in bone.children:
            append(child)

    for bone in rig.data.bones:
        if bone.parent is None:
            append(bone)
    return ordered


def write_action(rig, name, rows, frame_count):
    """Write sampled basis transforms without repeated depsgraph evaluations."""
    old = bpy.data.actions.get(name)
    if old:
        bpy.data.actions.remove(old)
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    action.use_frame_range = True
    action.frame_start, action.frame_end = 0, frame_count
    action["sourceClip"] = name
    action["motionRevision"] = "cto-rest-aware-v1-20261014"
    slot = action.slots.new(id_type="OBJECT", name=rig.name)
    layer = action.layers.new("Rest-aware retarget")
    strip = layer.strips.new(type="KEYFRAME")
    bag = strip.channelbag(slot, ensure=True)
    frames = np.arange(frame_count + 1, dtype=np.float64)
    for name, values in rows.items():
        values = np.asarray(values, dtype=np.float64)
        assert np.isfinite(values).all()
        for attribute, offset, dimensions in [
            ("location", 0, 3), ("rotation_quaternion", 3, 4), ("scale", 7, 3),
        ]:
            for component in range(dimensions):
                curve = bag.fcurves.new(
                    data_path=f'pose.bones["{name}"].{attribute}', index=component,
                )
                curve.keyframe_points.add(frame_count + 1)
                curve.keyframe_points.foreach_set(
                    "co", np.column_stack((frames, values[:, offset + component])).ravel(),
                )
                for point in curve.keyframe_points:
                    point.interpolation = "LINEAR"
    return action


def main():
    assert INPUT.exists(), f"Run build.py first: {INPUT}"
    bpy.ops.wm.open_mainfile(filepath=str(INPUT))
    scene = bpy.context.scene
    scene.render.fps = FPS
    rigs = [o for o in scene.objects if o.type == "ARMATURE"]
    assert len(rigs) == 1
    rig = rigs[0]
    meshes = [o for o in scene.objects if o.type == "MESH"]
    assert len(meshes) == 1
    assert max(abs(rig.matrix_world[i][j] - (1 if i == j else 0))
               for i in range(4) for j in range(4)) < 1e-6, "Expected identity rig matrix"
    rig.animation_data_clear()
    clear_pose(rig)
    # build.py produces a static bind asset. Do not accidentally retain diagnostic clips.
    assert not bpy.data.actions, "Unexpected pre-existing actions in the bind file"
    rest = {b.name: b.matrix_local.copy() for b in rig.data.bones}
    ordered = parent_order(rig)
    assert len(ordered) == 54 and len(set(ordered)) == 54
    parents = {b.name: b.parent.name if b.parent else None for b in rig.data.bones}
    local = {
        n: rest[parents[n]].inverted() @ m if parents[n] else m.copy()
        for n, m in rest.items()
    }
    original_geometry = [tuple(v.co) for v in meshes[0].data.vertices]
    original_uv = [tuple(v.uv) for v in meshes[0].data.uv_layers.active.data]
    material_names = [m.name for m in meshes[0].data.materials]
    source_rest, source_local, source_parents, records = read_source()
    assert set(source_rest) == set(rest), (set(source_rest) - set(rest), set(rest) - set(source_rest))
    assert parents == source_parents, "Compatibility requires the same anatomical hierarchy"
    scale = leg_length(rest) / leg_length(source_rest)
    soles = SoleSampler(rig, meshes, rest, ordered)
    children = {
        side + bone: side + child
        for side in ("Left", "Right")
        for bone, child in [
            ("Shoulder", "Arm"), ("Arm", "ForeArm"), ("ForeArm", "Hand"),
            ("UpLeg", "Leg"), ("Leg", "Foot"), ("Foot", "ToeBase"),
        ]
    }
    corrections = {}
    for name in ordered:
        target_rotation = rest[name].to_quaternion().to_matrix()
        if name in children:
            child = children[name]
            target_axis = rest[child].translation - rest[name].translation
            source_axis = source_rest[child].translation - source_rest[name].translation
            target_rotation = target_axis.rotation_difference(source_axis).to_matrix() @ target_rotation
        elif name.endswith("Hand"):
            # Align forearm swing only. Keep the target palm's rest roll; do not
            # copy an anatomical palm normal or add an arbitrary 180-degree turn.
            fore = name.replace("Hand", "ForeArm")
            target_axis = rest[name].translation - rest[fore].translation
            source_axis = source_rest[name].translation - source_rest[fore].translation
            target_rotation = target_axis.rotation_difference(source_axis).to_matrix() @ target_rotation
        corrections[name] = source_rest[name].to_quaternion().to_matrix().inverted() @ target_rotation

    digest = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    report = []
    for name, spec in records.items():
        rows = {n: [] for n in ordered}
        previous = {}
        floor_deltas, output_floors = [], []
        max_length_error = 0.
        for sample_index, sample in enumerate(spec["samples"]):
            posed = {}
            for n in ordered:
                parent = parents[n]
                if n == "Root":
                    posed[n] = rest[n].copy()
                    continue
                location = posed[parent] @ local[n].translation if parent else rest[n].translation.copy()
                if n == "Hips":
                    location = rest[n].translation + (sample[n].translation - source_rest[n].translation) * scale
                if n == "PropSocket.R":
                    # Socket is fixed in the target palm's own bind coordinates.
                    rotation = posed[parent].to_quaternion().to_matrix() @ local[n].to_quaternion().to_matrix()
                elif n.startswith(DIGITS) or n.endswith("ToeBase"):
                    # Transport flexion through each local bind frame. This keeps
                    # fingers attached to the target palm instead of pulling their
                    # absolute orientation back toward the reference character.
                    source_pose_local = sample[parent].inverted() @ sample[n]
                    delta = source_local[n].to_quaternion().inverted() @ source_pose_local.to_quaternion()
                    rotation = (posed[parent].to_quaternion() @ local[n].to_quaternion() @ delta).to_matrix()
                else:
                    rotation = sample[n].to_quaternion().to_matrix() @ corrections[n]
                posed[n] = Matrix.Translation(location) @ rotation.to_4x4()
                if parent and n != "Hips":
                    length_error = abs((location - posed[parent].translation).length - local[n].translation.length)
                    max_length_error = max(max_length_error, length_error)
            # Keep source airborne clearance (Vault/Climb/etc.), while eliminating
            # reference floor penetration. All bones below Root move together.
            desired_floor = max(.003, spec["floors"][sample_index] * scale)
            delta_z = desired_floor - soles.floor(posed)
            floor_deltas.append(delta_z)
            for n in ordered:
                if n != "Root":
                    posed[n].translation.z += delta_z
            output_floors.append(soles.floor(posed))
            for n in ordered:
                parent = parents[n]
                basis = local[n].inverted() @ (posed[parent].inverted() @ posed[n] if parent else posed[n])
                location, quaternion, bone_scale = basis.decompose()
                if n in previous and quaternion.dot(previous[n]) < 0:
                    quaternion.negate()
                previous[n] = quaternion.copy()
                assert max(abs(value - 1.) for value in bone_scale) < 1e-5, (name, n, bone_scale)
                rows[n].append([*location, *quaternion, *bone_scale])
        assert max_length_error < 2e-6, (name, max_length_error)
        write_action(rig, name, rows, spec["frames"])
        report.append({
            "name": name,
            "seconds": spec["seconds"],
            "fps": FPS,
            "sampleCount": spec["frames"] + 1,
            "loop": name in LOOPING,
            "source": str(SOURCE.relative_to(ROOT)),
            "sourceClip": name,
            "sourceGlbSha256": digest,
            "sourceProvenance": "Canonical Fukugyun v3; existing Mixamo, CC0 and authored motions remain mixed, not collectively CC0.",
            "retargetMethod": "World rest-aware rotations with minimum limb swing; parent-local finger flexion; target bone lengths retained.",
            "palmPolicy": "Target rest palm roll retained; no fixed 180-degree wrist correction.",
            "retargetLegScale": scale,
            "floorPolicy": "Preserve scaled source sole clearance, with a minimum 3 mm floor gap.",
            "floorCorrectionRangeM": [min(floor_deltas), max(floor_deltas)],
            "sourceSoleRangeM": [min(spec["floors"]), max(spec["floors"])],
            "targetSoleRangeM": [min(output_floors), max(output_floors)],
            "maxBoneLengthErrorM": max_length_error,
        })
        print("RETARGETED", name, spec["frames"] + 1, flush=True)
    use_action(rig, None)
    clear_pose(rig)
    scene.frame_set(0)
    assert original_geometry == [tuple(v.co) for v in meshes[0].data.vertices]
    assert original_uv == [tuple(v.uv) for v in meshes[0].data.uv_layers.active.data]
    assert material_names == [m.name for m in meshes[0].data.materials]
    assert {a.name for a in bpy.data.actions} == EXPECTED
    bpy.ops.object.select_all(action="DESELECT")
    for obj in [rig, *meshes]:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT_BLEND))
    bpy.ops.export_scene.gltf(
        filepath=str(OUTPUT_GLB), export_format="GLB", use_selection=True,
        export_animations=True, export_animation_mode="ACTIONS",
        export_frame_range=False, export_anim_slide_to_zero=True,
        export_anim_single_armature=True, export_skins=True,
        export_all_influences=False, export_def_bones=False,
        export_force_sampling=True, export_optimize_animation_size=True,
        export_morph_animation=False, export_extras=True,
    )
    exported = glb_json(OUTPUT_GLB)
    output_clips = {c["name"]: clip_seconds(exported, c) for c in exported["animations"]}
    assert set(output_clips) == EXPECTED and len(output_clips) == 20
    assert len(exported["skins"]) == 1 and len(exported["skins"][0]["joints"]) == 54
    for row in report:
        assert abs(output_clips[row["name"]] - row["seconds"]) < 1e-5
    (HERE / "motions.json").write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n")
    print("CTO_ANIMATION_DONE", len(output_clips), hashlib.sha256(OUTPUT_GLB.read_bytes()).hexdigest(), flush=True)


if __name__ == "__main__":
    main()
