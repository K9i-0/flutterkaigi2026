/// Time of day for the Akasaka beam stage. The plane mode keeps its own rig.
enum StageTime {
  day('昼'),
  night('夜');

  const StageTime(this.label);
  final String label;
  String get id => name;
}
