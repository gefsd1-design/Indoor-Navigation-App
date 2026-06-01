import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../models/visual_marker.dart';

class VisualMarkerScanner extends StatefulWidget {
  final ValueChanged<VisualMarker> onMarker;
  final double scanAreaSize;
  final bool pauseCameraOnDetect;

  const VisualMarkerScanner({
    super.key,
    required this.onMarker,
    this.scanAreaSize = 240,
    this.pauseCameraOnDetect = true,
  });

  @override
  State<VisualMarkerScanner> createState() => _VisualMarkerScannerState();
}

class _VisualMarkerScannerState extends State<VisualMarkerScanner> {
  late final MobileScannerController _controller;
  bool _hasDetected = false;

  @override
  void reassemble() {
    super.reassemble();
    _controller.stop();
    _controller.start();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: (capture) {
            if (_hasDetected && widget.pauseCameraOnDetect) {
              return;
            }
            for (final barcode in capture.barcodes) {
              final payload = barcode.rawValue;
              if (payload == null || payload.isEmpty) {
                continue;
              }
              _hasDetected = true;
              if (widget.pauseCameraOnDetect) {
                _controller.stop();
              }
              widget.onMarker(
                VisualMarker(
                  payload: payload,
                  format: barcode.format.name,
                  timestamp: DateTime.now(),
                ),
              );
              break;
            }
          },
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: Container(
                width: widget.scanAreaSize,
                height: widget.scanAreaSize,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 3,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController();
  }
}
