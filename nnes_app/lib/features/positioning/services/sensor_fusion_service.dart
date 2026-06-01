import 'dart:async';
import 'dart:math';

import 'package:sensors_plus/sensors_plus.dart';

import '../models/dead_reckoning_update.dart';

class SensorFusionService {
  final double stepLengthMeters;
  final double stepThreshold;
  final Duration minStepInterval;

  StreamSubscription<UserAccelerometerEvent>? _accelSub;
  StreamSubscription<MagnetometerEvent>? _magSub;
  final StreamController<DeadReckoningUpdate> _controller =
      StreamController.broadcast();

  double _headingRad = 0.0;
  double _xMeters = 0.0;
  double _yMeters = 0.0;
  double _lastAccelMag = 0.0;
  DateTime? _lastStepTime;
  int _steps = 0;

  SensorFusionService({
    this.stepLengthMeters = 0.75,
    this.stepThreshold = 1.2,
    this.minStepInterval = const Duration(milliseconds: 350),
  });

  Stream<DeadReckoningUpdate> get updates => _controller.stream;

  void start() {
    _accelSub?.cancel();
    _magSub?.cancel();

    _magSub = magnetometerEvents.listen((event) {
      _headingRad = atan2(event.y, event.x);
    });

    _accelSub = userAccelerometerEvents.listen((event) {
      final mag = sqrt(
        (event.x * event.x) + (event.y * event.y) + (event.z * event.z),
      );
      final now = DateTime.now();
      final crossed = _lastAccelMag <= stepThreshold && mag > stepThreshold;
      final enoughTime = _lastStepTime == null ||
          now.difference(_lastStepTime!) > minStepInterval;

      if (crossed && enoughTime) {
        _lastStepTime = now;
        _steps += 1;
        final dx = stepLengthMeters * cos(_headingRad);
        final dy = stepLengthMeters * sin(_headingRad);
        _xMeters += dx;
        _yMeters += dy;

        _controller.add(
          DeadReckoningUpdate(
            xMeters: _xMeters,
            yMeters: _yMeters,
            headingRad: _headingRad,
            steps: _steps,
            timestamp: now,
          ),
        );
      }

      _lastAccelMag = mag;
    });
  }

  void stop() {
    _accelSub?.cancel();
    _magSub?.cancel();
    _accelSub = null;
    _magSub = null;
  }

  void reset() {
    _xMeters = 0.0;
    _yMeters = 0.0;
    _steps = 0;
    _lastAccelMag = 0.0;
    _lastStepTime = null;
  }

  void dispose() {
    stop();
    _controller.close();
  }
}
