import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/office_node.dart';

/// Professional office map painter for tree-like backbone structure
///
/// BACKBONE CORRIDORS:
/// Horizontal Spine: Gym ← GIS ← CV ← PD ← Admin ← GEO ← Discussion
/// Vertical Spine: TIH Board ↓ Cafeteria ↓ CEO ↓ Meeting ↓ GNSS ↓ LiDAR ↓ Washrooms ↓ Computational
///
/// Intersection: Horizontal and Vertical spines meet at right-center (LiDAR area)
/// All rooms branch off main spines with stub corridors
class IndoorMapPainter extends CustomPainter {
  final List<OfficeNode> allNodes;
  final List<OfficeNode>? activePath;
  final OfficeNode? currentLocation;
  final double? heading;
  final double? pathProgress;

  IndoorMapPainter({
    required this.allNodes,
    this.activePath,
    this.currentLocation,
    this.heading,
    this.pathProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Fill background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = AppTheme.background,
    );

    // Draw grid-based map layout
    _drawMapLayout(canvas, size);

    // Draw navigation path if available
    if (activePath != null && activePath!.isNotEmpty) {
      _drawNavigationPath(canvas, size);
    }
  }

  void _drawMapLayout(Canvas canvas, Size size) {
    const roomWidth = 48.0;
    const roomHeight = 26.0;
    const stubLength = 50.0; // Length of stub corridors to rooms

    // Fixed reference layout (matches provided schematic image)
    const refWidth = 1250.0;
    const refHeight = 900.0;
    final scale = min(size.width / refWidth, size.height / refHeight);
    final offsetX = (size.width - refWidth * scale) / 2;
    final offsetY = (size.height - refHeight * scale) / 2;

    Offset s(double x, double y) =>
        Offset(offsetX + x * scale, offsetY + y * scale);

    // Horizontal room X positions
    const gymX = 120.0;
    const gisX = 300.0;
    const cvX = 440.0;
    const pdX = 580.0;
    const adminX = 740.0;
    const geoX = 800.0;
    const discussionX = 900.0;

    // Spine positions
    const horizontalSpineY = 560.0;
    const verticalSpineX = 980.0;
    const horizontalSpineStart = gymX;
    const horizontalSpineEnd = verticalSpineX;

    // Vertical room Y positions
    const tihY = 60.0;
    const cafeY = 170.0;
    const ceoY = cafeY;
    const meetingY = 300.0;
    const gnssY = 420.0;
    const lidarY = horizontalSpineY - roomHeight / 2;
    const washroomsY = 780.0;
    const compY = 780.0;

    // Room positions (branching off spines with stub corridors)
    final roomPositions = <String, Offset>{
      // HORIZONTAL SPINE ROOMS (branching up and down)
      'Gym_Room': s(gymX, horizontalSpineY - stubLength - roomHeight / 2),
      'GIS_Lab': s(gisX, horizontalSpineY - stubLength - roomHeight / 2),
      'CV_Lab': s(cvX, horizontalSpineY + stubLength - roomHeight / 2),
      'PD_Room': s(pdX, horizontalSpineY - stubLength - roomHeight / 2),
      'Admin_Room': s(adminX, horizontalSpineY + stubLength - roomHeight / 2),
      'GEO_Intel_Lab': s(geoX, horizontalSpineY - stubLength - roomHeight / 2),
      'Discussion_Area':
          s(discussionX, horizontalSpineY - stubLength - roomHeight / 2),

      // VERTICAL SPINE ROOMS (branching left and right)
      'TIH_Board': s(verticalSpineX - roomWidth / 2, tihY),
      'Cafeteria': s(verticalSpineX - stubLength - roomWidth, cafeY),
      'CEO_Room': s(verticalSpineX + stubLength - roomWidth / 2, ceoY),
      'Meeting_Room': s(verticalSpineX + stubLength - roomWidth / 2, meetingY),
      'GNSS_Lab': s(verticalSpineX + stubLength - roomWidth / 2, gnssY),
      'LiDAR_Lab': s(verticalSpineX + stubLength - roomWidth / 2, lidarY),
      'Washrooms': s(verticalSpineX - stubLength - roomWidth, washroomsY),
      'Computational_Lab':
          s(verticalSpineX + stubLength - roomWidth / 2, compY),
    };

    // Draw main corridor spines first (thick grey lines)
    final verticalTopY = (tihY + roomHeight / 2) * scale + offsetY;
    _drawMainSpines(
        canvas,
        (horizontalSpineStart + roomWidth / 2) * scale + offsetX,
        horizontalSpineEnd * scale + offsetX,
        horizontalSpineY * scale + offsetY,
        verticalSpineX * scale + offsetX,
        verticalTopY,
        offsetY + (refHeight - 30) * scale);

    // Draw stub corridors connecting rooms to spines
    _drawStubCorridors(
        canvas,
        roomPositions,
        horizontalSpineY * scale + offsetY,
        verticalSpineX * scale + offsetX,
        verticalTopY,
        stubLength * scale,
        roomWidth * scale,
        roomHeight * scale);

    final scaledRoomWidth = roomWidth * scale;
    final scaledRoomHeight = roomHeight * scale;

    // Draw all rooms
    for (var entry in roomPositions.entries) {
      _drawRoom(
          canvas, entry.value, entry.key, scaledRoomWidth, scaledRoomHeight);
    }

    // Draw path + moving arrow
    if (activePath != null && activePath!.length > 1) {
      _drawPathAndArrow(
        canvas,
        roomPositions,
        scaledRoomWidth,
        scaledRoomHeight,
        horizontalSpineY * scale + offsetY,
        verticalSpineX * scale + offsetX,
        verticalTopY,
        stubLength * scale,
      );
    }

    // Draw current location after layout so marker sits above rooms.
    if (currentLocation != null) {
      _drawCurrentLocation(
        canvas,
        roomPositions,
        scaledRoomWidth,
        scaledRoomHeight,
        horizontalSpineY * scale + offsetY,
        verticalSpineX * scale + offsetX,
        verticalTopY,
        stubLength * scale,
      );
    }
  }

  void _drawPathAndArrow(
    Canvas canvas,
    Map<String, Offset> positions,
    double roomWidth,
    double roomHeight,
    double horizontalSpineY,
    double verticalSpineX,
    double verticalSpineTopY,
    double stubLength,
  ) {
    if (activePath == null || activePath!.length < 2) return;

    const horizontalRooms = {
      'Gym_Room',
      'GIS_Lab',
      'CV_Lab',
      'PD_Room',
      'Admin_Room',
      'GEO_Intel_Lab',
      'Discussion_Area',
    };

    const verticalRooms = {
      'TIH_Board',
      'Cafeteria',
      'CEO_Room',
      'Meeting_Room',
      'GNSS_Lab',
      'LiDAR_Lab',
      'Washrooms',
      'Computational_Lab',
    };

    final points = _buildPathPoints(
      positions,
      roomWidth,
      roomHeight,
      horizontalSpineY,
      verticalSpineX,
      verticalSpineTopY,
      stubLength,
      horizontalRooms,
      verticalRooms,
    );
    if (points == null || points.length < 2) return;

    // Arrow moves along existing grey corridors only; no extra path overlay.

    final progress = (pathProgress ?? 0.0).clamp(0.0, 1.0);
    final totalLength = _pathLength(points);
    if (totalLength <= 0) return;

    final targetDistance = totalLength * progress;
    final arrowPos = _pointAtDistance(points, targetDistance);
    final arrowAngle = _angleAtDistance(points, targetDistance);

    _drawCurrentMarker(canvas, arrowPos);
    _drawMovingArrow(canvas, arrowPos, arrowAngle);
  }

  List<Offset>? _buildPathPoints(
    Map<String, Offset> positions,
    double roomWidth,
    double roomHeight,
    double horizontalSpineY,
    double verticalSpineX,
    double verticalSpineTopY,
    double stubLength,
    Set<String> horizontalRooms,
    Set<String> verticalRooms,
  ) {
    if (activePath == null || activePath!.length < 2) return null;

    final startId = activePath!.first.id;
    final endId = activePath!.last.id;
    final startPos = positions[startId];
    final endPos = positions[endId];
    if (startPos == null || endPos == null) return null;

    final startCenter =
        Offset(startPos.dx + roomWidth / 2, startPos.dy + roomHeight / 2);
    final endCenter =
        Offset(endPos.dx + roomWidth / 2, endPos.dy + roomHeight / 2);

    final startPoints = _corridorPointsForRoom(
      startId,
      startCenter,
      horizontalSpineY,
      verticalSpineX,
      verticalSpineTopY,
      horizontalRooms,
      verticalRooms,
      stubLength,
    );
    final endPoints = _corridorPointsForRoom(
      endId,
      endCenter,
      horizontalSpineY,
      verticalSpineX,
      verticalSpineTopY,
      horizontalRooms,
      verticalRooms,
      stubLength,
    );

    final intersection = Offset(verticalSpineX, horizontalSpineY);
    final startOnHorizontal = horizontalRooms.contains(startId);
    final endOnHorizontal = horizontalRooms.contains(endId);
    final startOnVertical = verticalRooms.contains(startId);
    final endOnVertical = verticalRooms.contains(endId);

    final points = <Offset>[startPoints.stubEnd, startPoints.spinePoint];
    if (startOnHorizontal && endOnHorizontal) {
      points.add(endPoints.spinePoint);
      points.add(endPoints.stubEnd);
    } else if (startOnVertical && endOnVertical) {
      points.add(endPoints.spinePoint);
      points.add(endPoints.stubEnd);
    } else {
      points.add(intersection);
      points.add(endPoints.spinePoint);
      points.add(endPoints.stubEnd);
    }

    return points;
  }

  _CorridorPoints _corridorPointsForRoom(
    String roomId,
    Offset center,
    double horizontalSpineY,
    double verticalSpineX,
    double verticalSpineTopY,
    Set<String> horizontalRooms,
    Set<String> verticalRooms,
    double stubLength,
  ) {
    if (horizontalRooms.contains(roomId)) {
      final isBelow = roomId == 'CV_Lab' || roomId == 'Admin_Room';
      final stubY = isBelow
          ? horizontalSpineY + stubLength
          : horizontalSpineY - stubLength;
      final stubEnd = Offset(center.dx, stubY);
      final spinePoint = Offset(center.dx, horizontalSpineY);
      return _CorridorPoints(stubEnd, spinePoint);
    }

    if (verticalRooms.contains(roomId)) {
      if (roomId == 'TIH_Board') {
        final spinePoint = Offset(verticalSpineX, verticalSpineTopY);
        final stubEnd = center;
        return _CorridorPoints(stubEnd, spinePoint);
      }
      final isLeft = roomId == 'Cafeteria' || roomId == 'Washrooms';
      final stubX =
          isLeft ? verticalSpineX - stubLength : verticalSpineX + stubLength;
      final stubEnd = Offset(stubX, center.dy);
      final spinePoint = Offset(verticalSpineX, center.dy);
      return _CorridorPoints(stubEnd, spinePoint);
    }

    return _CorridorPoints(center, center);
  }

  double _pathLength(List<Offset> points) {
    double length = 0.0;
    for (int i = 1; i < points.length; i++) {
      length += (points[i] - points[i - 1]).distance;
    }
    return length;
  }

  Offset _pointAtDistance(List<Offset> points, double distance) {
    double remaining = distance;
    for (int i = 1; i < points.length; i++) {
      final segment = (points[i] - points[i - 1]).distance;
      if (remaining <= segment) {
        final t = segment == 0 ? 0.0 : remaining / segment;
        return Offset(
          points[i - 1].dx + (points[i].dx - points[i - 1].dx) * t,
          points[i - 1].dy + (points[i].dy - points[i - 1].dy) * t,
        );
      }
      remaining -= segment;
    }
    return points.last;
  }

  double _angleAtDistance(List<Offset> points, double distance) {
    double remaining = distance;
    for (int i = 1; i < points.length; i++) {
      final segment = (points[i] - points[i - 1]).distance;
      if (remaining <= segment) {
        final dx = points[i].dx - points[i - 1].dx;
        final dy = points[i].dy - points[i - 1].dy;
        return atan2(dy, dx);
      }
      remaining -= segment;
    }
    final dx = points.last.dx - points[points.length - 2].dx;
    final dy = points.last.dy - points[points.length - 2].dy;
    return atan2(dy, dx);
  }

  void _drawMovingArrow(Canvas canvas, Offset center, double angle) {
    const arrowLength = 14.0;
    const arrowWidth = 10.0;

    final tip = Offset(
      center.dx + arrowLength * cos(angle),
      center.dy + arrowLength * sin(angle),
    );
    final left = Offset(
      center.dx + arrowWidth * cos(angle + pi * 0.75),
      center.dy + arrowWidth * sin(angle + pi * 0.75),
    );
    final right = Offset(
      center.dx + arrowWidth * cos(angle - pi * 0.75),
      center.dy + arrowWidth * sin(angle - pi * 0.75),
    );

    final arrowPath = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy)
      ..close();

    canvas.drawPath(
      arrowPath,
      Paint()
        ..color = AppTheme.secondary
        ..style = PaintingStyle.fill,
    );
  }

  void _drawMainSpines(Canvas canvas, double hStart, double hEnd, double hY,
      double vX, double padding, double vEnd) {
    final spinePaint = Paint()
      ..color = AppTheme.surfaceContainerHighest
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    // Draw horizontal spine (West to East)
    canvas.drawLine(
      Offset(hStart, hY),
      Offset(hEnd, hY),
      spinePaint,
    );

    // Draw vertical spine (North to South)
    canvas.drawLine(
      Offset(vX, padding),
      Offset(vX, vEnd),
      spinePaint,
    );
  }

  void _drawStubCorridors(
    Canvas canvas,
    Map<String, Offset> positions,
    double horizontalSpineY,
    double verticalSpineX,
    double verticalSpineTopY,
    double stubLength,
    double roomWidth,
    double roomHeight,
  ) {
    final stubPaint = Paint()
      ..color = AppTheme.surfaceContainerHighest
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    // Stub corridors for horizontal spine rooms
    final horizontalRooms = [
      'Gym_Room',
      'GIS_Lab',
      'CV_Lab',
      'PD_Room',
      'Admin_Room',
      'GEO_Intel_Lab',
      'Discussion_Area'
    ];

    for (var roomId in horizontalRooms) {
      if (positions.containsKey(roomId)) {
        final pos = positions[roomId]!;
        final isBelow = roomId == 'CV_Lab' || roomId == 'Admin_Room';
        final stubY = isBelow
            ? horizontalSpineY + stubLength
            : horizontalSpineY - stubLength;

        // Draw stub line from spine to room
        canvas.drawLine(
          Offset(pos.dx + roomWidth / 2, horizontalSpineY),
          Offset(pos.dx + roomWidth / 2, stubY),
          stubPaint,
        );
      }
    }

    // Stub corridors for vertical spine rooms
    final verticalRooms = [
      'TIH_Board',
      'Cafeteria',
      'CEO_Room',
      'Meeting_Room',
      'GNSS_Lab',
      'LiDAR_Lab',
      'Washrooms',
      'Computational_Lab'
    ];

    for (var roomId in verticalRooms) {
      if (positions.containsKey(roomId)) {
        final pos = positions[roomId]!;
        if (roomId == 'TIH_Board') {
          final spineX = verticalSpineX;
          final spineY = verticalSpineTopY;
          final roomCenterX = pos.dx + roomWidth / 2;
          final roomCenterY = pos.dy + roomHeight / 2;
          canvas.drawLine(
            Offset(spineX, spineY),
            Offset(roomCenterX, roomCenterY),
            stubPaint,
          );
        } else {
          final isLeft = roomId == 'Cafeteria' || roomId == 'Washrooms';
          final stubX = isLeft
              ? verticalSpineX - stubLength
              : verticalSpineX + stubLength;

          // Determine spine Y for this room
          final spineY = pos.dy + roomHeight / 2;

          // Draw stub line from spine to room
          canvas.drawLine(
            Offset(verticalSpineX, spineY),
            Offset(stubX, spineY),
            stubPaint,
          );
        }
      }
    }
  }

  void _drawRoom(Canvas canvas, Offset position, String roomId, double width,
      double height) {
    final roomRect = Rect.fromLTWH(position.dx, position.dy, width, height);

    // Room border
    canvas.drawRRect(
      RRect.fromRectAndRadius(roomRect, const Radius.circular(4)),
      Paint()
        ..color = AppTheme.primary
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );

    // Room label
    final textPainter = TextPainter(
      text: TextSpan(
        text: _getRoomLabel(roomId),
        style: const TextStyle(
          color: AppTheme.onSurface,
          fontSize: 8,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    final labelOffset =
        _labelOffset(roomId, position, width, height, textPainter);
    textPainter.paint(canvas, labelOffset);
  }

  Offset _labelOffset(String roomId, Offset position, double width,
      double height, TextPainter textPainter) {
    const belowRooms = {
      'CV_Lab',
      'Admin_Room',
      'Washrooms',
      'Computational_Lab',
    };

    const leftRooms = {
      'Cafeteria',
      'Washrooms',
    };

    const rightRooms = {
      'CEO_Room',
      'Meeting_Room',
      'GNSS_Lab',
      'LiDAR_Lab',
      'Computational_Lab',
    };

    final centeredX = position.dx + (width - textPainter.width) / 2;

    if (leftRooms.contains(roomId)) {
      return Offset(position.dx - textPainter.width - 6,
          position.dy + (height - textPainter.height) / 2);
    }

    if (rightRooms.contains(roomId)) {
      return Offset(position.dx + width + 6,
          position.dy + (height - textPainter.height) / 2);
    }

    if (belowRooms.contains(roomId)) {
      return Offset(centeredX, position.dy + height + 6);
    }

    return Offset(centeredX, position.dy - textPainter.height - 10);
  }

  void _drawNavigationPath(Canvas canvas, Size size) {
    if (activePath == null || activePath!.length < 2) return;
    // Navigation path drawing will be implemented with room position mapping
  }

  void _drawCurrentLocation(
    Canvas canvas,
    Map<String, Offset> positions,
    double roomWidth,
    double roomHeight,
    double horizontalSpineY,
    double verticalSpineX,
    double verticalSpineTopY,
    double stubLength,
  ) {
    if (currentLocation == null) return;
    if (activePath != null && activePath!.length > 1 && pathProgress != null) {
      return;
    }

    Offset? center;
    center = _roomCenter(positions, currentLocation!.id, roomWidth, roomHeight);
    if (center == null) return;

    _drawCurrentMarker(canvas, center);

    if (heading != null) {
      _drawHeadingArrow(canvas, center);
    }
  }

  Offset? _roomCenter(
    Map<String, Offset> positions,
    String roomId,
    double roomWidth,
    double roomHeight,
  ) {
    final pos = positions[roomId];
    if (pos == null) return null;
    return Offset(pos.dx + roomWidth / 2, pos.dy + roomHeight / 2);
  }

  void _drawCurrentMarker(Canvas canvas, Offset center) {
    canvas.drawCircle(
      center,
      15,
      Paint()
        ..color = AppTheme.primary.withValues(alpha: 0.3)
        ..style = PaintingStyle.fill,
    );

    canvas.drawCircle(
      center,
      10,
      Paint()
        ..color = AppTheme.primary.withValues(alpha: 0.6)
        ..style = PaintingStyle.fill,
    );

    canvas.drawCircle(
      center,
      6,
      Paint()
        ..color = AppTheme.primary
        ..style = PaintingStyle.fill,
    );
  }

  void _drawHeadingArrow(Canvas canvas, Offset center) {
    final headingRad = _headingToCanvasAngle(heading ?? 0);
    const arrowLength = 14.0;

    final tipX = center.dx + (arrowLength * sin(headingRad));
    final tipY = center.dy - (arrowLength * cos(headingRad));

    const arrowBaseSize = 6.0;
    final baseLeftX = tipX - (arrowBaseSize * cos(headingRad));
    final baseLeftY = tipY - (arrowBaseSize * sin(headingRad));
    final baseRightX = tipX + (arrowBaseSize * cos(headingRad));
    final baseRightY = tipY + (arrowBaseSize * sin(headingRad));

    final arrowPath = Path()
      ..moveTo(tipX, tipY)
      ..lineTo(baseLeftX, baseLeftY)
      ..lineTo(baseRightX, baseRightY)
      ..close();

    canvas.drawPath(
      arrowPath,
      Paint()
        ..color = AppTheme.secondary
        ..style = PaintingStyle.fill,
    );
  }

  double _headingToCanvasAngle(double headingDegrees) {
    return (headingDegrees * pi / 180) - (pi / 2);
  }

  String _getRoomLabel(String roomId) {
    final labels = {
      'TIH_Board': 'TIH\nBoard',
      'Cafeteria': 'Cafeteria',
      'CEO_Room': 'CEO\nRoom',
      'Meeting_Room': 'Meeting\nRoom',
      'Gym_Room': 'Gym',
      'GIS_Lab': 'GIS Lab',
      'GEO_Intel_Lab': 'GEO\nIntel',
      'GNSS_Lab': 'GNSS\nLab',
      'PD_Room': 'PD\nRoom',
      'CV_Lab': 'CV Lab',
      'Admin_Room': 'Admin',
      'LiDAR_Lab': 'LiDAR\nLab',
      'Washrooms': 'Washrooms',
      'Discussion_Area': 'Discussion',
      'Computational_Lab': 'Comp\nLab',
    };
    return labels[roomId] ?? roomId;
  }

  @override
  bool shouldRepaint(IndoorMapPainter oldDelegate) {
    return oldDelegate.activePath != activePath ||
        oldDelegate.currentLocation != currentLocation ||
        oldDelegate.heading != heading ||
        oldDelegate.pathProgress != pathProgress;
  }
}

class _CorridorPoints {
  final Offset stubEnd;
  final Offset spinePoint;

  const _CorridorPoints(this.stubEnd, this.spinePoint);
}
