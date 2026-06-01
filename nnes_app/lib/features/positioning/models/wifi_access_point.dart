class WifiAccessPoint {
  final String ssid;
  final String bssid;
  final int rssi;
  final int? frequency;
  final int? channel;

  const WifiAccessPoint({
    required this.ssid,
    required this.bssid,
    required this.rssi,
    this.frequency,
    this.channel,
  });
}
