class BleBeacon {
  final String id;
  final String name;
  final int rssi;
  final DateTime lastSeen;

  const BleBeacon({
    required this.id,
    required this.name,
    required this.rssi,
    required this.lastSeen,
  });
}
