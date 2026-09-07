enum MotionMethod {
  captured('収録動作', '既存のMixamo歩行・走行。人が演じた重心移動とタイミング。', 'MOCAP'),
  library('公開ライブラリ', 'CC0の手付け動作を骨格へ移植。接地補正前の状態も比較できます。', 'CC0 / FK'),
  procedural('体格からIK生成', '実測した脚長・腕長から足と手の軌道を解き、動きを生成。', 'PROCEDURAL'),
  hybrid('公開動作 + IK', '公開動作の演技を使い、脚長・肩幅・靴底に合わせて補正。', 'CC0 + IK'),
  video('Wan見本 + IK', 'クレイ動画から歩行周期・手足の軌道を観測。隠れた奥行きを補完し、体格別に接地を補正。', 'WAN + IK'),
  videoRig(
    'Wan骨格見本',
    '骨格ハイライト動画から身体の動きを再構成した試作。生成された骨格線は正解として使っていません。',
    'WAN RIG / 試作',
  );

  const MotionMethod(this.label, this.description, this.badge);
  final String label, description, badge;
}

class MotionEntry {
  MotionEntry(Map<String, dynamic> json)
    : name = json['name'] as String,
      action = json['action'] as String,
      label = json['label'] as String,
      category = json['category'] as String,
      method = MotionMethod.values.byName(json['method'] as String),
      duration = (json['duration'] as num).toDouble(),
      loop = json['loop'] as bool,
      source = json['source'] as String,
      prop = json['prop'] as String?,
      rootTravel = (json['rootTravelM'] as num?)?.toDouble() ?? 0,
      groundSpeed = (json['groundSpeedMps'] as num?)?.toDouble(),
      minSole = (json['minSoleM'] as num?)?.toDouble();
  final String name, action, label, category, source;
  final MotionMethod method;
  final double duration;
  final double? minSole;
  final String? prop;
  final double rootTravel;
  final double? groundSpeed;
  final bool loop;
}

class BodyProfile {
  BodyProfile(Map<String, dynamic> json)
    : id = json['id'] as String,
      label = json['label'] as String,
      asset = json['asset'] as String,
      height = (json['heightM'] as num).toDouble(),
      leg = (json['legM'] as num).toDouble(),
      arm = (json['armM'] as num).toDouble(),
      shoulder = (json['shoulderM'] as num).toDouble(),
      bones = json['bones'] as int,
      boneMap = Map<String, String>.from(json['boneMap'] as Map),
      clips = (json['clips'] as List)
          .map((e) => MotionEntry(e as Map<String, dynamic>))
          .toList() {
    if (clips.isEmpty ||
        clips.map((e) => e.name).toSet().length != clips.length) {
      throw const FormatException('Missing or duplicate motion entries');
    }
    if (clips.any((e) => !e.duration.isFinite || e.duration <= 0)) {
      throw const FormatException('Invalid animation duration');
    }
  }
  final String id, label, asset;
  final double height, leg, arm, shoulder;
  final int bones;
  final Map<String, String> boneMap;
  final List<MotionEntry> clips;

  MotionEntry? find(MotionMethod method, String action) {
    for (final clip in clips) {
      if (clip.method == method && clip.action == action) return clip;
    }
    return null;
  }
}

/// One clock makes pause, seek, slow motion and comparisons deterministic.
class MotionClock {
  double seconds = 0, speed = 1;
  bool paused = false, repeat = true;

  void advance(double dt, double duration) {
    if (paused || !dt.isFinite || dt <= 0 || duration <= 0) return;
    seconds += dt.clamp(0.0, .1) * speed;
    if (seconds >= duration) {
      if (repeat) {
        seconds %= duration;
      } else {
        seconds = duration;
        paused = true;
      }
    }
  }

  void seek(double time, double duration) {
    if (!time.isFinite) throw ArgumentError.value(time, 'time');
    seconds = time.clamp(0.0, duration);
    paused = true;
  }
}
