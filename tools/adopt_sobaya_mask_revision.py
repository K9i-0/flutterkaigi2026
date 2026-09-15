"""Attach unchanged adopted animation tracks to the approved Blender geometry export.

Run Blender tools/export_sobaya_mask_revision.py geometry stage first; inputs stay separate.
The geometry stage checks every original rest bone against the adopted rig.
"""
import copy
import hashlib
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / '04_GAME_ASSETS/3d/hazard_adopted'
NEW = BASE / 'v2_20260915_mask/sobaya.glb'
OLD = BASE / 'v2_20260913/sobaya.glb'
SOURCE = ROOT / '04_GAME_ASSETS/3d/characters/sobaya/v2_20260915_mask/sobaya_v2.glb'

def read(path):
    data = path.read_bytes()
    length = struct.unpack_from('<I', data, 12)[0]
    return json.loads(data[20:20+length]), data[28+length:]

def main():
    target, binary = read(NEW)
    original, old_binary = read(OLD)
    binary = bytearray(binary)
    for node in target['nodes']:
        if node.get('name') == 'SobayaV2Rig.001':
            node['name'] = 'SobayaV2Rig'
    nodes = {n.get('name'): i for i, n in enumerate(target['nodes'])}
    # A mesh and a joint can both be named Head; animation must target joints.
    for skin in target['skins']:
        for index in skin['joints']:
            nodes[target['nodes'][index]['name']] = index
    accessors = {}
    def accessor(index):
        if index in accessors:
            return accessors[index]
        a = copy.deepcopy(original['accessors'][index])
        assert 'sparse' not in a
        view = copy.deepcopy(original['bufferViews'][a['bufferView']])
        offset = view.get('byteOffset', 0)
        while len(binary) % 4:
            binary.append(0)
        view['byteOffset'] = len(binary)
        view['buffer'] = 0
        binary.extend(old_binary[offset:offset+view['byteLength']])
        a['bufferView'] = len(target['bufferViews'])
        target['bufferViews'].append(view)
        accessors[index] = len(target['accessors'])
        target['accessors'].append(a)
        return accessors[index]
    target['animations'] = copy.deepcopy(original['animations'])
    for animation in target['animations']:
        for sampler in animation['samplers']:
            for key in ('input', 'output'):
                sampler[key] = accessor(sampler[key])
        for channel in animation['channels']:
            name = original['nodes'][channel['target']['node']]['name']
            assert name in nodes, name
            channel['target']['node'] = nodes[name]
    target['buffers'] = [{'byteLength': len(binary)}]
    encoded = json.dumps(target, separators=(',', ':')).encode()
    encoded += b' ' * (-len(encoded) % 4)
    binary += b'\x00' * (-len(binary) % 4)
    NEW.write_bytes(struct.pack('<III', 0x46546c67, 2, 28+len(encoded)+len(binary)) + struct.pack('<II', len(encoded), 0x4e4f534a) + encoded + struct.pack('<II', len(binary), 0x004e4942) + binary)
    manifest = json.loads((BASE / 'manifest.json').read_text())
    row = manifest['sobaya']
    row.update(file=str(NEW.relative_to(ROOT)), source=str(SOURCE.relative_to(ROOT)), sha256=hashlib.sha256(NEW.read_bytes()).hexdigest(), sourceSha256=hashlib.sha256(SOURCE.read_bytes()).hexdigest(), geometryRevision='20260915_oval_mask_original_v2_proportions', animationSource=str(OLD.relative_to(ROOT)), animationSourceSha256=hashlib.sha256(OLD.read_bytes()).hexdigest())
    for path in (BASE / 'manifest.json', NEW.parent / 'manifest.json'):
        path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+'\n')
    link = ROOT / '21_SOBAYA_HAZARD_LAB/assets/models/sobaya.glb'
    link.unlink()
    link.symlink_to('../../../'+str(NEW.relative_to(ROOT)))
    print('Adopted', len(target['animations']), 'unchanged animation clips')

if __name__ == '__main__':
    main()
