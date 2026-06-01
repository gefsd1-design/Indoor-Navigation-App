import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/office_graph.dart';
import '../../../../core/models/office_graph_factory.dart';
import '../../../../core/models/office_node.dart';
import '../widgets/indoor_map_painter.dart';
import 'navigation_screen.dart';
import '../../../positioning/models/ble_beacon.dart';
import '../../../positioning/models/dead_reckoning_update.dart';
import '../../../positioning/models/visual_marker.dart';
import '../../../positioning/models/wifi_access_point.dart';
import '../../../positioning/presentation/widgets/visual_marker_scanner.dart';
import '../../../positioning/services/indoor_position_enhancer.dart';

// Hybrid position fields
double? _hybridXFeet;
double? _hybridYFeet;

class AccuracyEnhancementsScreen extends StatefulWidget {
  const AccuracyEnhancementsScreen({super.key});

  @override
  State<AccuracyEnhancementsScreen> createState() =>
      _AccuracyEnhancementsScreenState();
}

class _AccuracyEnhancementsScreenState
    extends State<AccuracyEnhancementsScreen> {
  late final IndoorPositionEnhancer _enhancer;
  StreamSubscription<List<BleBeacon>>? _bleSub;
  StreamSubscription<DeadReckoningUpdate>? _sensorSub;

  bool _enableBle = true;
  bool _enableSensors = true;
  bool _isRunning = false;
  bool _enableWifi = false;
  bool _isWifiScanning = false;

  List<BleBeacon> _beacons = [];
  // Placeholder for Bluetooth devices list (update with real type if available)
  List<dynamic> _bluetoothDevices = [];
  List<WifiAccessPoint> _wifiAccessPoints = [];
  DeadReckoningUpdate? _deadReckoning;
  VisualMarker? _lastMarker;
  double? _headingDeg;

  late final OfficeGraph _officeGraph;
  late final List<OfficeNode> _officeRooms;
  OfficeNode? _anchorRoom;
  OfficeNode? _currentRoom;
  double _estimatedXFeet = 0.0;
  double _estimatedYFeet = 0.0;

  @override
  void initState() {
    super.initState();
    _enhancer = IndoorPositionEnhancer();
    _officeGraph = OfficeGraphFactory.buildGraph();
    _officeRooms =
        _officeGraph.nodes.values.where((node) => node.isRoom).toList();
    _anchorRoom = _officeGraph.nodes['TIH_Board'];
    _currentRoom = _anchorRoom;
    _bleSub = _enhancer.bleScanner.beacons.listen((data) {
      if (!mounted) return;
      setState(() {
        _beacons = data;
        // Optionally, if your BLE scanner exposes all Bluetooth devices, update _bluetoothDevices here.
        // _bluetoothDevices = ...
      });
    });
    _sensorSub = _enhancer.sensorFusion.updates.listen((update) {
      if (!mounted) return;
      setState(() {
        _deadReckoning = update;
        _headingDeg = _radiansToDegrees(update.headingRad);
        _applyDeadReckoning(update);
      });
    });
  }

  void _applyDeadReckoning(DeadReckoningUpdate update) {
    final anchor = _anchorRoom ?? _officeGraph.nodes['TIH_Board'];
    if (anchor == null) return;

    const metersToFeet = 3.28084;
    _estimatedXFeet = anchor.x + (update.xMeters * metersToFeet);
    _estimatedYFeet = anchor.y + (update.yMeters * metersToFeet);
    _currentRoom = _closestRoom(_estimatedXFeet, _estimatedYFeet);

    // Hybrid fusion: weighted average if both BLE and Wi-Fi are enabled and available
    if (_enableBle &&
        _enableWifi &&
        _beacons.isNotEmpty &&
        _wifiAccessPoints.isNotEmpty) {
      // Example: BLE position = _estimatedXFeet/_estimatedYFeet
      // Wi-Fi position: use a dummy offset for Wi-Fi (replace with real mapping if available)
      final wifiX = anchor.x + 5.0; // Dummy offset for Wi-Fi
      final wifiY = anchor.y + 5.0;
      // Weighted average: 60% BLE, 40% Wi-Fi
      _hybridXFeet = 0.6 * _estimatedXFeet + 0.4 * wifiX;
      _hybridYFeet = 0.6 * _estimatedYFeet + 0.4 * wifiY;
    } else {
      _hybridXFeet = null;
      _hybridYFeet = null;
    }
  }

  Future<void> _start() async {
    await _enhancer.start(
      enableBle: _enableBle,
      enableSensors: _enableSensors,
    );

    if (!mounted) return;
    setState(() {
      _isRunning = true;
    });
  }

  Future<void> _stop() async {
    await _enhancer.stop();
    if (!mounted) return;
    setState(() {
      _isRunning = false;
    });
  }

  Future<void> _scanWifi() async {
    setState(() {
      _isWifiScanning = true;
    });
    try {
      final results = await _enhancer.wifiFingerprint.scan();
      if (mounted) {
        setState(() {
          _wifiAccessPoints = results;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isWifiScanning = false;
        });
      }
    }
  }

  // --- Helper methods moved above build ---
  double _radiansToDegrees(double radians) {
    return radians * 180 / 3.1415926535897932;
  }

  OfficeNode? _closestRoom(double xFeet, double yFeet) {
    if (_officeRooms.isEmpty) return null;
    OfficeNode? best;
    double? bestDist;
    for (final room in _officeRooms) {
      final dx = room.x - xFeet;
      final dy = room.y - yFeet;
      final dist = (dx * dx) + (dy * dy);
      if (bestDist == null || dist < bestDist) {
        bestDist = dist;
        best = room;
      }
    }
    return best;
  }

  String _normalize(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildControlsCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          // ...existing code for controls...
        ],
      ),
    );
  }

  Widget _buildBleCard(BuildContext context) {
    return _buildSectionCard(
      context,
      title: 'BLE Beacons & Bluetooth Devices',
      subtitle:
          'BLE beacons and Bluetooth devices are used to improve indoor location accuracy by detecting nearby signals.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_beacons.isEmpty)
            Text('No beacons detected yet.',
                style: Theme.of(context).textTheme.bodySmall),
          if (_beacons.isNotEmpty) ...[
            Text('Nearby BLE Beacons:',
                style: Theme.of(context).textTheme.labelMedium),
            ..._beacons.take(5).map((beacon) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.bluetooth, color: AppTheme.primary),
                  title: Text(beacon.name.isEmpty ? 'Unknown' : beacon.name),
                  subtitle: Text('RSSI: ${beacon.rssi}'),
                  trailing: Text(
                    beacon.id,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                )),
          ],
          if (_bluetoothDevices.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('All Bluetooth Devices:',
                style: Theme.of(context).textTheme.labelMedium),
            ..._bluetoothDevices.take(5).map((device) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.devices, color: AppTheme.primary),
                  title: Text('Unknown Device'),
                  subtitle: Text('Address: --'),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildSensorCard(BuildContext context) {
    return _buildSectionCard(
      context,
      title: 'Sensor Fusion',
      subtitle:
          'Combines motion sensors for step counting and heading estimation.',
      child: _deadReckoning == null
          ? Text('No sensor data yet.',
              style: Theme.of(context).textTheme.bodySmall)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Steps: ${_deadReckoning!.steps}'),
                Text('Heading: ${_headingDeg?.toStringAsFixed(1) ?? '--'}°'),
                Text('ΔX: ${_deadReckoning!.xMeters.toStringAsFixed(2)} m'),
                Text('ΔY: ${_deadReckoning!.yMeters.toStringAsFixed(2)} m'),
              ],
            ),
    );
  }

  // --- Main build method ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Accuracy Enhancements'),
        backgroundColor: AppTheme.primaryContainer,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildDescriptionCard(context),
          const SizedBox(height: 12),
          _buildActiveSummaryCard(context),
          const SizedBox(height: 12),
          _buildMapCard(context),
          const SizedBox(height: 16),
          _buildStatusCard(context),
          const SizedBox(height: 16),
          _buildControlsCard(context),
          const SizedBox(height: 16),
          _buildBleCard(context),
          const SizedBox(height: 16),
          _buildSensorCard(context),
        ],
      ),
    );
  }

  Widget _buildDescriptionCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Improve your indoor location accuracy using BLE beacons, Wi-Fi fingerprinting, and motion sensors. Enable the enhancements you want, then tap Start. Your estimated position will update live on the map.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSummaryCard(BuildContext context) {
    final active = <String>[];
    if (_isRunning && _enableBle) active.add('BLE');
    if (_isRunning && _enableWifi) active.add('Wi-Fi');
    if (_isRunning && _enableSensors) active.add('Sensors');
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(_isRunning ? Icons.check_circle : Icons.pause_circle_filled,
              color: _isRunning ? Colors.green : Colors.orange, size: 22),
          const SizedBox(width: 8),
          Text(
            _isRunning
                ? 'Running: ${active.isEmpty ? 'None' : active.join(", ")}'
                : 'Stopped',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const Spacer(),
          if (_isRunning &&
              (_beacons.isNotEmpty || _wifiAccessPoints.isNotEmpty))
            Text(
              'Beacons: ${_beacons.length}  Wi-Fi: ${_wifiAccessPoints.length}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }

  Widget _buildMapCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Live Indoor Map',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            _currentRoom == null
                ? 'Scan a marker or walk to estimate a room.'
                : 'Estimated room: ${_currentRoom!.name}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 320,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: InteractiveViewer(
                boundaryMargin: const EdgeInsets.all(40),
                minScale: 0.7,
                maxScale: 3.0,
                child: CustomPaint(
                  painter: IndoorMapPainter(
                    allNodes: _officeRooms,
                    activePath: null,
                    currentLocation: _currentRoom,
                    heading: _headingDeg,
                    pathProgress: 1.0,
                  ),
                  child: const SizedBox(
                    width: 1100,
                    height: 820,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Accuracy Enhancements',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Run BLE, Wi-Fi, sensors, and QR markers alongside GPS to improve indoor positioning without changing existing navigation logic.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.wifi),
            label: const Text('Show Available Wi-Fi'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              await _scanWifi();
              if (!mounted) return;
              showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: const Text('Available Wi-Fi'),
                    content: SizedBox(
                      width: 320,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Wi-Fi Access Points:',
                                style: Theme.of(context).textTheme.labelMedium),
                            if (_wifiAccessPoints.isEmpty)
                              const Text('No Wi-Fi access points found.'),
                            ..._wifiAccessPoints.map((ap) => ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.wifi,
                                      color: Colors.blue),
                                  title: Text(
                                      ap.ssid.isEmpty ? 'Unknown' : ap.ssid),
                                  subtitle: Text('RSSI: ${ap.rssi}'),
                                )),
                          ],
                        ),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close'),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.bluetooth),
            label: const Text('Show Available BLE'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: const Text('Available BLE'),
                    content: SizedBox(
                      width: 320,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('BLE Beacons:',
                                style: Theme.of(context).textTheme.labelMedium),
                            if (_beacons.isEmpty)
                              const Text('No BLE beacons found.'),
                            ..._beacons.map((beacon) => ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.bluetooth,
                                      color: Colors.indigo),
                                  title: Text(beacon.name.isEmpty
                                      ? 'Unknown'
                                      : beacon.name),
                                  subtitle: Text('RSSI: ${beacon.rssi}'),
                                  trailing: Text(beacon.id,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall),
                                )),
                          ],
                        ),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close'),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
