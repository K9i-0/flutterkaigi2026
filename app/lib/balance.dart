class BalanceField {
  const BalanceField(
    this.key,
    this.label,
    this.min,
    this.max,
    this.initial,
    this.step,
  );
  final String key, label;
  final double min, max, initial, step;
}

class Balance {
  static const fields = <BalanceField>[
    BalanceField('roundSeconds', '制限時間（秒）', 10, 60, 20, 5),
    BalanceField('spawnInterval', '出現間隔（秒）', .5, 3, 1.03, .05),
    BalanceField('fallSeconds', '落下時間（秒・長いほど遅い）', 1, 6, 3.1, .1),
    BalanceField('moveSpeed', '移動速度（鉄骨編）', 1, 5, 2.6, .1),
    BalanceField('acceleration', '移動の応答（大きいほど即応）', 3, 24, 12, 1),
    BalanceField('catchRadius', 'キャッチ半径', .3, 1.2, .72, .02),
    BalanceField('badRatio', '発泡酒の割合', 0, 1, .25, .05),
    BalanceField('beerPoints', 'ビール基本点', 25, 300, 100, 25),
    BalanceField('penalty', '発泡酒の減点', 0, 500, 200, 25),
    BalanceField('comboBonus', '連続キャッチ加点（最大4段階）', 0, 100, 25, 5),
    BalanceField('cameraStep', 'カメラ1タップ（度・鉄骨編）', 15, 45, 30, 5),
    BalanceField('cameraLimit', 'カメラ左右上限（度・鉄骨編）', 30, 75, 60, 5),
    BalanceField('facingMin', '缶の向き・最小角（度）', 0, 110, 70, 5),
    BalanceField('facingMax', '缶の向き・最大角（度）', 0, 130, 110, 5),
    BalanceField('tiltDegrees', '最大速度になる傾き（度）', 5, 30, 13.75, .5),
  ];
  Balance._(this.values);
  factory Balance.defaults() =>
      Balance._(Map.unmodifiable({for (final f in fields) f.key: f.initial}));
  factory Balance.fromMap(Map<String, dynamic> input) {
    final values = Map<String, double>.from(Balance.defaults().values);
    for (final entry in input.entries) {
      final spec = fields.where((f) => f.key == entry.key).firstOrNull;
      if (spec == null || entry.value is! num) {
        throw FormatException('Unknown or non-numeric field: ${entry.key}');
      }
      final v = (entry.value as num).toDouble();
      if (!v.isFinite || v < spec.min || v > spec.max) {
        throw FormatException('${entry.key}: ${spec.min}..${spec.max}');
      }
      values[entry.key] = v;
    }
    if (values['facingMin']! > values['facingMax']!) {
      throw const FormatException('缶の最小角は最大角以下にしてください');
    }
    return Balance._(Map.unmodifiable(values));
  }
  final Map<String, double> values;
  double operator [](String key) => values[key]!;
  static Balance preset(String name) => switch (name) {
    'easy' => Balance.fromMap({
      'spawnInterval': 1.6,
      'fallSeconds': 4.5,
      'catchRadius': .95,
      'badRatio': .15,
      'facingMin': 20,
      'facingMax': 70,
    }),
    'hard' => Balance.fromMap({
      'spawnInterval': .8,
      'fallSeconds': 2.4,
      'catchRadius': .55,
      'badRatio': .4,
      'facingMin': 90,
      'facingMax': 130,
    }),
    _ => Balance.defaults(),
  };
}
