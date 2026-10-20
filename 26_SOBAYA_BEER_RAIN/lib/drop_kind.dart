/// A drop's identity also owns its scoring category and shared model path.
enum CanKind {
  superTry('ビール', 'super_try', false),
  light('ビール', 'light', false),
  happoshu('発泡酒', 'happoshu', true),
  chikuwa('ちくわ', 'chikuwa', false),
  toxicChikuwa('毒ちくわ', 'chikuwa_toxic', true),
  yumemin('ゆめみん', 'yumemin', false),
  yametaro('やめ太郎', 'yametaro', true);

  const CanKind(this.label, this.assetId, this.isBad);
  final String label, assetId;
  final bool isBad;
  bool get isCan => index < 3;
  bool get isChikuwa => this == chikuwa || this == toxicChikuwa;
  String asset({bool lane = true}) =>
      'assets/models/$assetId${lane && isCan ? '_lane' : ''}.glb';
}
