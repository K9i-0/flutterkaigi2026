import 'drop_kind.dart';

/// Easy to hard, as listed on the selection and ranking screens.
const pickerOrder = [
  CatchCharacter.fukuchan,
  CatchCharacter.ctoOdatetsu,
  CatchCharacter.sobaya,
];

/// Existing shared models; adding a character also requires a build-hook entry.
enum CatchCharacter {
  sobaya('そば屋', 'sobaya', 2.6, .72),
  ctoOdatetsu('CTOおだてつ', 'cto_odatetsu', 3.4, .55),
  fukuchan('福ギュン', 'fukuchan', 3.0, .64);

  const CatchCharacter(this.label, this.id, this.moveSpeed, this.catchRadius);
  final String label, id;
  final double moveSpeed, catchRadius;
  String get difficulty => switch (this) {
    fukuchan => 'イージー',
    ctoOdatetsu => 'ノーマル',
    sobaya => 'ハード',
  };
  double get spawnMultiplier => switch (this) {
    fukuchan => 1.45,
    ctoOdatetsu => 1,
    sobaya => .8,
  };
  double get fallMultiplier => switch (this) {
    fukuchan => 1.35,
    ctoOdatetsu => 1,
    sobaya => .8,
  };
  double get badMultiplier => switch (this) {
    fukuchan => .6,
    ctoOdatetsu => 1,
    sobaya => 1.6,
  };
  List<CanKind> get goodDrops => switch (this) {
    fukuchan => const [CanKind.yumemin],
    ctoOdatetsu => const [CanKind.chikuwa],
    sobaya => const [CanKind.superTry, CanKind.light],
  };
  CanKind get badDrop => switch (this) {
    fukuchan => CanKind.yametaro,
    ctoOdatetsu => CanKind.toxicChikuwa,
    sobaya => CanKind.happoshu,
  };
  String get hint => switch (this) {
    fukuchan => 'ゆっくり落ちてくる。ゆめみんをキャッチ。',
    ctoOdatetsu => 'こんがり焼けたちくわを。紫色にはご用心。',
    sobaya => '銘柄いろいろ。ラベルを見て、ビールだけ。',
  };
  String get portraitAsset =>
      'assets/images/$id.${this == ctoOdatetsu ? 'png' : 'jpg'}';
  String get modelAsset => 'assets/models/$id.glb';
}
