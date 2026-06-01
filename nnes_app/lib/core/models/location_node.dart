import 'dart:convert';
import 'package:flutter/services.dart';

class LocationNode {
  final String id;
  final String name;
  final String digiPin;
  final double lat;
  final double lng;
  final List<String> neighborIds;

  LocationNode({
    required this.id,
    required this.name,
    required this.digiPin,
    required this.lat,
    required this.lng,
    required this.neighborIds,
  });

  factory LocationNode.fromJson(Map<String, dynamic> json) {
    return LocationNode(
      id: json['id'],
      name: json['name'],
      digiPin: json['digiPin'],
      lat: json['lat'].toDouble(),
      lng: json['lng'].toDouble(),
      neighborIds: List<String>.from(json['neighborIds']),
    );
  }

  static Future<List<LocationNode>> loadNodes() async {
    final String response = await rootBundle.loadString('assets/data/office_map.json');
    final List<dynamic> data = json.decode(response);
    return data.map((json) => LocationNode.fromJson(json)).toList();
  }
}
