import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:pedometer/pedometer.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/location_node.dart';
import '../../../../core/models/office_graph.dart';
import '../../../../core/models/office_graph_factory.dart';
import '../../../../core/models/office_node.dart';
import '../../../../core/utils/path_engine.dart';
import '../../../localization/services/localization_service.dart';
import '../widgets/indoor_map_painter.dart';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen>
    with SingleTickerProviderStateMixin {
  List<LocationNode> _allNodes = [];
  List<LocationNode> _gpsDestinations = [];
  LocationNode? _currentLocation;
  LocationNode? _destination;
  List<LocationNode> _activePath = [];

  late OfficeGraph _officeGraph;
  List<OfficeNode> _officeNodes = [];
  OfficeNode? _officeCurrent;
  OfficeNode? _officeDestination;
  List<OfficeNode> _officeActivePath = [];

  double? _heading;
  bool _isDebugMode = false;
  Position? _rawPosition;

  StreamSubscription<Position>? _positionStream;
  StreamSubscription<CompassEvent>? _compassStream;
  StreamSubscription<StepCount>? _stepStream;
  StreamSubscription<GyroscopeEvent>? _gyroStream;
  StreamSubscription<AccelerometerEvent>? _accelStream;
  final FlutterTts _flutterTts = FlutterTts();
  bool _hasAnnouncedArrival = false;
  late AnimationController _pathController;
  double _pathProgress = 0.0;
  int? _stepBase;
  int? _lastStepCount;
  double _gyroHeading = 0.0;
  DateTime? _lastGyroTime;
  static const double _stepLengthFeet = 2.5;

  @override
  void initState() {
    super.initState();
    _pathController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..addListener(() {
        if (mounted) {
          setState(() {
            _pathProgress = _pathController.value;
          });
        }
      });
    _initData();
    _initTts();
    _initPdrSensors();
  }

  Future<void> _initData() async {
    _allNodes = await LocationNode.loadNodes();
    _officeGraph = OfficeGraphFactory.buildGraph();
    _officeNodes =
        _officeGraph.nodes.values.where((node) => node.isRoom).toList();
    final roomIds = _officeNodes.map((node) => node.id).toSet();
    _gpsDestinations =
        _allNodes.where((node) => roomIds.contains(node.id)).toList();
    if (_gpsDestinations.isEmpty) {
      _gpsDestinations = List<LocationNode>.from(_allNodes);
    }
    _gpsDestinations.sort((a, b) => a.name.compareTo(b.name));

    // Start tracking orientation
    _compassStream = FlutterCompass.events?.listen((event) {
      if (mounted) {
        setState(() {
          _heading = event.heading;
        });
      }
    });

    // Start tracking location
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 1, // trigger update every 1 meter
    );

    _positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((Position? position) async {
      if (position != null && mounted) {
        _rawPosition = position;
        final node = await LocalizationService.estimateFromGps(_allNodes);
        if (node != null && node != _currentLocation) {
          setState(() {
            _currentLocation = node;
            _updatePath();
            _syncOfficePath();
            _checkArrival();
          });
        } else if (_isDebugMode) {
          setState(() {});
        }
      }
    });

    // Initial fetch
    _currentLocation =
        await LocalizationService.estimateFromGps(_allNodes) ?? _allNodes.first;
    _syncOfficePath();
    setState(() {});
  }

  void _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  void _updatePath() {
    if (_currentLocation != null && _destination != null) {
      _activePath = PathEngine.findShortestPath(
          _currentLocation!.id, _destination!.id, _allNodes);
    } else {
      _activePath = [];
    }
  }

  void _syncOfficePath() {
    _officeCurrent = _currentLocation == null
        ? null
        : _mapLocationToOfficeNode(_currentLocation!);
    _officeDestination =
        _destination == null ? null : _mapLocationToOfficeNode(_destination!);

    if (_officeCurrent != null && _officeDestination != null) {
      _officeActivePath = _officeGraph.findShortestPath(
        _officeCurrent!.id,
        _officeDestination!.id,
      );
      _syncPdrProgress();
    } else {
      _officeActivePath = [];
      _pathController.stop();
      _pathProgress = 0.0;
    }
  }

  void _initPdrSensors() {
    _stepStream = Pedometer.stepCountStream.listen(
      (event) {
        _lastStepCount = event.steps;
        _updatePdrProgressFromSteps(event.steps);
      },
      onError: (error) {
        debugPrint('Step tracking error: $error');
      },
    );

    _gyroStream = gyroscopeEventStream().listen(
      (event) {
        final now = DateTime.now();
        if (_lastGyroTime != null) {
          final dt = now.difference(_lastGyroTime!).inMilliseconds / 1000.0;
          if (dt > 0) {
            _gyroHeading += (event.z * dt) * (180 / math.pi);
            if (_gyroHeading >= 360) _gyroHeading -= 360;
            if (_gyroHeading < 0) _gyroHeading += 360;
          }
        }
        _lastGyroTime = now;
      },
      onError: (error) {
        debugPrint('Gyroscope error: $error');
      },
    );

    _accelStream = accelerometerEventStream().listen(
      (event) {
        math.sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      },
      onError: (error) {
        debugPrint('Accelerometer error: $error');
      },
    );
  }

  void _syncPdrProgress() {
    if (_officeActivePath.length < 2) {
      _pathController.stop();
      _pathProgress = 0.0;
      return;
    }

    if (_stepBase == null) {
      _pathController.repeat();
      return;
    }

    _pathController.stop();
  }

  void _updatePdrProgressFromSteps(int stepCount) {
    if (_officeActivePath.length < 2) return;
    if (_stepBase == null) {
      _stepBase = stepCount;
      return;
    }
    final stepsTaken = stepCount - _stepBase!;
    if (stepsTaken < 0) return;

    final totalFeet = _officeGraph.calculatePathDistance(_officeActivePath);
    if (totalFeet <= 0) return;

    final walkedFeet = stepsTaken * _stepLengthFeet;
    final progress = (walkedFeet / totalFeet).clamp(0.0, 1.0);

    if (mounted) {
      setState(() {
        _pathProgress = progress;
      });
    }
  }

  void _checkArrival() {
    if (_currentLocation != null &&
        _destination != null &&
        !_hasAnnouncedArrival) {
      double distance = PathEngine.calculateDistance(_currentLocation!.lat,
          _currentLocation!.lng, _destination!.lat, _destination!.lng);
      // Less than 2 meters
      if (distance < 2.0) {
        _hasAnnouncedArrival = true;
        _flutterTts.speak("You have arrived at ${_destination!.name}");
        // Clear path
        setState(() {
          _activePath = [];
          _destination = null;
        });
      }
    }
  }

  void _selectDestination(LocationNode target) {
    setState(() {
      _destination = target;
      _hasAnnouncedArrival = false;
      _stepBase = _lastStepCount;
      _pathProgress = 0.0;
      _updatePath();
      _syncOfficePath();
    });
  }

  OfficeNode? _mapLocationToOfficeNode(LocationNode node) {
    final direct = _officeGraph.nodes[node.id];
    if (direct != null) return direct;

    final normalizedNode = _normalize(node.name);
    for (final officeNode in _officeGraph.nodes.values) {
      if (!officeNode.isRoom) continue;
      final normalizedOffice = _normalize(officeNode.name);
      if (normalizedOffice == normalizedNode) return officeNode;
      if (normalizedOffice.contains(normalizedNode) ||
          normalizedNode.contains(normalizedOffice)) {
        return officeNode;
      }
    }

    return null;
  }

  String _normalize(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }

  String _formatTimestamp(DateTime? timestamp) {
    if (timestamp == null) return '--';
    final time = timestamp;
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    final d = time.day.toString().padLeft(2, '0');
    final mo = time.month.toString().padLeft(2, '0');
    final y = time.year.toString();
    return '$y-$mo-$d $h:$m:$s';
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _compassStream?.cancel();
    _stepStream?.cancel();
    _gyroStream?.cancel();
    _accelStream?.cancel();
    _flutterTts.stop();
    _pathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.background,
                    AppTheme.surfaceContainerLow.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),
            Positioned(
              top: -70,
              left: -40,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  color: AppTheme.secondary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            // Interactive Map
            Positioned.fill(
              child: GestureDetector(
                onLongPress: () {
                  setState(() {
                    _isDebugMode = !_isDebugMode;
                  });
                },
                child: InteractiveViewer(
                  minScale: 0.3,
                  maxScale: 3.0,
                  boundaryMargin: const EdgeInsets.all(400),
                  child: CustomPaint(
                    size: const Size(double.infinity, double.infinity),
                    painter: IndoorMapPainter(
                      allNodes: _officeNodes,
                      activePath: _officeActivePath,
                      currentLocation: _officeCurrent,
                      heading: _gyroHeading,
                      pathProgress:
                          _officeActivePath.length > 1 ? _pathProgress : null,
                    ),
                  ),
                ),
              ),
            ),

            // Floating Top Header
            Positioned(
              top: 16,
              left: 16,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: AppTheme.onSurface),
                onPressed: () => Navigator.pop(context),
              ),
            ),

            Positioned(
              top: 16,
              left: 64,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerLow.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppTheme.outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.gps_fixed,
                        size: 16, color: AppTheme.secondary),
                    const SizedBox(width: 8),
                    Text(
                      'GPS Navigation',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AppTheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
            ),

            // Persistent Logo
            Positioned(
              top: 16,
              right: 16,
              child: Image.network(
                "https://lh3.googleusercontent.com/aida/ADBb0ugDC6rBBRIDKPQl6VtNEIlf3ORtsZuynfWpIS4gBmP770eV1AKkLn5NvN1ido76AoNt6KRRAQhYe4oXjgFl-ttA8AIub3U9iOoQUnz6IjEZmSQcYofUgEPyge0dMGi7p1iwGi2bwCRULoSMUNPV3S6dW3ewe-0yRdrKr1MeAJXKreoke6RXU3_X1vczOug1kg0YXK_NFws3TDgMHMi6QXgFuEO2V4K2ys7ciRcyGl-CfCf2N7iax5CSicg98GjtOPZNZMB995ou",
                width: 50,
                height: 50,
                errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.business,
                    size: 50,
                    color: AppTheme.onSurface),
              ),
            ),

            Positioned(
              top: 74,
              right: 16,
              child: Builder(builder: (context) {
                final lat = _rawPosition?.latitude;
                final lng = _rawPosition?.longitude;
                final time = _rawPosition?.timestamp;
                final latLabel =
                    lat == null ? 'Lat: --' : 'Lat: ${lat.toStringAsFixed(6)}';
                final lngLabel =
                    lng == null ? 'Lng: --' : 'Lng: ${lng.toStringAsFixed(6)}';
                final timeLabel = 'Time: ${_formatTimestamp(time)}';
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainerLow.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      )
                    ],
                  ),
                  child: Text(
                    '$latLabel\n$lngLabel\n$timeLabel',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppTheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                );
              }),
            ),

            // Debug Overlay
            if (_isDebugMode)
              Positioned(
                bottom: 120,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.black54,
                  child: Text(
                    "DEBUG MODE\nLat: ${_rawPosition?.latitude ?? 'N/A'}\nLng: ${_rawPosition?.longitude ?? 'N/A'}\nHeading: ${_heading?.toStringAsFixed(1) ?? 'N/A'}",
                    style: const TextStyle(
                        color: Colors.greenAccent, fontSize: 10),
                  ),
                ),
              ),

            // Navigation Selection / Status Panel
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    )
                  ],
                  border: Border.all(
                    color: AppTheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_destination == null) ...[
                        Text(
                          "Where would you like to go?",
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 16),
                        if (_gpsDestinations.isEmpty)
                          Container(
                            height: 48,
                            width: double.infinity,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Loading destinations...',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: AppTheme.onSurfaceVariant),
                            ),
                          )
                        else
                          SizedBox(
                            height: 48,
                            width: double.infinity,
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<LocationNode>(
                                hint: const Text('Select Destination'),
                                isExpanded: true,
                                dropdownColor: AppTheme.surfaceContainerHighest,
                                icon: const Icon(Icons.arrow_drop_down,
                                    color: AppTheme.primary),
                                style: const TextStyle(
                                    color: AppTheme.onSurface, fontSize: 16),
                                onChanged: (LocationNode? newValue) {
                                  if (newValue != null) {
                                    _selectDestination(newValue);
                                  }
                                },
                                items: _gpsDestinations
                                    .map<DropdownMenuItem<LocationNode>>(
                                        (LocationNode node) {
                                  return DropdownMenuItem<LocationNode>(
                                    value: node,
                                    child: Text(node.name),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                      ] else ...[
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: const BoxDecoration(
                                color: AppTheme.primaryContainer,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.navigation,
                                  color: AppTheme.onPrimaryContainer),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Proceed to ${_destination!.name}",
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(
                                          color: AppTheme.onSurface,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "${_activePath.length - 1 > 0 ? _activePath.length - 1 : 0} nodes away",
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: AppTheme.primary,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close,
                                  color: AppTheme.onSurfaceVariant),
                              onPressed: () {
                                setState(() {
                                  _destination = null;
                                  _activePath = [];
                                });
                              },
                            )
                          ],
                        ),
                      ]
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
