import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:pedometer/pedometer.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/location_node.dart';
import '../../../../core/models/office_node.dart';
import '../../../../core/models/office_graph.dart';
import '../../../../core/models/office_graph_factory.dart';
import '../../../../core/utils/hybrid_path_engine.dart';
import '../../../localization/services/localization_service.dart';
import '../widgets/indoor_map_painter.dart';

class HybridNavigationScreen extends StatefulWidget {
  final String?
      presetSourceLabId; // Optional preset source location from image detection
  final String? initialMode; // 'gps' or 'indoor'

  const HybridNavigationScreen({
    super.key,
    this.presetSourceLabId,
    this.initialMode,
  });

  @override
  State<HybridNavigationScreen> createState() => _HybridNavigationScreenState();
}

class _HybridNavigationScreenState extends State<HybridNavigationScreen>
    with SingleTickerProviderStateMixin {
  // GPS-based navigation
  List<LocationNode> _gpsNodes = [];
  LocationNode? _gpsLocation;
  List<LocationNode> _gpsActivePath = [];

  // Indoor (feet-based) navigation
  late OfficeGraph _officeGraph;
  List<OfficeNode> _indoorNodes = [];
  OfficeNode? _indoorLocation;
  List<OfficeNode> _indoorActivePath = [];

  // Navigation mode
  String _navigationMode = 'indoor'; // 'gps' or 'indoor' (default to indoor)

  // Common state
  double? _heading;
  bool _isDebugMode = false;
  Position? _rawPosition;
  int? _stepBase;
  int? _lastStepCount;
  double _indoorProgress = 0.0;
  bool _useAutoIndoor = true;
  static const double _stepLengthFeet = 2.5;

  // Selected destinations
  dynamic _gpsDestination; // LocationNode
  dynamic _indoorDestination; // OfficeNode

  StreamSubscription<Position>? _positionStream;
  StreamSubscription<CompassEvent>? _compassStream;
  StreamSubscription<StepCount>? _stepStream;
  final FlutterTts _flutterTts = FlutterTts();
  bool _hasAnnouncedArrival = false;
  late AnimationController _pathController;
  double _pathProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _navigationMode = widget.initialMode ?? 'indoor';
    _pathController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..addListener(() {
        if (mounted) {
          if (!_useAutoIndoor) return;
          setState(() {
            _pathProgress = _pathController.value;
          });
        }
      });
    _initData();
    _initTts();
    _initStepTracking();
  }

  Future<void> _initData() async {
    // Initialize indoor graph
    _officeGraph = OfficeGraphFactory.buildGraph();
    const orderedRoomIds = [
      'TIH_Board',
      'Cafeteria',
      'CEO_Room',
      'Meeting_Room',
      'GNSS_Lab',
      'LiDAR_Lab',
      'Computational_Lab',
      'Washrooms',
      'Discussion_Area',
      'GEO_Intel_Lab',
      'Admin_Room',
      'PD_Room',
      'CV_Lab',
      'GIS_Lab',
      'Gym_Room',
    ];

    final orderIndex = <String, int>{
      for (int i = 0; i < orderedRoomIds.length; i++) orderedRoomIds[i]: i
    };

    _indoorNodes =
        _officeGraph.nodes.values.where((node) => node.isRoom).toList()
          ..sort((a, b) {
            final aIndex = orderIndex[a.id] ?? 999;
            final bIndex = orderIndex[b.id] ?? 999;
            return aIndex.compareTo(bIndex);
          });

    // Initialize GPS nodes
    _gpsNodes = await LocationNode.loadNodes();

    // Start compass
    _compassStream = FlutterCompass.events?.listen((event) {
      if (mounted) {
        setState(() {
          _heading = event.heading;
        });
      }
    });

    // Start GPS tracking with error handling
    try {
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 1,
      );

      _positionStream =
          Geolocator.getPositionStream(locationSettings: locationSettings)
              .listen(
        (Position? position) async {
          if (position != null && mounted) {
            _rawPosition = position;

            if (_navigationMode == 'gps') {
              final node = await LocalizationService.estimateFromGps(_gpsNodes);
              if (node != null && node != _gpsLocation) {
                setState(() {
                  _gpsLocation = node;
                  _updateGpsPath();
                  _checkGpsArrival();
                });
              }
            }
          }
        },
        onError: (error) {
          // Handle GPS errors gracefully
          debugPrint('GPS Error: $error');
          // Fall back to indoor mode if GPS fails
          if (mounted) {
            setState(() {
              _navigationMode = 'indoor';
            });
          }
        },
      );

      // Initial GPS location
      _gpsLocation = await LocalizationService.estimateFromGps(_gpsNodes) ??
          _gpsNodes.first;
    } catch (e) {
      // Handle permission errors gracefully
      debugPrint('GPS initialization error: $e');
      // Default to first GPS node if location fails
      _gpsLocation = _gpsNodes.first;
      // Switch to indoor mode by default if GPS fails
      _navigationMode = 'indoor';
    }

    // Set default indoor location
    // Use preset source lab from image detection if provided
    if (widget.presetSourceLabId != null &&
        _officeGraph.nodes.containsKey(widget.presetSourceLabId)) {
      _indoorLocation = _officeGraph.nodes[widget.presetSourceLabId]!;
    } else {
      // Default to TIH Board
      _indoorLocation = _indoorNodes.firstWhere(
        (n) => n.id == 'TIH_Board',
        orElse: () => _indoorNodes.first,
      );
    }

    setState(() {});
  }

  void _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  void _updateGpsPath() {
    if (_gpsLocation != null && _gpsDestination != null) {
      _gpsActivePath = HybridPathEngine.findShortestPathGps(
        _gpsLocation!.id,
        (_gpsDestination as LocationNode).id,
        _gpsNodes,
      );
    } else {
      _gpsActivePath = [];
    }
  }

  void _updateIndoorPath() {
    if (_indoorLocation != null && _indoorDestination != null) {
      _indoorActivePath = HybridPathEngine.findShortestPathIndoor(
        _indoorLocation!.id,
        (_indoorDestination as OfficeNode).id,
        _officeGraph,
      );
      _useAutoIndoor = _stepBase == null;
      _resetIndoorProgress();
      if (_useAutoIndoor) {
        _pathController.repeat();
      }
    } else {
      _indoorActivePath = [];
      _pathController.stop();
      _pathProgress = 0.0;
      _indoorProgress = 0.0;
    }
  }

  void _checkGpsArrival() {
    if (_gpsLocation != null &&
        _gpsDestination != null &&
        !_hasAnnouncedArrival) {
      double distance = HybridPathEngine.calculateGpsDistance(
        _gpsLocation!.lat,
        _gpsLocation!.lng,
        (_gpsDestination as LocationNode).lat,
        (_gpsDestination as LocationNode).lng,
      );
      if (distance < 2.0) {
        _hasAnnouncedArrival = true;
        _flutterTts.speak("You have arrived at ${_gpsDestination!.name}");
        setState(() {
          _gpsActivePath = [];
          _gpsDestination = null;
        });
      }
    }
  }

  void _selectGpsDestination(LocationNode target) {
    setState(() {
      _navigationMode = 'gps';
      _gpsDestination = target;
      _hasAnnouncedArrival = false;
      _updateGpsPath();
    });
  }

  void _selectIndoorDestination(OfficeNode target) {
    setState(() {
      _navigationMode = 'indoor';
      _indoorDestination = target;
      _hasAnnouncedArrival = false;
      _updateIndoorPath();
    });
  }

  void _initStepTracking() {
    _stepStream = Pedometer.stepCountStream.listen(
      (event) {
        _lastStepCount = event.steps;
        if (!mounted) return;
        if (_navigationMode == 'indoor' && _indoorActivePath.length > 1) {
          _updateIndoorProgressFromSteps(event.steps);
        }
      },
      onError: (error) {
        debugPrint('Step tracking error: $error');
      },
    );
  }

  void _resetIndoorProgress() {
    _pathController.stop();
    _indoorProgress = 0.0;
    _pathProgress = 0.0;
    if (_lastStepCount != null) {
      _stepBase = _lastStepCount;
    }
  }

  void _updateIndoorProgressFromSteps(int stepCount) {
    if (_useAutoIndoor) {
      _useAutoIndoor = false;
      _pathController.stop();
    }
    if (_stepBase == null) {
      _stepBase = stepCount;
      return;
    }

    final stepsTaken = stepCount - _stepBase!;
    if (stepsTaken < 0) return;

    final totalFeet = _currentIndoorPathDistanceFeet();
    if (totalFeet <= 0) return;

    final walkedFeet = stepsTaken * _stepLengthFeet;
    final progress = (walkedFeet / totalFeet).clamp(0.0, 1.0);

    setState(() {
      _indoorProgress = progress;
      _pathProgress = progress;
    });

    _checkIndoorArrival();
  }

  double _currentIndoorPathDistanceFeet() {
    if (_indoorActivePath.length < 2) return 0.0;
    return _officeGraph.calculatePathDistance(_indoorActivePath);
  }

  void _checkIndoorArrival() {
    if (_indoorDestination == null || _hasAnnouncedArrival) return;
    if (_indoorProgress < 0.99) return;

    _hasAnnouncedArrival = true;
    _flutterTts.speak(
        "You have arrived at ${(_indoorDestination as OfficeNode).name}");
    setState(() {
      _indoorActivePath = [];
      _indoorDestination = null;
    });
  }

  double? _calculateIndoorDistanceFeet() {
    if (_indoorLocation == null || _indoorDestination == null) return null;

    final startId = _indoorLocation!.id;
    final endId = (_indoorDestination as OfficeNode).id;
    if (startId == endId) return 0.0;

    final override = _distanceOverride(startId, endId);
    if (override != null) return override;

    const verticalAxis = {
      'TIH_Board': -28.0,
      'Cafeteria': -21.0,
      'CEO_Room': -18.0,
      'Meeting_Room': -13.0,
      'GNSS_Lab': -5.0,
      'LiDAR_Lab': 0.0,
      'Computational_Lab': 10.0,
      'Washrooms': 10.0,
    };

    const horizontalAxis = {
      'LiDAR_Lab': 0.0,
      'GEO_Intel_Lab': 20.0,
      'Discussion_Area': 25.0,
      'Admin_Room': 28.0,
      'PD_Room': 30.0,
      'CV_Lab': 33.0,
      'GIS_Lab': 38.0,
      'Gym_Room': 48.0,
    };

    final startOnVertical = verticalAxis.containsKey(startId);
    final endOnVertical = verticalAxis.containsKey(endId);
    final startOnHorizontal = horizontalAxis.containsKey(startId);
    final endOnHorizontal = horizontalAxis.containsKey(endId);

    if (startOnVertical && endOnVertical) {
      return (verticalAxis[startId]! - verticalAxis[endId]!).abs();
    }

    if (startOnHorizontal && endOnHorizontal) {
      return (horizontalAxis[startId]! - horizontalAxis[endId]!).abs();
    }

    if ((startOnVertical && endOnHorizontal) ||
        (startOnHorizontal && endOnVertical)) {
      final verticalId = startOnVertical ? startId : endId;
      final horizontalId = startOnHorizontal ? startId : endId;
      return verticalAxis[verticalId]!.abs() +
          horizontalAxis[horizontalId]!.abs();
    }

    final fallbackPath = _indoorActivePath.isNotEmpty
        ? _indoorActivePath
        : _officeGraph.findShortestPath(startId, endId);
    if (fallbackPath.isEmpty) return null;
    return _officeGraph.calculatePathDistance(fallbackPath);
  }

  double? _distanceOverride(String startId, String endId) {
    const overrides = {
      'Computational_Lab|Washrooms': 5.0,
    };

    final ordered = _orderedPairKey(startId, endId);
    return overrides[ordered];
  }

  String _orderedPairKey(String a, String b) {
    if (a.compareTo(b) <= 0) return '$a|$b';
    return '$b|$a';
  }

  String _formatFeet(double value) {
    final rounded = value.roundToDouble();
    if ((value - rounded).abs() < 0.05) {
      return rounded.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }

  String _formatTimestamp(DateTime? timestamp) {
    final time = timestamp ?? DateTime.now();
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
                      allNodes: _indoorNodes,
                      activePath: _indoorActivePath,
                      currentLocation: _indoorLocation,
                      heading: null,
                      pathProgress: _pathProgress,
                    ),
                  ),
                ),
              ),
            ),

            // Back Button
            Positioned(
              top: 16,
              left: 16,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: AppTheme.onSurface),
                onPressed: () => Navigator.pop(context),
              ),
            ),

            // Logo
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

            // Distance + Location Badge
            Positioned(
              top: 74,
              right: 16,
              child: Builder(builder: (context) {
                final distance = _calculateIndoorDistanceFeet();
                final label = distance == null
                    ? 'Distance: --'
                    : 'Distance: ${_formatFeet(distance)} ft';
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
                    _navigationMode == 'indoor'
                        ? label
                        : '$label\n$latLabel\n$lngLabel\n$timeLabel',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppTheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                );
              }),
            ),

            // Mode Selector removed (direct navigation only)

            // Debug Overlay
            if (_isDebugMode)
              Positioned(
                bottom: 120,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.black54,
                  child: Text(
                    "DEBUG: $_navigationMode\nLat: ${_rawPosition?.latitude ?? 'N/A'}\nLng: ${_rawPosition?.longitude ?? 'N/A'}\nHeading: ${_heading?.toStringAsFixed(1) ?? 'N/A'}",
                    style: const TextStyle(
                        color: Colors.greenAccent, fontSize: 10),
                  ),
                ),
              ),

            // Bottom Navigation Panel
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
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: _navigationMode == 'gps'
                      ? _buildGpsPanel()
                      : _buildIndoorPanel(),
                ),
              ),
            ),

            // Voice Assistant Button removed for direct navigation focus
          ],
        ),
      ),
    );
  }

  Widget _buildGpsPanel() {
    if (_gpsDestination == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "GPS Navigation - Select Destination",
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            width: double.infinity,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<LocationNode>(
                hint: const Text('Select Destination'),
                isExpanded: true,
                dropdownColor: AppTheme.surfaceContainerHighest,
                icon:
                    const Icon(Icons.arrow_drop_down, color: AppTheme.primary),
                style: const TextStyle(color: AppTheme.onSurface, fontSize: 16),
                onChanged: (LocationNode? newValue) {
                  if (newValue != null) {
                    _selectGpsDestination(newValue);
                  }
                },
                items: _gpsNodes.map<DropdownMenuItem<LocationNode>>((node) {
                  return DropdownMenuItem<LocationNode>(
                    value: node,
                    child: Text(node.name),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      );
    } else {
      return Row(
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
                  "Proceed to ${(_gpsDestination as LocationNode).name}",
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppTheme.onSurface,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${_gpsActivePath.length - 1 > 0 ? _gpsActivePath.length - 1 : 0} waypoints",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.primary,
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppTheme.onSurfaceVariant),
            onPressed: () {
              setState(() {
                _gpsDestination = null;
                _gpsActivePath = [];
              });
            },
          )
        ],
      );
    }
  }

  Widget _buildIndoorPanel() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "Direct Navigation",
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 48,
          width: double.infinity,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<OfficeNode>(
              value: _indoorLocation,
              hint: const Text('Select Current Location'),
              isExpanded: true,
              dropdownColor: AppTheme.surfaceContainerHighest,
              icon: const Icon(Icons.arrow_drop_down, color: AppTheme.primary),
              style: const TextStyle(color: AppTheme.onSurface, fontSize: 16),
              onChanged: (OfficeNode? newValue) {
                if (newValue != null) {
                  setState(() {
                    _indoorLocation = newValue;
                    _updateIndoorPath();
                  });
                }
              },
              items: _indoorNodes.map<DropdownMenuItem<OfficeNode>>((node) {
                return DropdownMenuItem<OfficeNode>(
                  value: node,
                  child: Text(node.name),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 48,
          width: double.infinity,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<OfficeNode>(
              value: _indoorDestination as OfficeNode?,
              hint: const Text('Select Destination'),
              isExpanded: true,
              dropdownColor: AppTheme.surfaceContainerHighest,
              icon: const Icon(Icons.arrow_drop_down, color: AppTheme.primary),
              style: const TextStyle(color: AppTheme.onSurface, fontSize: 16),
              onChanged: (OfficeNode? newValue) {
                if (newValue != null) {
                  _selectIndoorDestination(newValue);
                }
              },
              items: _indoorNodes.map<DropdownMenuItem<OfficeNode>>((node) {
                return DropdownMenuItem<OfficeNode>(
                  value: node,
                  child: Text(node.name),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
