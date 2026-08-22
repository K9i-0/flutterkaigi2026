import 'dart:convert';
import 'dart:typed_data';

/// Pure-data representation of the VRM 1.0 information needed by the runtime
/// integration layer.
class VrmDocument {
  VrmDocument({
    required this.meta,
    required this.expressions,
    required this.humanoidBones,
    required this.hasMToon,
    required this.hasSpringBone,
    required this.hasNodeConstraint,
  });

  factory VrmDocument.fromGlbBytes(Uint8List bytes) {
    final json = _parseGlbJson(bytes);
    final extensions = _map(json['extensions']);
    final vrm = _map(extensions['VRMC_vrm']);
    if (vrm.isEmpty) {
      throw const FormatException(
        'VRMC_vrm is missing. This package currently targets VRM 1.0.',
      );
    }
    final specVersion = vrm['specVersion'] as String?;
    if (specVersion == null || !specVersion.startsWith('1.')) {
      throw FormatException('Unsupported VRM version: $specVersion');
    }

    final rawExpressions = _map(vrm['expressions']);
    final expressions = <String, VrmExpression>{};
    void collect(Object? value, {required bool preset}) {
      for (final entry in _map(value).entries) {
        final expression = _map(entry.value);
        expressions[entry.key] = VrmExpression(
          name: entry.key,
          isPreset: preset,
          isBinary: expression['isBinary'] as bool? ?? false,
          morphTargetBinds: [
            for (final raw in _list(expression['morphTargetBinds']))
              VrmMorphTargetBind.fromJson(_map(raw)),
          ],
        );
      }
    }

    collect(rawExpressions['preset'], preset: true);
    collect(rawExpressions['custom'], preset: false);

    final meta = _map(vrm['meta']);
    final humanoid = _map(vrm['humanoid']);
    final humanBones = <String, int>{};
    for (final entry in _map(humanoid['humanBones']).entries) {
      final node = _map(entry.value)['node'];
      if (node is int) humanBones[entry.key] = node;
    }

    final materials = _list(json['materials']);
    final nodes = _list(json['nodes']);
    return VrmDocument(
      meta: VrmMeta(
        name: meta['name'] as String? ?? 'Unnamed VRM',
        version: meta['version'] as String? ?? '',
        authors: [for (final value in _list(meta['authors'])) '$value'],
        licenseUrl: meta['otherLicenseUrl'] as String?,
      ),
      expressions: Map.unmodifiable(expressions),
      humanoidBones: Map.unmodifiable(humanBones),
      hasMToon: materials.any(
        (material) => _map(
          _map(material)['extensions'],
        ).containsKey('VRMC_materials_mtoon'),
      ),
      hasSpringBone: extensions.containsKey('VRMC_springBone'),
      hasNodeConstraint: nodes.any(
        (node) =>
            _map(_map(node)['extensions']).containsKey('VRMC_node_constraint'),
      ),
    );
  }

  final VrmMeta meta;
  final Map<String, VrmExpression> expressions;
  final Map<String, int> humanoidBones;
  final bool hasMToon;
  final bool hasSpringBone;
  final bool hasNodeConstraint;
}

class VrmMeta {
  const VrmMeta({
    required this.name,
    required this.version,
    required this.authors,
    required this.licenseUrl,
  });

  final String name;
  final String version;
  final List<String> authors;
  final String? licenseUrl;
}

class VrmExpression {
  const VrmExpression({
    required this.name,
    required this.isPreset,
    required this.isBinary,
    required this.morphTargetBinds,
  });

  final String name;
  final bool isPreset;
  final bool isBinary;
  final List<VrmMorphTargetBind> morphTargetBinds;
}

class VrmMorphTargetBind {
  const VrmMorphTargetBind({
    required this.node,
    required this.index,
    required this.weight,
  });

  factory VrmMorphTargetBind.fromJson(Map<String, Object?> json) =>
      VrmMorphTargetBind(
        node: json['node'] as int,
        index: json['index'] as int,
        weight: (json['weight'] as num?)?.toDouble() ?? 1.0,
      );

  final int node;
  final int index;
  final double weight;
}

Map<String, Object?> _parseGlbJson(Uint8List bytes) {
  if (bytes.length < 20) throw const FormatException('GLB is too short.');
  final data = ByteData.sublistView(bytes);
  if (data.getUint32(0, Endian.little) != 0x46546c67) {
    throw const FormatException('Invalid GLB magic.');
  }
  if (data.getUint32(4, Endian.little) != 2) {
    throw const FormatException('Only GLB 2 is supported.');
  }
  final totalLength = data.getUint32(8, Endian.little);
  if (totalLength > bytes.length) {
    throw const FormatException('Truncated GLB.');
  }
  var offset = 12;
  while (offset + 8 <= totalLength) {
    final length = data.getUint32(offset, Endian.little);
    final type = data.getUint32(offset + 4, Endian.little);
    final start = offset + 8;
    final end = start + length;
    if (end > totalLength) throw const FormatException('Invalid GLB chunk.');
    if (type == 0x4e4f534a) {
      final text = utf8.decode(bytes.sublist(start, end)).trimRight();
      return (jsonDecode(text) as Map).cast<String, Object?>();
    }
    offset = end;
  }
  throw const FormatException('GLB JSON chunk is missing.');
}

Map<String, Object?> _map(Object? value) =>
    value is Map ? value.cast<String, Object?>() : const {};

List<Object?> _list(Object? value) =>
    value is List ? value.cast<Object?>() : const [];
