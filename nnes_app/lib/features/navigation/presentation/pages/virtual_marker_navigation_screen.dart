import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../../../core/models/office_graph.dart';
import '../../../../core/models/office_graph_factory.dart';
import '../../../../core/models/office_node.dart';
import '../../../../core/theme/app_theme.dart';
import '../widgets/indoor_map_painter.dart';
import '../../../positioning/models/visual_marker.dart';
import '../../../positioning/presentation/widgets/visual_marker_scanner.dart';

class VirtualMarkerNavigationScreen extends StatefulWidget {
  const VirtualMarkerNavigationScreen({super.key});

  @override
  State<VirtualMarkerNavigationScreen> createState() =>
      _VirtualMarkerNavigationScreenState();
}

class _VirtualMarkerNavigationScreenState
    extends State<VirtualMarkerNavigationScreen> {
  final FlutterTts _tts = FlutterTts();
  late final OfficeGraph _graph;
  late final List<OfficeNode> _rooms;
  OfficeNode? _currentRoom;
  OfficeNode? _destinationRoom;
  List<OfficeNode> _activePath = [];
  List<String> _directions = [];
  double _pathProgress = 0.0;
  bool _isSpeaking = false;
  final List<VisualMarker> _recentMarkers = [];

  @override
  void initState() {
    super.initState();
    _graph = OfficeGraphFactory.buildGraph();
    _rooms = _graph.nodes.values.where((node) => node.isRoom).toList();
    _currentRoom = _graph.nodes['TIH_Board'];
  }

  void _openScanner() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.78,
        child: VisualMarkerScanner(
          onMarker: (marker) {
            setState(() {
              _recentMarkers.insert(0, marker);
              _currentRoom = _resolveRoom(marker.payload) ?? _currentRoom;
              _updatePath();
            });
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  void _updatePath() {
    if (_currentRoom == null || _destinationRoom == null) {
      _activePath = [];
      _directions = [];
      _pathProgress = 0.0;
      return;
    }
    _activePath = _graph.findShortestPath(
      _currentRoom!.id,
      _destinationRoom!.id,
    );
    _directions = _graph.generateDirections(_activePath);
    _pathProgress = 0.0;
    if (_directions.isNotEmpty) {
      _speakDirections();
    }
    // Animate arrow to destination
    _animateArrowToDestination();
  }

  Future<void> _speakDirections() async {
    if (_isSpeaking) return;
    _isSpeaking = true;
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
    await _tts.speak(_directions.take(6).join('. '));
    _isSpeaking = false;
  }

  void _animateArrowToDestination() async {
    if (_activePath.length < 2) return;
    for (int i = 0; i <= 20; i++) {
      await Future.delayed(const Duration(milliseconds: 40));
      setState(() {
        _pathProgress = i / 20.0;
      });
    }
    setState(() {
      _pathProgress = 1.0;
    });
  }

  OfficeNode? _resolveRoom(String payload) {
    final direct = _graph.nodes[payload];
    if (direct != null && direct.isRoom) return direct;

    final normalized = _normalize(payload);
    for (final node in _graph.nodes.values) {
      if (!node.isRoom) continue;
      final name = _normalize(node.name);
      if (name == normalized ||
          name.contains(normalized) ||
          normalized.contains(name)) {
        return node;
      }
    }
    return null;
  }

  String _normalize(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Virtual Marker Navigation'),
        backgroundColor: AppTheme.primaryContainer,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeroCard(context),
          const SizedBox(height: 16),
          _buildDestinationCard(context),
          const SizedBox(height: 16),
          _buildMapCard(context),
          const SizedBox(height: 16),
          _buildDirectionsCard(context),
          const SizedBox(height: 16),
          _buildRecentMarkersCard(context),
        ],
      ),
    );
  }

  Widget _buildDestinationCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Destination',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            _currentRoom == null
                ? 'Scan a marker first to set your start location.'
                : 'Start: ${_currentRoom!.name}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            width: double.infinity,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<OfficeNode>(
                hint: const Text('Select Destination'),
                isExpanded: true,
                value: _destinationRoom,
                dropdownColor: AppTheme.surfaceContainerHighest,
                icon:
                    const Icon(Icons.arrow_drop_down, color: AppTheme.primary),
                style: const TextStyle(color: AppTheme.onSurface, fontSize: 16),
                onChanged: (OfficeNode? newValue) {
                  setState(() {
                    _destinationRoom = newValue;
                    _updatePath();
                  });
                },
                items:
                    _rooms.map<DropdownMenuItem<OfficeNode>>((OfficeNode node) {
                  return DropdownMenuItem<OfficeNode>(
                    value: node,
                    child: Text(node.name),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _destinationRoom == null
                      ? null
                      : () {
                          setState(() {
                            _destinationRoom = null;
                            _activePath = [];
                            _directions = [];
                          });
                        },
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear Destination'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryContainer,
            AppTheme.primaryContainer.withValues(alpha: 0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.primaryContainer,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withOpacity(0.4),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                  border: Border.all(color: AppTheme.primary, width: 2),
                ),
                child: Icon(
                  Icons.qr_code_scanner,
                  color: AppTheme.primary,
                  size: 40,
                  shadows: const [
                    Shadow(
                      color: Colors.black26,
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Scan a QR marker to lock your room instantly.',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Explanation removed as per user request
          SizedBox(
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.25),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
                border: Border.all(
                  color: AppTheme.primary,
                  width: 2,
                ),
              ),
              child: ElevatedButton.icon(
                onPressed: _openScanner,
                icon: Icon(Icons.center_focus_strong,
                    color: AppTheme.primaryContainer),
                label: Text(
                  'Scan Marker',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Color(0xFF8C151B), // Maroon
                    letterSpacing: 1.1,
                    shadows: const [
                      Shadow(
                        color: Colors.black26,
                        blurRadius: 2,
                        offset: Offset(1, 1),
                      ),
                    ],
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: AppTheme.onPrimaryContainer,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
              ),
            ),
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
        border:
            Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.5)),
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
                ? 'Scan a marker to anchor your position.'
                : 'Anchored at: ${_currentRoom!.name}',
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
                    allNodes: _rooms,
                    activePath: _activePath.isEmpty ? null : _activePath,
                    currentLocation: _currentRoom,
                    heading: null,
                    pathProgress: _activePath.isNotEmpty ? _pathProgress : null,
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

  Widget _buildDirectionsCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Route Steps',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          if (_directions.isEmpty)
            Text(
              'Pick a destination to see directions.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppTheme.onSurfaceVariant),
            )
          else
            ..._directions.take(6).map(
                  (step) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading:
                        const Icon(Icons.turn_right, color: AppTheme.secondary),
                    title: Text(step),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildRecentMarkersCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Markers',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          if (_recentMarkers.isEmpty)
            Text(
              'No markers scanned yet.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppTheme.onSurfaceVariant),
            )
          else
            ..._recentMarkers.take(4).map(
                  (marker) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading:
                        const Icon(Icons.location_pin, color: AppTheme.primary),
                    title: Text(marker.payload),
                    subtitle: Text(
                      '${marker.format} • ${marker.timestamp.hour.toString().padLeft(2, '0')}:${marker.timestamp.minute.toString().padLeft(2, '0')}',
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}
