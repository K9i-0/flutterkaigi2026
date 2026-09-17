"""Replace one named glTF animation without re-exporting meshes or other clips."""
import copy
import json
import struct
from pathlib import Path


def read_glb(path):
    data = Path(path).read_bytes()
    size = struct.unpack_from('<I', data, 12)[0]
    doc = json.loads(data[20:20+size])
    return doc, data[28+size:28+size+doc['buffers'][0]['byteLength']]


def replace_animation(original, animated, destination, name='Greeting'):
    doc, binary = read_glb(original)
    source, source_binary = read_glb(animated)
    animation = copy.deepcopy(next(a for a in source['animations'] if a['name'] == name))
    target_joints = {j for skin in doc.get('skins', []) for j in skin['joints']}
    source_joints = {j for skin in source.get('skins', []) for j in skin['joints']}
    target_nodes = {(n.get('name'), i in target_joints, 'mesh' in n): i
                    for i, n in enumerate(doc['nodes'])}
    # Exported channels must use the same local reference frames as the original.
    for channel in animation['channels']:
        source_node = source['nodes'][channel['target']['node']]
        target_id = target_nodes[(source_node.get('name'),
                                  channel['target']['node'] in source_joints,
                                  'mesh' in source_node)]
        target_node = doc['nodes'][target_id]
        for key, default in [('translation', [0, 0, 0]), ('rotation', [0, 0, 0, 1]), ('scale', [1, 1, 1])]:
            a, b = source_node.get(key, default), target_node.get(key, default)
            error = max(abs(x-y) for x, y in zip(a, b))
            if key == 'rotation':
                error = min(error, max(abs(x+y) for x, y in zip(a, b)))
            assert error < 1e-4, (source_node['name'], key, a, b)
        channel['target']['node'] = target_id
    result_binary = bytearray(binary)
    remapped = {}
    for sampler in animation['samplers']:
        for key in ['input', 'output']:
            old = sampler[key]
            if old not in remapped:
                accessor = copy.deepcopy(source['accessors'][old])
                assert 'sparse' not in accessor
                view = copy.deepcopy(source['bufferViews'][accessor['bufferView']])
                start, count = view.get('byteOffset', 0), view['byteLength']
                while len(result_binary) % 4:
                    result_binary.append(0)
                view['byteOffset'] = len(result_binary)
                view['buffer'] = 0
                result_binary.extend(source_binary[start:start+count])
                accessor['bufferView'] = len(doc['bufferViews'])
                doc['bufferViews'].append(view)
                remapped[old] = len(doc['accessors'])
                doc['accessors'].append(accessor)
            sampler[key] = remapped[old]
    index = next(i for i, a in enumerate(doc['animations']) if a['name'] == name)
    doc['animations'][index] = animation
    doc['buffers'][0]['byteLength'] = len(result_binary)
    raw = json.dumps(doc, separators=(',', ':')).encode()
    raw += b' ' * (-len(raw) % 4)
    result_binary.extend(b'\0' * (-len(result_binary) % 4))
    output = struct.pack('<III', 0x46546c67, 2, 28+len(raw)+len(result_binary))
    output += struct.pack('<I4s', len(raw), b'JSON') + raw
    output += struct.pack('<I4s', len(result_binary), b'BIN\0') + result_binary
    Path(destination).write_bytes(output)
    # Original data and all unrelated animation declarations remain exact.
    before, before_binary = read_glb(original)
    assert result_binary[:len(before_binary)] == before_binary
    for a, b in zip(before['animations'], doc['animations']):
        if a['name'] != name:
            assert a == b
    for key in ['nodes', 'meshes', 'skins', 'materials', 'textures', 'images']:
        assert before.get(key) == doc.get(key), key
    return {'unchangedOtherClips': len(doc['animations'])-1,
            'originalBinaryPrefixPreserved': True,
            'geometryMaterialsSkinRestNodesUnchanged': True}


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('original')
    parser.add_argument('animated')
    parser.add_argument('destination')
    args = parser.parse_args()
    print(replace_animation(args.original, args.animated, args.destination))
