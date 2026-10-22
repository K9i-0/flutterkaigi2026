/// A drop's identity also owns its scoring category and shared model path.
enum CanKind {
  superTry('ビール', 'super_try', false),
  light('ビール', 'light', false),
  happoshu('発泡酒', 'happoshu', true),
  chikuwa('ちくわ', 'chikuwa', false),
  toxicChikuwa('毒ちくわ', 'chikuwa', true, variant: 'toxic'),
  yumemin('ゆめみん', 'yumemin', false),
  yametaro('やめ太郎', 'yametaro', true);

  const CanKind(this.label, this.assetId, this.isBad, {this.variant});
  final String label, assetId;

  /// KHR_materials_variants look inside [assetId]; null keeps the default.
  final String? variant;
  final bool isBad;
  bool get isCan => index < 3;
  bool get isChikuwa => this == chikuwa || this == toxicChikuwa;
  String asset() => 'assets/models/$assetId.glb';
}
