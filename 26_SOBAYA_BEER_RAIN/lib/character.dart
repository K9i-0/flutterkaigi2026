/// Existing shared models; adding a character also requires a build-hook entry.
enum CatchCharacter {
  sobaya('そば屋', 'sobaya', 2.6, .72),
  ctoOdatetsu('CTOおだてつ', 'cto_odatetsu', 3.4, .55);

  const CatchCharacter(this.label, this.id, this.moveSpeed, this.catchRadius);
  final String label, id;
  final double moveSpeed, catchRadius;
  String get modelAsset => 'assets/models/$id.glb';
}
