import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../est_location/models/estimated_location.dart';
import '../../../est_location/services/location_estimation_service.dart';

class EstLocationScreen extends StatefulWidget {
  const EstLocationScreen({super.key});

  @override
  State<EstLocationScreen> createState() => _EstLocationScreenState();
}

class _EstLocationScreenState extends State<EstLocationScreen> {
  late LocationEstimationService _estimationService;
  EstimatedLocation? _currentLocation;
  String _statusMessage = 'Initializing...';
  List<EstimatedLocation> _locationHistory = [];
  bool _isTracking = false;

  @override
  void initState() {
    super.initState();
    _estimationService = LocationEstimationService();
    _initializeService();
  }

  Future<void> _initializeService() async {
    try {
      await _estimationService.initialize();

      // Listen to location updates
      _estimationService.locationStream.listen((location) {
        if (!mounted) return;
        setState(() {
          _currentLocation = location;
          _locationHistory.add(location);
          // Keep only last 100 readings
          if (_locationHistory.length > 100) {
            _locationHistory.removeAt(0);
          }
        });
      });

      // Listen to status updates
      _estimationService.statusStream.listen((status) {
        if (!mounted) return;
        setState(() {
          _statusMessage = status;
        });
      });

      setState(() {
        _isTracking = true;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Error: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _estimationService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Estimated Location'),
        backgroundColor: AppTheme.primaryContainer,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStatusCard(context),
          const SizedBox(height: 16),
          _buildCurrentLocationCard(context),
          const SizedBox(height: 16),
          _buildSensorDataCard(context),
          const SizedBox(height: 16),
          _buildHistoryCard(context),
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
            'Estimated Location Tracking',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'This domain estimates your location when GPS signal is weak. It uses sensors (accelerometer, gyroscope) and motion data to continue tracking your position.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  _isTracking ? Icons.check_circle : Icons.pause_circle_filled,
                  color: _isTracking ? Colors.green : Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _statusMessage,
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentLocationCard(BuildContext context) {
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
            'Current Location',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          if (_currentLocation == null)
            Text(
              'Waiting for GPS location...',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.onSurfaceVariant,
                  ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLocationField(
                  'Latitude',
                  _currentLocation!.latitude.toStringAsFixed(6),
                  context,
                ),
                const SizedBox(height: 8),
                _buildLocationField(
                  'Longitude',
                  _currentLocation!.longitude.toStringAsFixed(6),
                  context,
                ),
                const SizedBox(height: 8),
                _buildLocationField(
                  'Timestamp',
                  _currentLocation!.timestamp.toString().split('.')[0],
                  context,
                ),
                const SizedBox(height: 8),
                _buildLocationField(
                  'Status',
                  _currentLocation!.isEstimated
                      ? 'Estimated (${_currentLocation!.estimateCount}/${_currentLocation!.maxEstimates})'
                      : 'Valid GPS',
                  context,
                  _currentLocation!.isEstimated ? Colors.orange : Colors.green,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildLocationField(String label, String value, BuildContext context,
      [Color? labelColor]) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            '$label:',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: labelColor,
                ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildSensorDataCard(BuildContext context) {
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
            'Motion & Sensor Data',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          if (_currentLocation == null)
            Text(
              'Waiting for sensor data...',
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLocationField(
                  'Velocity',
                  '${_currentLocation!.velocity?.toStringAsFixed(2) ?? '--'} m/s',
                  context,
                ),
                const SizedBox(height: 8),
                _buildLocationField(
                  'Acceleration',
                  '${_currentLocation!.acceleration?.toStringAsFixed(2) ?? '--'} m/s²',
                  context,
                ),
                const SizedBox(height: 8),
                _buildLocationField(
                  'Direction',
                  '${_currentLocation!.direction?.toStringAsFixed(1) ?? '--'}°',
                  context,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context) {
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
            'Location History (Last ${_locationHistory.length})',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          if (_locationHistory.isEmpty)
            Text(
              'No location history yet',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.onSurfaceVariant,
                  ),
            )
          else
            SizedBox(
              height: 200,
              child: ListView.builder(
                itemCount: _locationHistory.length,
                itemBuilder: (context, index) {
                  final location =
                      _locationHistory[_locationHistory.length - 1 - index];
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      location.isEstimated ? Icons.navigation : Icons.gps_fixed,
                      color:
                          location.isEstimated ? Colors.orange : Colors.green,
                      size: 18,
                    ),
                    title: Text(
                      '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    subtitle: Text(
                      location.timestamp.toString().split('.')[0],
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontSize: 10,
                          ),
                    ),
                    trailing: Text(
                      location.isEstimated ? 'EST' : 'GPS',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: location.isEstimated
                                ? Colors.orange
                                : Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
