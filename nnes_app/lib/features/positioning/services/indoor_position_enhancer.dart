import 'ble_scanner_service.dart';
import 'sensor_fusion_service.dart';
import 'wifi_fingerprint_service.dart';

class IndoorPositionEnhancer {
  final BleScannerService bleScanner;
  final SensorFusionService sensorFusion;
  final WifiFingerprintService wifiFingerprint;

  IndoorPositionEnhancer({
    BleScannerService? bleScanner,
    SensorFusionService? sensorFusion,
    WifiFingerprintService? wifiFingerprint,
  })  : bleScanner = bleScanner ?? BleScannerService(),
        sensorFusion = sensorFusion ?? SensorFusionService(),
        wifiFingerprint = wifiFingerprint ?? WifiFingerprintService();

  Future<void> start({
    bool enableBle = true,
    bool enableSensors = true,
  }) async {
    if (enableBle) {
      await bleScanner.startScan();
    }
    if (enableSensors) {
      sensorFusion.start();
    }
  }

  Future<void> stop() async {
    await bleScanner.stopScan();
    sensorFusion.stop();
  }

  void dispose() {
    bleScanner.dispose();
    sensorFusion.dispose();
  }
}
