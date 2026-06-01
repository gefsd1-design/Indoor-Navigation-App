/// Model representing an estimated location reading
class EstimatedLocation {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final bool isEstimated;
  final double? velocity;
  final double? acceleration;
  final double? direction;
  final int estimateCount;
  final int maxEstimates;

  EstimatedLocation({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.isEstimated,
    this.velocity,
    this.acceleration,
    this.direction,
    required this.estimateCount,
    required this.maxEstimates,
  });

  /// Convert to a displayable string
  String toDisplayString() {
    final statusTag = isEstimated ? ' (Estimated)' : ' (Valid GPS)';
    return '$latitude, $longitude, ${timestamp.toString()}$statusTag';
  }

  /// Convert to CSV format for file saving
  String toCsvString() {
    final status = isEstimated ? 'Estimated' : 'Valid GPS';
    return '$latitude,$longitude,${timestamp.toIso8601String()},$status';
  }

  @override
  String toString() => toDisplayString();
}
