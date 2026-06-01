import 'office_node.dart';
import 'office_edge.dart';

/// Graph data structure for indoor office navigation using feet-based coordinates
class OfficeGraph {
  final Map<String, OfficeNode> nodes;
  final Map<String, List<Edge>> adjacencyList;

  OfficeGraph({
    required this.nodes,
    required this.adjacencyList,
  });

  /// Find shortest path using Dijkstra's algorithm
  /// Returns path as list of nodes, or empty list if no path exists
  List<OfficeNode> findShortestPath(String startId, String endId) {
    if (!nodes.containsKey(startId) || !nodes.containsKey(endId)) {
      return [];
    }

    if (startId == endId) {
      return [nodes[startId]!];
    }

    // Distance map: node ID -> shortest distance from start
    final distances = <String, double>{};
    // Previous node map for path reconstruction
    final previous = <String, String>{};
    // Unvisited nodes set
    final unvisited = <String>{};

    // Initialize distances
    for (var nodeId in nodes.keys) {
      distances[nodeId] = double.infinity;
      unvisited.add(nodeId);
    }
    distances[startId] = 0.0;

    while (unvisited.isNotEmpty) {
      // Find unvisited node with minimum distance
      String? current;
      double minDistance = double.infinity;

      for (var nodeId in unvisited) {
        if (distances[nodeId]! < minDistance) {
          minDistance = distances[nodeId]!;
          current = nodeId;
        }
      }

      if (current == null || current == endId) break;

      unvisited.remove(current);

      // Check all neighbors
      final edges = adjacencyList[current] ?? [];
      for (var edge in edges) {
        final neighbor = edge.toNodeId;

        if (!unvisited.contains(neighbor)) continue;

        final alt = distances[current]! + edge.distance;
        if (alt < distances[neighbor]!) {
          distances[neighbor] = alt;
          previous[neighbor] = current;
        }
      }
    }

    // Reconstruct path
    if (!previous.containsKey(endId) && endId != startId) {
      return []; // No path found
    }

    final path = <OfficeNode>[];
    String? current = endId;

    while (current != null) {
      path.add(nodes[current]!);
      current = previous[current];
    }

    return path.reversed.toList();
  }

  /// Calculate total distance of a path in feet
  double calculatePathDistance(List<OfficeNode> path) {
    if (path.length < 2) return 0.0;

    double totalDistance = 0.0;
    for (int i = 0; i < path.length - 1; i++) {
      totalDistance += path[i].distanceTo(path[i + 1]);
    }
    return totalDistance;
  }

  /// Get step-by-step directions for a path
  List<String> generateDirections(List<OfficeNode> path) {
    final directions = <String>[];

    for (int i = 0; i < path.length - 1; i++) {
      final currentNode = path[i];
      final nextNode = path[i + 1];

      // Look for edge information
      final edges = adjacencyList[currentNode.id] ?? [];
      final edge = edges.firstWhere(
        (e) => e.toNodeId == nextNode.id,
        orElse: () => Edge(
          fromNodeId: currentNode.id,
          toNodeId: nextNode.id,
          distance: currentNode.distanceTo(nextNode),
          direction: 'Head towards ${nextNode.name}',
        ),
      );

      final distance = edge.distance.toStringAsFixed(1);
      directions.add('${edge.direction} ($distance feet)');
    }

    if (path.isNotEmpty) {
      directions.add('Arrive at ${path.last.name}');
    }

    return directions;
  }
}
