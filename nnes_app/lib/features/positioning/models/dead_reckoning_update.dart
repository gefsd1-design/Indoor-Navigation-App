class DeadReckoningUpdate {
  final double xMeters;
  final double yMeters;
  final double headingRad;
  final int steps;
  final DateTime timestamp;

  const DeadReckoningUpdate({
    required this.xMeters,
    required this.yMeters,
    required this.headingRad,
    required this.steps,
    required this.timestamp,
  });
}
