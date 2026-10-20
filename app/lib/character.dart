/// Existing shared models; adding a character also requires a build-hook entry.
enum CatchCharacter {
  sobaya('そば屋', 'sobaya', 2.6, .72),
  ctoOdatetsu('CTOおだてつ', 'cto_odatetsu', 3.4, .55),
  fukuchan('福ギュン', 'fukuchan', 3.0, .64);

  const CatchCharacter(this.label, this.id, this.moveSpeed, this.catchRadius);
  final String label, id;
  final double moveSpeed, catchRadius;
  String get portraitAsset =>
      'assets/images/$id.${this == ctoOdatetsu ? 'png' : 'jpg'}';
  String get modelAsset => 'assets/models/$id.glb';
}
