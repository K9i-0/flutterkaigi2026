"""Check the additive pose and compare Blender with independent glTF skinning."""
import importlib.util
import json
from pathlib import Path
import sys

import bpy
import numpy as np

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('rig_validation', HERE.parent / 'rig_v1_20261014/validate.py')
validation = importlib.util.module_from_spec(spec)
spec.loader.exec_module(validation)
old = validation.Glb(HERE.parent / 'rig_v1_20261014/cto_odatetsu_rig.glb')
new = validation.Glb(HERE / 'cto_odatetsu_camera.glb')
assert new.bin[:len(old.bin)] == old.bin
for key in ('meshes', 'skins', 'materials', 'images', 'textures', 'nodes', 'scenes'):
    assert old.doc.get(key) == new.doc.get(key), key
assert new.doc['accessors'][:len(old.doc['accessors'])] == old.doc['accessors']
assert new.doc['bufferViews'][:len(old.doc['bufferViews'])] == old.doc['bufferViews']
assert new.doc['animations'][:20] == old.doc['animations']
durations = new.clips()
assert set(durations) == set(old.clips()) | {'CameraCarry'}
assert durations['CameraCarry'] == 1
assert len(new.doc['skins'][0]['joints']) == 54
old_eval, new_eval = validation.SkinEvaluator(old), validation.SkinEvaluator(new)
comparisons = []
for clip, duration in old.clips().items():
    for phase in (0, .31, .83):
        a = old_eval.evaluate(clip, duration * phase)
        b = new_eval.evaluate(clip, duration * phase)
        assert np.array_equal(a, b), (clip, phase)
    comparisons.append({'clip': clip, 'phases': [0, .31, .83], 'maxVertexDifferenceM': 0})
pose = new_eval.evaluate('CameraCarry', .5)
assert np.isfinite(pose).all()
assert np.max(np.abs(pose)) < 2
new_clip = next(c for c in new.doc['animations'] if c['name'] == 'CameraCarry')
assert all(np.array_equal(new.accessor(s['output'])[0], new.accessor(s['output'])[1]) for s in new_clip['samplers'])
static_drift = max(float(np.linalg.norm(pose-new_eval.evaluate('CameraCarry', t), axis=1).max()) for t in (0, 1))
assert static_drift < 1e-6, static_drift

def current_corners():
    mesh = next(o for o in bpy.context.scene.objects if o.type == 'MESH' and any(m.type == 'ARMATURE' for m in o.modifiers))
    dg = bpy.context.evaluated_depsgraph_get()
    evaluated = mesh.evaluated_get(dg)
    points = np.array([evaluated.matrix_world @ v.co for v in evaluated.data.vertices], dtype=float)
    corners = np.array([i for p in evaluated.data.polygons for i in p.vertices], dtype=int)
    return points[corners]

bpy.ops.wm.open_mainfile(filepath=str(HERE / 'camera_pose.blend'))
bpy.context.view_layer.update()
authored = current_corners()
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps = 30
bpy.ops.import_scene.gltf(filepath=str(HERE / 'cto_odatetsu_camera.glb'))
roundtrip = validation.scene_sample('CameraCarry', .5)
independent = pose[new_eval.tris.ravel()][:, [0, 2, 1]] * np.array([1, -1, 1])
roundtrip_error = float(np.max(np.linalg.norm(roundtrip-authored, axis=1)))
independent_error = float(np.max(np.linalg.norm(independent-roundtrip, axis=1)))
assert roundtrip_error < .00002, roundtrip_error
assert independent_error < .00002, independent_error
attachment = json.loads((HERE / 'attachment.json').read_text())
grip = attachment['rightGripPose']
assert len(grip) == 15
assert len({v['node'] for v in grip}) == 15
assert all(abs(np.linalg.norm(v['quaternion'])-1) < 1e-6 for v in grip)
assert all(v['node'].endswith('.R') for v in grip)
assert len(attachment['socketToGrip']) == 16 and np.isfinite(attachment['socketToGrip']).all()
report = {
    'passed': True, 'sourceSha256': old.sha256, 'outputSha256': new.sha256,
    'boneCount': 54, 'clipCount': 21, 'newClip': 'CameraCarry',
    'originalBinaryPrefixUnchanged': True, 'originalAccessorAndBufferViewsUnchanged': True,
    'originalGeometrySkinMaterialsRestNodesUnchanged': True,
    'original20AnimationDefinitionsUnchanged': True,
    'originalMotionComparisons': comparisons,
    'newPose': {'finite': True, 'staticEndpointKeyframesIdentical': True, 'sampledStaticPoseMaxDriftM': static_drift,
                'boundsMin': pose.min(axis=0).tolist(), 'boundsMax': pose.max(axis=0).tolist(),
                'authoredVsReimportMaxVertexDifferenceM': roundtrip_error,
                'independentGlTfVsBlenderMaxVertexDifferenceM': independent_error},
    'rightGripBoneCount': len(grip),
    'limits': 'Camera clearance and visual hand contact are reviewed separately in contact_review.json and pose_review.json. Numeric skin checks alone do not certify contact or artistic quality.'
}
(HERE / 'validation.json').write_text(json.dumps(report, indent=2) + '\n')
print('CAMERA_CARRY_VALIDATED', new.sha256, roundtrip_error, independent_error, flush=True)
