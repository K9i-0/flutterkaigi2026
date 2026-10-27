class BalanceField {
  const BalanceField(
    this.key,
    this.label,
    this.min,
    this.max,
    this.initial,
    this.step, {
    required this.group,
    this.unit = '',
    this.digits = 2,
  });
  final String key, label, group, unit;
  final double min, max, initial, step;

  /// Decimal places shown in the debug panel.
  final int digits;
  String format(double v) => '${v.toStringAsFixed(digits)}$unit';
}

class Balance {
  /// Shared base values; each character scales the drop settings.
  static const fields = <BalanceField>[
    BalanceField(
      'roundSeconds',
      '制限時間',
      10,
      60,
      20,
      5,
      group: 'ラウンド',
      unit: '秒',
      digits: 0,
    ),
    BalanceField(
      'spawnInterval',
      '出現間隔',
      .5,
      3,
      1.03,
      .05,
      group: 'ラウンド',
      unit: '秒',
    ),
    BalanceField(
      'fallSeconds',
      '落下時間（長いほど遅い）',
      1,
      6,
      3.1,
      .1,
      group: 'ラウンド',
      unit: '秒',
      digits: 1,
    ),
    BalanceField('badRatio', 'はずれの割合', 0, 1, .25, .05, group: 'ラウンド'),
    BalanceField(
      'penalty',
      'はずれ1回の減点',
      0,
      50,
      10,
      5,
      group: '採点（100点満点）',
      unit: '点',
      digits: 0,
    ),
    BalanceField(
      'catchMargin',
      'あたりの判定を輪より広げる幅',
      0,
      .6,
      .2,
      .05,
      group: '当たり判定（あたりだけ）',
    ),
    BalanceField(
      'catchGrace',
      '着地後もキャッチできる時間',
      0,
      .4,
      .15,
      .05,
      group: '当たり判定（あたりだけ）',
      unit: '秒',
    ),
    BalanceField(
      'acceleration',
      '移動の応答（大きいほど即応）',
      3,
      24,
      12,
      1,
      group: '操作',
      digits: 0,
    ),
    BalanceField(
      'tiltDegrees',
      '最大速度になる傾き',
      5,
      30,
      13.75,
      .5,
      group: '操作',
      unit: '°',
    ),
    BalanceField(
      'cameraStep',
      'スワイプ1回の回転',
      15,
      45,
      30,
      5,
      group: 'カメラ',
      unit: '°',
      digits: 0,
    ),
    BalanceField(
      'cameraLimit',
      '撮影デモの見回し角',
      30,
      75,
      60,
      5,
      group: 'カメラ',
      unit: '°',
      digits: 0,
    ),
    BalanceField(
      'zoomMin',
      'ピンチの最小倍率（引き）',
      .4,
      1,
      .7,
      .05,
      group: 'カメラ',
      unit: '×',
    ),
    BalanceField(
      'zoomMax',
      'ピンチの最大倍率（寄り）',
      1,
      6,
      5,
      .1,
      group: 'カメラ',
      unit: '×',
      digits: 1,
    ),
    BalanceField(
      'facingMin',
      '最小角',
      0,
      180,
      0,
      5,
      group: '落下物の向き',
      unit: '°',
      digits: 0,
    ),
    BalanceField(
      'facingMax',
      '最大角',
      0,
      180,
      180,
      5,
      group: '落下物の向き',
      unit: '°',
      digits: 0,
    ),
  ];

  /// Keys of removed settings that saved or pasted JSON may still contain.
  static const retired = {
    'catchRadius',
    'moveSpeed',
    'beerPoints',
    'comboBonus',
  };
  Balance._(this.values);
  factory Balance.defaults() =>
      Balance._(Map.unmodifiable({for (final f in fields) f.key: f.initial}));
  factory Balance.fromMap(Map<String, dynamic> input) {
    final values = Map<String, double>.from(Balance.defaults().values);
    for (final entry in input.entries) {
      if (retired.contains(entry.key)) continue;
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
      throw const FormatException('向きの最小角は最大角以下にしてください');
    }
    return Balance._(Map.unmodifiable(values));
  }
  final Map<String, double> values;
  double operator [](String key) => values[key]!;
}
