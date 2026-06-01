import '../models/location_node.dart';
import 'package:geolocator/geolocator.dart';

class PathEngine {
  /// Haversine distance in meters
  static double calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  /// Dijkstra's Algorithm implementation
  static List<LocationNode> findShortestPath(
      String startId, String endId, List<LocationNode> allNodes) {
    final Map<String, LocationNode> nodeMap = {for (var n in allNodes) n.id: n};
    if (!nodeMap.containsKey(startId) || !nodeMap.containsKey(endId)) return [];

    final Map<String, double> distances = {};
    final Map<String, String> previous = {};
    final List<String> unvisited = [];

    for (var node in allNodes) {
      distances[node.id] = double.infinity;
      unvisited.add(node.id);
    }
    distances[startId] = 0.0;

    while (unvisited.isNotEmpty) {
      // Find node with minimum distance
      String? current;
      double minDistance = double.infinity;
      for (var id in unvisited) {
        if (distances[id]! < minDistance) {
          minDistance = distances[id]!;
          current = id;
        }
      }

      if (current == null || current == endId) break;

      unvisited.remove(current);
      final currentNode = nodeMap[current]!;

      for (var neighborId in currentNode.neighborIds) {
        if (!unvisited.contains(neighborId)) continue;

        final neighborNode = nodeMap[neighborId]!;
        final distToNeighbor = calculateDistance(currentNode.lat,
            currentNode.lng, neighborNode.lat, neighborNode.lng);

        final alt = distances[current]! + distToNeighbor;
        if (alt < distances[neighborId]!) {
          distances[neighborId] = alt;
          previous[neighborId] = current;
        }
      }
    }

    // Reconstruct path
    final List<LocationNode> path = [];
    String? current = endId;
    while (current != null) {
      path.add(nodeMap[current]!);
      current = previous[current];
    }

    return path.reversed.toList();
  }
}
