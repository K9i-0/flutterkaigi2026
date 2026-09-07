"""Export VRM 1.0 mappings without changing existing game skinning or clips."""
import hashlib
import json
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / '04_GAME_ASSETS/3d/motion_library'
OUT = ROOT / '04_GAME_ASSETS/vrm/characters'


def read_glb(path):
    data = path.read_bytes()
    length = struct.unpack_from('<I', data, 12)[0]
    return json.loads(data[20:20 + length]), data[20 + length:]


def export(name):
    source = LIB / name / f'{name}.glb'
    gltf, binary_chunk = read_glb(source)
    profile = json.loads((LIB / name / 'profile.json').read_text())
    nodes = {node.get('name'): i for i, node in enumerate(gltf['nodes'])}
    roles = {'hips': 'pelvis', 'spine': 'spine_01', 'neck': 'neck_01', 'head': 'head'}
    if 'spine_02' in profile['boneMap']:
        roles.update(chest='spine_02', upperChest='spine_03')
    else:
        roles['chest'] = 'spine_03'
    for side, suffix in [('left', 'l'), ('right', 'r')]:
        for vrm, role in [('Shoulder', 'clavicle'), ('UpperArm', 'upperarm'),
                          ('LowerArm', 'lowerarm'), ('Hand', 'hand'),
                          ('UpperLeg', 'thigh'), ('LowerLeg', 'calf'),
                          ('Foot', 'foot'), ('Toes', 'ball')]:
            roles[side + vrm] = role + '_' + suffix
    bones = {vrm: {'node': nodes[profile['boneMap'][role]]} for vrm, role in roles.items()}
    if name == 'sobaya':
        for side, suffix in [('left', 'L'), ('right', 'R')]:
            for finger in ['Index', 'Middle', 'Ring', 'Little', 'Thumb']:
                segments = ['Metacarpal', 'Proximal'] if finger == 'Thumb' else ['Proximal', 'Intermediate']
                for index, segment in enumerate(segments, 1):
                    bones[side + finger + segment] = {'node': nodes[f'{finger}{index}.{suffix}']}
    vrm = {
        'specVersion': '1.0',
        'meta': {'name': profile['label'], 'version': '1.0.0',
                 'authors': ['窓際族物語'], 'licenseUrl': 'https://vrm.dev/licenses/1.0/',
                 'avatarPermission': 'onlyAuthor', 'allowRedistribution': False,
                 'modification': 'allowModification',
                 'copyrightInformation': '窓際族物語 — character rights retained by their owner.'},
        'humanoid': {'humanBones': bones},
        'firstPerson': {'meshAnnotations': [
            {'node': i, 'type': 'auto'} for i, node in enumerate(gltf['nodes']) if 'mesh' in node
        ]},
    }
    presets = {}
    for i, node in enumerate(gltf['nodes']):
        if 'mesh' not in node:
            continue
        mesh = gltf['meshes'][node['mesh']]
        targets = mesh.get('extras', {}).get('targetNames', [])
        for preset, target in [('aa', 'SpeechOpen'), ('ou', 'SpeechNarrow')]:
            if target in targets:
                presets.setdefault(preset, {'morphTargetBinds': []})['morphTargetBinds'].append(
                    {'node': i, 'index': targets.index(target), 'weight': 1.0})
    if presets:
        vrm['expressions'] = {'preset': presets}
    clips = [a['name'] for a in gltf.pop('animations', [])]
    gltf.pop('cameras', None)
    gltf.setdefault('extensionsUsed', []).append('VRMC_vrm')
    gltf.setdefault('extensions', {})['VRMC_vrm'] = vrm
    payload = json.dumps(gltf, ensure_ascii=False, separators=(',', ':')).encode()
    payload += b' ' * (-len(payload) % 4)
    result = struct.pack('<III', 0x46546C67, 2, 20 + len(payload) + len(binary_chunk))
    result += struct.pack('<II', len(payload), 0x4E4F534A) + payload + binary_chunk
    OUT.mkdir(parents=True, exist_ok=True)
    target = OUT / f'{name}.vrm'
    target.write_bytes(result)
    report = {'source': str(source.relative_to(ROOT)), 'sourceSha256': hashlib.sha256(source.read_bytes()).hexdigest(),
              'output': str(target.relative_to(ROOT)), 'sha256': hashlib.sha256(result).hexdigest(),
              'humanoidBones': {role: gltf['nodes'][value['node']]['name'] for role, value in bones.items()},
              'expressions': list(presets), 'gameClipsKeptInSourceGlb': clips,
              'geometryAndSkinBinaryUnchanged': True,
              'limitations': ['Original rest pose and local bone axes retained; use a VRM humanoid retargeter.',
                              'Optional eye, blink and complete finger articulation are not synthesized.',
                              'VRM consumers ignore embedded glTF animations; use the separate game GLB for existing clips.']}
    (OUT / f'{name}.manifest.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print(name, len(bones), 'mapped bones', len(result), 'bytes')


if __name__ == '__main__':
    for character in ['sobaya', 'fukuchan']:
        export(character)
