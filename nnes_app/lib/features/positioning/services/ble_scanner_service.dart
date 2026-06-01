import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models/ble_beacon.dart';

class BleScannerService {
  StreamSubscription<List<ScanResult>>? _scanSub;
  final StreamController<List<BleBeacon>> _beaconController =
      StreamController.broadcast();

  BleScannerService();

  Stream<List<BleBeacon>> get beacons => _beaconController.stream;

  Future<bool> startScan(
      {Duration timeout = const Duration(seconds: 6)}) async {
    try {
      final isAvailable = await FlutterBluePlus.isAvailable;
      final isOn = await FlutterBluePlus.isOn;
      if (!isAvailable || !isOn) {
        return false;
      }

      await _scanSub?.cancel();
      _scanSub = FlutterBluePlus.scanResults.listen((results) {
        final now = DateTime.now();
        final mapped = results
            .map(
              (result) => BleBeacon(
                id: result.device.id.id,
                name: result.device.name.isNotEmpty
                    ? result.device.name
                    : result.device.id.id,
                rssi: result.rssi,
                lastSeen: now,
              ),
            )
            .toList(growable: false);
        _beaconController.add(mapped);
      });

      await FlutterBluePlus.startScan(timeout: timeout);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    await _scanSub?.cancel();
    _scanSub = null;
  }

  void dispose() {
    _scanSub?.cancel();
    _beaconController.close();
  }
}
