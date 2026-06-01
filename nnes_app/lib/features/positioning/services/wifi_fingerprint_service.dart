import 'package:wifi_scan/wifi_scan.dart';

import '../models/wifi_access_point.dart';

class WifiFingerprintService {
  Future<List<WifiAccessPoint>> scan() async {
    final canScan = await WiFiScan.instance.canStartScan();
    if (canScan != CanStartScan.yes) {
      return [];
    }

    await WiFiScan.instance.startScan();
    final results = await WiFiScan.instance.getScannedResults();
    return results
        .map(
          (result) => WifiAccessPoint(
            ssid: result.ssid,
            bssid: result.bssid,
            rssi: result.level,
            frequency: result.frequency,
            channel: result.channelWidth?.index,
          ),
        )
        .toList(growable: false);
  }
}
