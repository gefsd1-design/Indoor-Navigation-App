/// Represents a directed edge between two office nodes
class Edge {
  final String fromNodeId;
  final String toNodeId;
  final double distance; // Distance in feet
  final String direction; // e.g., "Turn right into Lab Wing"

  Edge({
    required this.fromNodeId,
    required this.toNodeId,
    required this.distance,
    required this.direction,
  });
}
