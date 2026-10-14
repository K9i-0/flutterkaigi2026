"""Independently audit the exported CTO Odatetsu GLB without modifying assets.

Run with Blender 5.1: blender -b --factory-startup --python validate.py.
Numerical checks certify export/skin behavior, not anatomical or artistic quality.
"""
from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path
import struct

import bpy
import numpy as np

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]
RIG = HERE / 'cto_odatetsu_rig.glb'
STATIC = HERE.parent / 'finish_20261014/cto_odatetsu_static.glb'
SOURCE = ROOT / '04_GAME_ASSETS/3d/characters/fukuchan/web_v3_20260917/fukuchan.glb'
EXPECTED = {
    'Idle', 'Walk', 'Run', 'Aim', 'AimShotgun', 'ReloadHandgun',
    'ReloadShotgun', 'Hit', 'Evade', 'Kick', 'Climb', 'Vault',
    'Struggle', 'BreakFree', 'Greeting', 'GyunGyun', 'GyunGyunPose',
    'DanceStep', 'DanceDisco', 'DanceVictory',
}
DTYPES = {5120:'i1', 5121:'u1', 5122:'<i2', 5123:'<u2', 5125:'<u4', 5126:'<f4'}
DIMENSIONS = {'SCALAR':1, 'VEC2':2, 'VEC3':3, 'VEC4':4, 'MAT4':16}


class Glb:
    def __init__(self, path):
        self.path = path
        self.data = path.read_bytes()
        assert struct.unpack_from('<4sII', self.data) == (b'glTF', 2, len(self.data))
        chunks = {}
        offset = 12
        while offset < len(self.data):
            length, kind = struct.unpack_from('<II', self.data, offset)
            chunks[kind] = self.data[offset + 8:offset + 8 + length]
            offset += 8 + length
        self.doc = json.loads(chunks[0x4E4F534A])
        self.bin = chunks[0x004E4942]
        self.sha256 = hashlib.sha256(self.data).hexdigest()

    def accessor(self, index):
        a = self.doc['accessors'][index]
        assert 'sparse' not in a
        v = self.doc['bufferViews'][a['bufferView']]
        dtype = np.dtype(DTYPES[a['componentType']])
        dims = DIMENSIONS[a['type']]
        offset = v.get('byteOffset', 0) + a.get('byteOffset', 0)
        value = np.ndarray(
            (a['count'], dims), dtype=dtype, buffer=self.bin, offset=offset,
            strides=(v.get('byteStride', dims * dtype.itemsize), dtype.itemsize),
        ).copy()
        if a.get('normalized'):
            maximum = np.iinfo(dtype).max
            value = np.maximum(-1., value.astype(np.float64) / maximum)
        return value

    def image(self, index):
        img = self.doc['images'][index]
        view = self.doc['bufferViews'][img['bufferView']]
        start = view.get('byteOffset', 0)
        return self.bin[start:start + view['byteLength']]

    def primitive(self):
        assert len(self.doc['meshes']) == 1
        primitives = self.doc['meshes'][0]['primitives']
        assert len(primitives) == 1 and primitives[0].get('mode', 4) == 4
        p = primitives[0]
        return {k:self.accessor(v) for k,v in p['attributes'].items()}, self.accessor(p['indices']).ravel().reshape(-1,3)

    def clips(self):
        result = {}
        for clip in self.doc.get('animations', []):
            times = [self.accessor(s['input']).ravel() for s in clip['samplers']]
            assert all(np.isfinite(t).all() and len(t) and np.all(np.diff(t) > 0) for t in times)
            result[clip['name']] = max(float(t[-1]) for t in times)
            assert min(float(t[0]) for t in times) == 0
        return result


def quaternion_matrix(q):
    x,y,z,w = q / np.linalg.norm(q)
    return np.array([
        [1-2*y*y-2*z*z, 2*x*y-2*z*w, 2*x*z+2*y*w],
        [2*x*y+2*z*w, 1-2*x*x-2*z*z, 2*y*z-2*x*w],
        [2*x*z-2*y*w, 2*y*z+2*x*w, 1-2*x*x-2*y*y],
    ])


def interpolate(t, values, at, mode, rotation=False):
    if at <= t[0]: return values[0]
    if at >= t[-1]: return values[-1]
    i = np.searchsorted(t, at, side='right') - 1
    if mode == 'STEP': return values[i]
    assert mode == 'LINEAR', mode
    f = (at - t[i]) / (t[i+1] - t[i])
    a, b = values[i].astype(np.float64), values[i+1].astype(np.float64)
    if rotation:
        dot = np.dot(a,b)
        if dot < 0: b, dot = -b, -dot
        if dot > .9995:
            q = a * (1-f) + b * f
            return q / np.linalg.norm(q)
        angle = math.acos(np.clip(dot, -1, 1))
        return (math.sin((1-f)*angle)*a + math.sin(f*angle)*b) / math.sin(angle)
    return a * (1-f) + b * f


class SkinEvaluator:
    """Independent raw glTF interpolation and linear blend skinning."""
    def __init__(self, glb):
        self.glb = glb
        self.attributes, self.tris = glb.primitive()
        self.p = np.column_stack((self.attributes['POSITION'], np.ones(len(self.attributes['POSITION']))))
        self.j = self.attributes['JOINTS_0'].astype(int)
        self.w = self.attributes['WEIGHTS_0'].astype(float)
        self.skin = glb.doc['skins'][0]
        self.inverse = glb.accessor(self.skin['inverseBindMatrices']).reshape(-1,4,4).transpose(0,2,1)
        self.parents = {}
        for i,node in enumerate(glb.doc['nodes']):
            for child in node.get('children', []): self.parents[child] = i
        self.clips = {c['name']: c for c in glb.doc['animations']}

    def evaluate(self, clip_name=None, seconds=0):
        nodes = self.glb.doc['nodes']
        trs = {i:{'translation':np.array(n.get('translation', [0,0,0]), dtype=float),
                  'rotation':np.array(n.get('rotation', [0,0,0,1]), dtype=float),
                  'scale':np.array(n.get('scale', [1,1,1]), dtype=float)} for i,n in enumerate(nodes)}
        if clip_name:
            clip = self.clips[clip_name]
            for channel in clip['channels']:
                sampler = clip['samplers'][channel['sampler']]
                target = channel['target']
                path = target['path']
                assert path in ('translation', 'rotation', 'scale'), path
                times = self.glb.accessor(sampler['input']).ravel()
                values = self.glb.accessor(sampler['output'])
                assert np.isfinite(values).all()
                trs[target['node']][path] = interpolate(times, values, seconds, sampler.get('interpolation','LINEAR'), path == 'rotation')
        world = {}
        def resolve(i):
            if i not in world:
                n = nodes[i]
                if 'matrix' in n:
                    local = np.array(n['matrix']).reshape(4,4).T
                else:
                    transform = trs[i]
                    local = np.eye(4)
                    local[:3,:3] = quaternion_matrix(transform['rotation']) @ np.diag(transform['scale'])
                    local[:3,3] = transform['translation']
                world[i] = resolve(self.parents[i]) @ local if i in self.parents else local
            return world[i]
        matrices = np.stack([resolve(j) for j in self.skin['joints']]) @ self.inverse
        transformed = np.einsum('nkij,nj->nki', matrices[self.j], self.p)
        return (transformed * self.w[:,:,None]).sum(axis=1)[:,:3]


def identity_audit(static, rig):
    old, old_tris = static.primitive()
    new, new_tris = rig.primitive()
    report = {'staticVertexCount':len(old['POSITION']), 'rigVertexCount':len(new['POSITION']), 'triangleCount':len(new_tris), 'comparison':'Indexed triangle corners; export may split vertices for normals or weights.', 'attributes':{}}
    assert old_tris.shape == new_tris.shape
    for name in ('POSITION', 'NORMAL', 'TEXCOORD_0'):
        old_corners, new_corners = old[name][old_tris.ravel()], new[name][new_tris.ravel()]
        exact = np.array_equal(old_corners, new_corners)
        maximum = float(np.max(np.abs(old_corners - new_corners)))
        report['attributes'][name] = {'sameOrder':True, 'bitIdenticalValues':exact, 'maxAbsDifference':maximum}
        if name == 'NORMAL':
            cosine = np.sum(old_corners*new_corners,axis=1) / (np.linalg.norm(old_corners,axis=1)*np.linalg.norm(new_corners,axis=1))
            angles=np.degrees(np.arccos(np.clip(cosine,-1,1)))
            report['attributes'][name]['maxAngularDifferenceDegrees']=float(angles.max())
            report['attributes'][name]['p99AngularDifferenceDegrees']=float(np.percentile(angles,99))
        else:
            assert maximum < 1e-6, (name, maximum)
    report['triangleCornerOrderIdentical'] = True
    report['rawTriangleIndicesIdentical'] = bool(np.array_equal(old_tris,new_tris))
    assert static.doc['materials'] == rig.doc['materials']
    report['materialJsonIdentical'] = True
    assert static.doc.get('textures') == rig.doc.get('textures')
    assert static.doc.get('samplers') == rig.doc.get('samplers')
    assert len(static.doc['images']) == len(rig.doc['images']) == 1
    assert static.image(0) == rig.image(0)
    report['embeddedImageBytesIdentical'] = True
    report['embeddedImageSha256'] = hashlib.sha256(rig.image(0)).hexdigest()
    return report


def weights_audit(glb, attributes):
    assert 'JOINTS_1' not in attributes and 'WEIGHTS_1' not in attributes
    weights = attributes['WEIGHTS_0'].astype(float)
    joints = attributes['JOINTS_0'].astype(int)
    assert weights.shape[1] == joints.shape[1] == 4
    assert np.isfinite(weights).all() and weights.min() >= 0
    assert joints.min() >= 0 and joints.max() < 54
    deviation = float(np.max(np.abs(weights.sum(axis=1)-1)))
    assert deviation < 2e-6, deviation
    dense = np.zeros((len(weights),54))
    for k in range(4): dense[np.arange(len(weights)),joints[:,k]] += weights[:,k]
    positions = attributes['POSITION']
    _, inverse, counts = np.unique(positions, axis=0, return_inverse=True, return_counts=True)
    maximum = 0.
    duplicate_groups = 0
    order = np.argsort(inverse)
    offsets = np.concatenate(([0], np.cumsum(counts)))
    for group in np.flatnonzero(counts > 1):
        w = dense[order[offsets[group]:offsets[group+1]]]
        maximum = max(maximum, float(np.ptp(w,axis=0).max()))
        duplicate_groups += 1
    assert maximum < 2e-6, maximum
    return {'maxInfluences':int((weights>0).sum(axis=1).max()), 'maxWeightSumError':deviation,
            'coincidentPositionGroups':duplicate_groups, 'coincidentPositionVertices':int(counts[counts>1].sum()),
            'maxCoincidentWeightDifference':maximum}


def animation_audit(evaluator, durations):
    attrs = evaluator.attributes
    rest = attrs['POSITION'].astype(float)
    tris = evaluator.tris
    edges = np.unique(np.sort(np.concatenate([tris[:,[0,1]],tris[:,[1,2]],tris[:,[2,0]]]),axis=1),axis=0)
    lengths = np.linalg.norm(rest[edges[:,0]]-rest[edges[:,1]],axis=1)
    valid = lengths > .001
    names = [evaluator.glb.doc['nodes'][n]['name'] for n in evaluator.skin['joints']]
    foot_joints = [i for i,n in enumerate(names) if n.endswith(('Foot','ToeBase'))]
    foot_weight = np.sum(np.where(np.isin(evaluator.j,foot_joints),evaluator.w,0),axis=1)
    sole = (rest[:,1] < .06) & (foot_weight > .6)
    assert sole.any()
    report = []
    for clip,duration in durations.items():
        samples = []
        for phase in [0,.25,.5,.75,1]:
            posed = evaluator.evaluate(clip,duration*phase)
            assert np.isfinite(posed).all(), (clip,phase)
            deformed = np.linalg.norm(posed[edges[:,0]]-posed[edges[:,1]],axis=1)
            ratio = deformed[valid]/lengths[valid]
            extension = deformed-lengths
            row = {'phase':phase, 'seconds':duration*phase, 'finite':True,
                   'boundsMinM':posed.min(axis=0).tolist(), 'boundsMaxM':posed.max(axis=0).tolist(),
                   'minimumSoleYM':float(posed[sole,1].min()),
                   'maxEdgeExtensionM':float(extension.max()),
                   'maxExtensionEdgeBindMidpointM':((rest[edges[int(extension.argmax()),0]]+rest[edges[int(extension.argmax()),1]])/2).tolist(),
                   'p99EdgeExtensionM':float(np.percentile(extension,99)),
                   'maxEdgeLengthRatioOver1mm':float(ratio.max()),
                   'p99EdgeLengthRatioOver1mm':float(np.percentile(ratio,99)),
                   'edgesOver3xAnd20mmExtension':int(((deformed>3*lengths)&(extension>.02)).sum())}
            assert abs(posed).max() < 5., (clip,phase,'exploded bounds')
            assert row['minimumSoleYM'] > -.005, (clip,phase,row['minimumSoleYM'])
            samples.append(row)
        report.append({'name':clip,'seconds':duration,'samples':samples})
        print('VALIDATED_CLIP',clip,flush=True)
    return report


def scene_sample(name, seconds):
    rigs = [o for o in bpy.context.scene.objects if o.type=='ARMATURE']
    meshes = [o for o in bpy.context.scene.objects if o.type=='MESH' and any(m.type=='ARMATURE' for m in o.modifiers)]
    assert len(rigs)==len(meshes)==1
    rig, mesh = rigs[0], meshes[0]
    rig.animation_data_clear()
    for bone in rig.pose.bones:
        bone.rotation_mode='QUATERNION'
        bone.location=(0,0,0); bone.rotation_quaternion=(1,0,0,0); bone.scale=(1,1,1)
    action = bpy.data.actions[name]
    rig.animation_data_create()
    rig.animation_data.action=action
    if action.slots: rig.animation_data.action_slot=action.slots[0]
    frame = float(action.frame_range[0])+seconds*30
    bpy.context.scene.frame_set(math.floor(frame),subframe=frame%1)
    depsgraph=bpy.context.evaluated_depsgraph_get()
    evaluated=mesh.evaluated_get(depsgraph)
    points=np.array([evaluated.matrix_world@v.co for v in evaluated.data.vertices],dtype=float)
    corners=np.array([i for p in evaluated.data.polygons for i in p.vertices],dtype=int)
    assert len(corners)==3*len(evaluated.data.polygons)
    return points[corners]


def blender_roundtrip(evaluator, durations):
    checks = [('Idle',.5),('Walk',.25),('GyunGyun',.5),('DanceVictory',.75)]
    bpy.ops.wm.open_mainfile(filepath=str(HERE/'cto_odatetsu_animated.blend'))
    bpy.context.scene.render.fps=30
    source = {name:scene_sample(name,durations[name]*phase) for name,phase in checks}
    bpy.ops.wm.read_factory_settings(use_empty=True)
    # glTF seconds must be converted to 30 fps by the importer, not its 24 fps default.
    bpy.context.scene.render.fps=30
    bpy.ops.import_scene.gltf(filepath=str(RIG),merge_vertices=False)
    result=[]
    for name,phase in checks:
        seconds=durations[name]*phase
        got=scene_sample(name,seconds)
        expected=source[name]
        assert got.shape==expected.shape,(got.shape,expected.shape)
        # Blender preserves the primitive vertex order in both files.
        differences=np.linalg.norm(got-expected,axis=1)
        direct=evaluator.evaluate(name,seconds)[evaluator.tris.ravel()]
        direct=direct[:,[0,2,1]]*np.array([1,-1,1]) # glTF Y-up to Blender Z-up.
        assert direct.shape==got.shape
        gltf_difference=np.linalg.norm(got-direct,axis=1)
        row={'clip':name,'phase':phase,'seconds':seconds,
             'blendVsReimportMaxVertexDistanceM':float(differences.max()),
             'blendVsReimportP99VertexDistanceM':float(np.percentile(differences,99)),
             'independentGlTfVsBlenderMaxVertexDistanceM':float(gltf_difference.max())}
        assert differences.max()<1e-4,row
        assert gltf_difference.max()<2e-5,row
        result.append(row)
    return result


def main():
    static,rig,source=map(Glb,[STATIC,RIG,SOURCE])
    clips,source_clips=rig.clips(),source.clips()
    assert set(clips)==set(source_clips)==EXPECTED and len(clips)==20
    assert len(rig.doc['skins'])==1 and len(rig.doc['skins'][0]['joints'])==54
    joint_names=[rig.doc['nodes'][i]['name'] for i in rig.doc['skins'][0]['joints']]
    source_names=[source.doc['nodes'][i]['name'] for i in source.doc['skins'][0]['joints']]
    assert set(joint_names)==set(source_names) and len(set(joint_names))==54
    def hierarchy(glb):
        joints=set(glb.doc['skins'][0]['joints'])
        parents={child: i for i,n in enumerate(glb.doc['nodes']) for child in n.get('children',[])}
        return {glb.doc['nodes'][i]['name']: glb.doc['nodes'][parents[i]]['name'] if parents.get(i) in joints else None for i in joints}
    assert hierarchy(rig)==hierarchy(source), 'Bone hierarchy differs from canonical source'
    assert max(abs(clips[k]-source_clips[k]) for k in clips)<1e-5
    evaluator=SkinEvaluator(rig)
    identity=identity_audit(static,rig)
    weights=weights_audit(rig,evaluator.attributes)
    bind_diff=np.linalg.norm(evaluator.evaluate()-evaluator.attributes['POSITION'],axis=1)
    assert bind_diff.max()<2e-6,float(bind_diff.max())
    animation=animation_audit(evaluator,clips)
    (HERE/'validation.json').write_text(json.dumps({'passed':False, 'status':'Blender roundtrip pending', 'rigGlbSha256':rig.sha256, 'staticIdentity':identity, 'weights':weights, 'animations':animation},indent=2)+'\n')
    roundtrip=blender_roundtrip(evaluator,clips)
    assert hashlib.sha256(RIG.read_bytes()).hexdigest()==rig.sha256, 'Rig GLB changed during audit; rerun after build completes'
    report={'passed':True,'fps':30,'coordinateSystem':'glTF right-handed Y-up; distances in metres',
            'scope':'Numerical export and skin audit. Artistic deformation quality requires separate rendered review.',
            'sourceGlbSha256':source.sha256,'staticGlbSha256':static.sha256,'rigGlbSha256':rig.sha256,
            'skinCount':1,'boneCount':54,'boneNamesAndHierarchyMatchSource':True,'animationCount':20,'animationNamesAndDurationsMatchSource':True,
            'staticIdentity':identity,'weights':weights,'bindPoseMaxVertexDistanceM':float(bind_diff.max()),
            'animationPhaseSamples':100,'animations':animation,'blenderRoundtrip':roundtrip,
            'metricNotes':{'edgeRatios':'Edges shorter than 1 mm excluded only from ratio statistics; extension includes every edge.',
                           'floors':'Shoe-sole vertices with bind Y < 0.06 m and Foot/ToeBase influence > 0.6; airborne clearance allowed.',
                           'thresholds':'All sampled coordinates finite and <5 m magnitude; sole above -5 mm. Roundtrip tolerance: 0.1 mm versus authored blend (export interpolation), 0.02 mm versus independent glTF LBS. Edge and normal metrics are diagnostic, not artistic pass criteria.'}}
    (HERE/'validation.json').write_text(json.dumps(report,indent=2,ensure_ascii=False)+'\n')
    print('CTO_RIG_VALIDATED',rig.sha256,flush=True)


if __name__=='__main__':
    main()
