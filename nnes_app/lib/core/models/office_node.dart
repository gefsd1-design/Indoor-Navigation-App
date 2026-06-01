import 'dart:math' as math;

/// Represents a point in the office using feet-based coordinates
/// Origin (0,0) is at the TIH Board
class OfficeNode {
  final String id;
  final String name;
  final double x; // X coordinate in feet
  final double y; // Y coordinate in feet
  final bool isRoom; // true = destination room, false = junction point
  final List<String> adjacentNodeIds;

  OfficeNode({
    required this.id,
    required this.name,
    required this.x,
    required this.y,
    required this.isRoom,
    this.adjacentNodeIds = const [],
  });

  /// Calculate distance in feet to another node
  double distanceTo(OfficeNode other) {
    final dx = other.x - x;
    final dy = other.y - y;
    return math.sqrt(dx * dx + dy * dy);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OfficeNode && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
