import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/location_node.dart';

class OfficeMapPainter extends CustomPainter {
  final List<LocationNode> allNodes;
  final List<LocationNode>? activePath;
  final LocationNode? currentLocation;
  final double? heading; // Compass heading in radians

  OfficeMapPainter({
    required this.allNodes,
    this.activePath,
    this.currentLocation,
    this.heading,
  });

  /// Convert Geo coordinate to local Canvas coordinate
  Offset geoToCanvas(double lat, double lng) {
    // Anchor LiDAR hook: (13.717465, 79.590786) -> (600, 450)
    double x = 600.0 + (lng - 79.590786) / 0.00001;
    double y = 450.0 - (lat - 13.717465) / 0.00001;
    return Offset(x, y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Center map
    canvas.translate((size.width - 800) / 2, (size.height - 700) / 2);

    final Paint corridorPaint = Paint()
      ..color = AppTheme.surfaceContainerHighest
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final Paint activePathPaint = Paint()
      ..color = AppTheme.primary
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Build coordinate map
    final Map<String, Offset> nodePos = {};
    for (var node in allNodes) {
      nodePos[node.id] = geoToCanvas(node.lat, node.lng);
    }

    // Safely draw corridors
    final Set<String> drawnEdges = {};

    for (var node in allNodes) {
      final p1 = nodePos[node.id]!;
      for (var neighborId in node.neighborIds) {
        final edgeHash = [node.id, neighborId].toList()..sort();
        final edgeKey = edgeHash.join('-');

        if (!drawnEdges.contains(edgeKey) && nodePos.containsKey(neighborId)) {
          final p2 = nodePos[neighborId]!;
          canvas.drawLine(p1, p2, corridorPaint);
          drawnEdges.add(edgeKey);
        }
      }
    }

    // Draw active path if present
    if (activePath != null && activePath!.length > 1) {
      final Path path = Path();
      path.moveTo(
          nodePos[activePath!.first.id]!.dx, nodePos[activePath!.first.id]!.dy);
      for (int i = 1; i < activePath!.length; i++) {
        path.lineTo(
            nodePos[activePath![i].id]!.dx, nodePos[activePath![i].id]!.dy);
      }
      canvas.drawPath(path, activePathPaint);
    }

    final TextPainter textPainter =
        TextPainter(textDirection: TextDirection.ltr);

    // Draw nodes
    for (var node in allNodes) {
      final pos = nodePos[node.id]!;
      bool isTarget = activePath != null &&
          activePath!.isNotEmpty &&
          activePath!.last.id == node.id;
      bool isCurrent = currentLocation?.id == node.id;

      final Paint nodePaint = Paint()
        ..color =
            isTarget ? AppTheme.primaryContainer : AppTheme.surfaceContainerLow
        ..style = PaintingStyle.fill;

      final Paint nodeStrokePaint = Paint()
        ..color =
            (isTarget || isCurrent) ? AppTheme.primary : AppTheme.secondary
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      canvas.drawCircle(pos, 16, nodePaint);
      canvas.drawCircle(pos, 16, nodeStrokePaint);

      textPainter.text = TextSpan(
        text: node.name,
        style: TextStyle(
          color: AppTheme.onSurface,
          fontFamily: 'Inter',
          fontSize: 10,
          fontWeight: isTarget ? FontWeight.bold : FontWeight.normal,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(pos.dx - (textPainter.width / 2), pos.dy + 20),
      );
    }

    // Draw player arrow compass
    if (currentLocation != null) {
      final pos = nodePos[currentLocation!.id]!;
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      if (heading != null) {
        // heading is usually 0 for North. On our map, North is -Y.
        // Let's rotate accordingly. Usually compass gives 0 = North.
        canvas.rotate(heading! * (math.pi / 180));
      }

      final Paint arrowPaint = Paint()..color = AppTheme.primary;
      final Path arrow = Path()
        ..moveTo(0, -15)
        ..lineTo(10, 10)
        ..lineTo(0, 5)
        ..lineTo(-10, 10)
        ..close();

      canvas.drawPath(arrow, arrowPaint);
      canvas.restore();

      // Draw subtle ping radius
      final Paint pulsePaint = Paint()
        ..color = AppTheme.primary.withValues(alpha: 0.3)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, 24, pulsePaint);
    }
  }

  @override
  bool shouldRepaint(covariant OfficeMapPainter oldDelegate) {
    return oldDelegate.currentLocation != currentLocation ||
        oldDelegate.heading != heading ||
        oldDelegate.activePath != activePath;
  }
}
