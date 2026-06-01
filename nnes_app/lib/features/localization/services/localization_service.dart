import 'package:geolocator/geolocator.dart';
import '../../../core/models/location_node.dart';
import '../../../core/utils/path_engine.dart';

class LocalizationService {
  /// Dummy image hash matching for indoor localization
  static LocationNode? matchImageToNode(
      String imageHash, List<LocationNode> nodes) {
    // In a real scenario, compare hash with a reference DB.
    // For now, return null to enforce GPS fallback logic.
    return null;
  }

  /// Fallback: estimate closest node based on GPS coordinates
  static Future<LocationNode?> estimateFromGps(List<LocationNode> nodes) async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    // High accuracy for indoor proximity
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
      ),
    );

    LocationNode? closestNode;
    double minDistance = double.infinity;

    for (var node in nodes) {
      double distance = PathEngine.calculateDistance(
        position.latitude,
        position.longitude,
        node.lat,
        node.lng,
      );
      if (distance < minDistance) {
        minDistance = distance;
        closestNode = node;
      }
    }

    return closestNode;
  }

  /// Get raw position for Debug Mode
  static Future<Position?> getRawPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
        ),
      );
    } catch (e) {
      return null;
    }
  }
}
