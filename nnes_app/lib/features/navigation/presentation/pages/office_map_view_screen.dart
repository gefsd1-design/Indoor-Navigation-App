import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/office_graph_factory.dart';
import '../widgets/indoor_map_painter.dart';

class OfficeMapViewScreen extends StatefulWidget {
  const OfficeMapViewScreen({super.key});

  @override
  State<OfficeMapViewScreen> createState() => _OfficeMapViewScreenState();
}

class _OfficeMapViewScreenState extends State<OfficeMapViewScreen> {
  late final _graph = OfficeGraphFactory.buildGraph();
  late final _nodes = _graph.nodes.values.toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Office Map'),
        backgroundColor: AppTheme.primaryContainer,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        color: AppTheme.surface,
        child: InteractiveViewer(
          boundaryMargin: const EdgeInsets.all(40),
          minScale: 0.7,
          maxScale: 3.0,
          child: CustomPaint(
            painter: IndoorMapPainter(
              allNodes: _nodes,
              activePath: null,
              currentLocation: null,
              heading: null,
            ),
            child: const SizedBox(
              width: 1100,
              height: 820,
            ),
          ),
        ),
      ),
    );
  }
}
