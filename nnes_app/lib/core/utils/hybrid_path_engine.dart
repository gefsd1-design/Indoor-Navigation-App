import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import '../models/location_node.dart';
import '../models/office_node.dart';
import '../models/office_graph.dart';

/// Hybrid navigation engine supporting both GPS and indoor (feet-based) navigation
class HybridPathEngine {
  /// GPS accuracy threshold (in meters) to determine if we should use indoor navigation
  static const double gpsIndoorThreshold = 10.0;

  /// Calculate distance between two GPS coordinates using Haversine formula
  static double calculateGpsDistance(
      double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  /// Calculate distance between two indoor (feet) coordinates
  static double calculateIndoorDistance(
      double x1, double y1, double x2, double y2) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Find shortest path using GPS coordinates (for outdoor navigation)
  /// Returns path as list of LocationNodes
  static List<LocationNode> findShortestPathGps(
    String startId,
    String endId,
    List<LocationNode> allNodes,
  ) {
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
        final distToNeighbor = calculateGpsDistance(
          currentNode.lat,
          currentNode.lng,
          neighborNode.lat,
          neighborNode.lng,
        );

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

  /// Find shortest path using indoor coordinates (for indoor navigation)
  /// Returns path as list of OfficeNodes
  static List<OfficeNode> findShortestPathIndoor(
    String startId,
    String endId,
    OfficeGraph graph,
  ) {
    return graph.findShortestPath(startId, endId);
  }

  /// Automatically select navigation mode based on available data
  /// Returns 'gps' or 'indoor'
  static String selectNavigationMode({
    required bool hasGpsSignal,
    required bool hasIndoorData,
  }) {
    if (hasIndoorData && !hasGpsSignal) {
      return 'indoor';
    } else if (hasGpsSignal && !hasIndoorData) {
      return 'gps';
    } else if (hasIndoorData && hasGpsSignal) {
      // Prefer indoor for better accuracy in buildings
      return 'indoor';
    }
    return 'undefined';
  }

  /// Generate text directions from GPS path
  static List<String> generateGpsDirections(List<LocationNode> path) {
    final directions = <String>[];

    if (path.isEmpty) {
      return directions;
    }

    directions.add('Starting from ${path.first.name}');

    for (int i = 0; i < path.length - 1; i++) {
      final distance = calculateGpsDistance(
        path[i].lat,
        path[i].lng,
        path[i + 1].lat,
        path[i + 1].lng,
      );
      directions.add(
        'Head towards ${path[i + 1].name} (${(distance / 0.3048).toStringAsFixed(1)} feet)',
      );
    }

    if (path.isNotEmpty) {
      directions.add('Arrive at ${path.last.name}');
    }

    return directions;
  }

  /// Generate text directions from indoor path (feet-based)
  static List<String> generateIndoorDirections(
    List<OfficeNode> path,
    OfficeGraph graph,
  ) {
    return graph.generateDirections(path);
  }

  /// Calculate total distance of GPS path in meters
  static double calculateGpsPathDistance(List<LocationNode> path) {
    if (path.length < 2) return 0.0;

    double totalDistance = 0.0;
    for (int i = 0; i < path.length - 1; i++) {
      totalDistance += calculateGpsDistance(
        path[i].lat,
        path[i].lng,
        path[i + 1].lat,
        path[i + 1].lng,
      );
    }
    return totalDistance;
  }

  /// Calculate total distance of indoor path in feet
  static double calculateIndoorPathDistance(List<OfficeNode> path) {
    return path.isEmpty ? 0.0 : path[0].distanceTo(path[path.length - 1]);
  }
}
