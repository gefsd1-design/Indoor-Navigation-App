import 'dart:async';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../models/estimated_location.dart';

/// Service for estimating location when GPS signal is weak
/// Implements the logic from the Kotlin MainActivity
class LocationEstimationService {
  // GPS and location state
  Position? _lastValidLocation;
  DateTime? _lastValidTimestamp;
  bool _snrAboveThreshold = false;

  // Motion and sensor state
  double _velocity = 0.0;
  double _acceleration = 0.0;
  double _direction = 0.0;
  int _estimatedCount = 0;
  final int _maxEstimates = 50;

  // Sensor listeners
  late StreamSubscription<AccelerometerEvent> _accelerometerSub;
  late StreamSubscription<GyroscopeEvent> _gyroscopeSub;
  late StreamSubscription<UserAccelerometerEvent> _userAccelSub;

  // For location estimation
  int _lastTimestamp = 0;
  List<double>? _lastGyroscopeValues;

  // Streams for UI updates
  final _locationStream = StreamController<EstimatedLocation>.broadcast();
  final _statusStream = StreamController<String>.broadcast();

  Stream<EstimatedLocation> get locationStream => _locationStream.stream;
  Stream<String> get statusStream => _statusStream.stream;

  /// Initialize the location estimation service
  Future<void> initialize() async {
    _startSensorListeners();
    _startLocationTracking();
  }

  /// Start listening to sensor events
  void _startSensorListeners() {
    _accelerometerSub = accelerometerEvents.listen((AccelerometerEvent event) {
      _handleAccelerometerEvent(event);
    });

    _gyroscopeSub = gyroscopeEvents.listen((GyroscopeEvent event) {
      _handleGyroscopeEvent(event);
    });

    _userAccelSub =
        userAccelerometerEvents.listen((UserAccelerometerEvent event) {
      // Alternative accelerometer data if needed
    });
  }

  /// Handle accelerometer sensor changes
  void _handleAccelerometerEvent(AccelerometerEvent event) {
    final accMagnitude = sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );
    _acceleration = accMagnitude - 9.81; // Subtract gravitational acceleration

    // Set to 0 if below threshold
    if (_acceleration.abs() < 0.2) {
      _acceleration = 0.0;
    }
  }

  /// Handle gyroscope sensor changes
  void _handleGyroscopeEvent(GyroscopeEvent event) {
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    final deltaTime =
        _lastTimestamp != 0 ? (currentTime - _lastTimestamp) / 1000.0 : 1.0;
    _lastTimestamp = currentTime;

    if (_lastGyroscopeValues != null) {
      // Calculate the change in orientation (heading)
      final deltaYaw = event.z * deltaTime;
      _direction += deltaYaw;
    } else {
      // Set initial gyroscope values
      _lastGyroscopeValues = [event.x, event.y, event.z];
    }
  }

  /// Start tracking real GPS location
  Future<void> _startLocationTracking() async {
    try {
      // Check GPS enabled
      final isLocationServiceEnabled =
          await Geolocator.isLocationServiceEnabled();
      if (!isLocationServiceEnabled) {
        _statusStream.add('GPS is disabled. Please enable it!');
        return;
      }

      // Request permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        _statusStream.add('Location permission permanently denied');
        return;
      }

      // Listen to position updates
      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 0,
        ),
      ).listen((Position position) {
        _handleLocationUpdate(position);
      });
    } catch (e) {
      _statusStream.add('Error starting location tracking: $e');
    }
  }

  /// Handle incoming GPS location updates
  void _handleLocationUpdate(Position position) {
    final timestamp = DateTime.now();

    if (_snrAboveThreshold) {
      // GPS signal is strong
      _lastValidLocation = position;
      _lastValidTimestamp = timestamp;
      _velocity = 0.0;
      _estimatedCount = 0;

      final location = EstimatedLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: timestamp,
        isEstimated: false,
        velocity: _velocity,
        acceleration: _acceleration,
        direction: _direction,
        estimateCount: _estimatedCount,
        maxEstimates: _maxEstimates,
      );

      _locationStream.add(location);
      _statusStream.add('Valid GPS: ${location.toDisplayString()}');
    } else if (_estimatedCount < _maxEstimates && _lastValidLocation != null) {
      // Start estimating if GPS is weak
      _startEstimation();
    }
  }

  /// Start the estimation process
  void _startEstimation() {
    _estimationTimer?.cancel();
    _estimationTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (_estimatedCount < _maxEstimates && _lastValidLocation != null) {
          _estimateLocation();
        } else {
          _estimationTimer?.cancel();
        }
      },
    );
  }

  Timer? _estimationTimer;

  /// Estimate the current location based on motion
  void _estimateLocation() {
    final location = _lastValidLocation;
    if (location == null) return;

    const timeInterval = 1.0; // Update interval in seconds

    // Update velocity based on acceleration
    _velocity += _acceleration * timeInterval;
    _velocity = _velocity.clamp(-10.0, 10.0); // Prevent unrealistic velocities

    // Calculate distance traveled
    final distance = _velocity * timeInterval;

    // Earth's radius in meters
    const earthRadius = 6378137.0;

    // Calculate lat/lon change
    final directionRad = _direction * pi / 180;
    final deltaLat = (distance * cos(directionRad)) / earthRadius * (180 / pi);
    final deltaLon = (distance * sin(directionRad)) /
        (earthRadius * cos(location.latitude * pi / 180)) *
        (180 / pi);

    // Update location
    _lastValidLocation = Position(
      latitude: location.latitude + deltaLat,
      longitude: location.longitude + deltaLon,
      timestamp: DateTime.now(),
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
      accuracy: 0,
      altitude: 0,
      altitudeAccuracy: 0,
    );

    _estimatedCount++;

    final estimatedLoc = EstimatedLocation(
      latitude: _lastValidLocation!.latitude,
      longitude: _lastValidLocation!.longitude,
      timestamp: DateTime.now(),
      isEstimated: true,
      velocity: _velocity,
      acceleration: _acceleration,
      direction: _direction,
      estimateCount: _estimatedCount,
      maxEstimates: _maxEstimates,
    );

    _locationStream.add(estimatedLoc);
    _statusStream.add(
      'EST ${_estimatedCount}/$_maxEstimates: ${estimatedLoc.toDisplayString()}',
    );
  }

  /// Set SNR threshold status (would be called from GPS status callback)
  void setSNRStatus(bool aboveThreshold) {
    _snrAboveThreshold = aboveThreshold;
    if (aboveThreshold) {
      _estimationTimer?.cancel();
      _statusStream.add('GPS SNR is good');
    } else {
      _statusStream.add('GPS SNR is weak, starting estimation');
    }
  }

  /// Get current estimated location
  EstimatedLocation? get currentLocation {
    if (_lastValidLocation == null) return null;
    return EstimatedLocation(
      latitude: _lastValidLocation!.latitude,
      longitude: _lastValidLocation!.longitude,
      timestamp: _lastValidTimestamp ?? DateTime.now(),
      isEstimated: _estimatedCount > 0,
      velocity: _velocity,
      acceleration: _acceleration,
      direction: _direction,
      estimateCount: _estimatedCount,
      maxEstimates: _maxEstimates,
    );
  }

  /// Cleanup resources
  void dispose() {
    _accelerometerSub.cancel();
    _gyroscopeSub.cancel();
    _userAccelSub.cancel();
    _estimationTimer?.cancel();
    _locationStream.close();
    _statusStream.close();
  }
}
