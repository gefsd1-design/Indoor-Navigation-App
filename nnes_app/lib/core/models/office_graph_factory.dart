import 'office_node.dart';
import 'office_graph.dart';
import 'office_edge.dart';

/// Factory class to build the hardcoded office graph
/// Layout matches the provided office diagram:
/// - TIH Board at top center (0, 0)
/// - Left side: Gym Room, GIS Lab, CV Lab
/// - Center: Cafeteria, PD Room, Admin Room
/// - Right side: CEO Room, Meeting Room, GNSS Lab, LiDAR Lab, Computational Lab
/// - Bottom: Washrooms, Discussion Area
class OfficeGraphFactory {
  // Origin is at TIH Board (0, 0) - top center

  /// Create the complete office graph with all nodes and edges
  static OfficeGraph buildGraph() {
    final nodes = _createNodes();
    final adjacencyList = _createAdjacencyList(nodes);

    return OfficeGraph(
      nodes: nodes,
      adjacencyList: adjacencyList,
    );
  }

  /// Create all office nodes with feet-based coordinates
  /// Origin (0,0) is at TIH Board (top-center)
  /// X-axis: negative = left, positive = right
  /// Y-axis: negative = up, positive = down
  static Map<String, OfficeNode> _createNodes() {
    return {
      // TOP TIER: TIH Board (entry point)
      'TIH_Board': OfficeNode(
        id: 'TIH_Board',
        name: 'TIH Board',
        x: 0,
        y: 0,
        isRoom: true,
      ),

      // TIER 2: Main Corridors & Junctions below TIH Board
      'Main_Corridor_J1': OfficeNode(
        id: 'Main_Corridor_J1',
        name: 'Main Corridor',
        x: 0,
        y: 8,
        isRoom: false,
        adjacentNodeIds: ['TIH_Board', 'CEO_Wing_J', 'Cafeteria_J'],
      ),

      // RIGHT WING: CEO & Meeting Rooms
      'CEO_Wing_J': OfficeNode(
        id: 'CEO_Wing_J',
        name: 'CEO Wing Junction',
        x: 15,
        y: 8,
        isRoom: false,
        adjacentNodeIds: ['Main_Corridor_J1', 'CEO_Room', 'Meeting_Room'],
      ),
      'CEO_Room': OfficeNode(
        id: 'CEO_Room',
        name: 'CEO Room',
        x: 20,
        y: 4,
        isRoom: true,
        adjacentNodeIds: ['CEO_Wing_J'],
      ),
      'Meeting_Room': OfficeNode(
        id: 'Meeting_Room',
        name: 'Meeting Room',
        x: 20,
        y: 12,
        isRoom: true,
        adjacentNodeIds: ['CEO_Wing_J'],
      ),

      // CENTER: Cafeteria
      'Cafeteria_J': OfficeNode(
        id: 'Cafeteria_J',
        name: 'Cafeteria Junction',
        x: 0,
        y: 16,
        isRoom: false,
        adjacentNodeIds: ['Main_Corridor_J1', 'Cafeteria', 'Lab_Corridor_J'],
      ),
      'Cafeteria': OfficeNode(
        id: 'Cafeteria',
        name: 'Cafeteria',
        x: -6,
        y: 16,
        isRoom: true,
        adjacentNodeIds: ['Cafeteria_J'],
      ),

      // LAB CORRIDOR: GNSS, LiDAR, Computational
      'Lab_Corridor_J': OfficeNode(
        id: 'Lab_Corridor_J',
        name: 'Lab Corridor',
        x: 0,
        y: 24,
        isRoom: false,
        adjacentNodeIds: [
          'Cafeteria_J',
          'GNSS_Lab',
          'LiDAR_Lab',
          'Lab_Section_J'
        ],
      ),
      'GNSS_Lab': OfficeNode(
        id: 'GNSS_Lab',
        name: 'GNSS Lab',
        x: -8,
        y: 24,
        isRoom: true,
        adjacentNodeIds: ['Lab_Corridor_J'],
      ),
      'LiDAR_Lab': OfficeNode(
        id: 'LiDAR_Lab',
        name: 'LiDAR Lab',
        x: 8,
        y: 24,
        isRoom: true,
        adjacentNodeIds: ['Lab_Corridor_J'],
      ),
      'Lab_Section_J': OfficeNode(
        id: 'Lab_Section_J',
        name: 'Lab Section Junction',
        x: 20,
        y: 24,
        isRoom: false,
        adjacentNodeIds: ['Lab_Corridor_J', 'Computational_Lab'],
      ),
      'Computational_Lab': OfficeNode(
        id: 'Computational_Lab',
        name: 'Computational Lab',
        x: 28,
        y: 24,
        isRoom: true,
        adjacentNodeIds: ['Lab_Section_J'],
      ),

      // LEFT SIDE: Gym, GIS Lab
      'Gym_Room': OfficeNode(
        id: 'Gym_Room',
        name: 'Gym Room',
        x: -20,
        y: 12,
        isRoom: true,
        adjacentNodeIds: ['Left_Corridor_J'],
      ),
      'Left_Corridor_J': OfficeNode(
        id: 'Left_Corridor_J',
        name: 'Left Corridor Junction',
        x: -15,
        y: 16,
        isRoom: false,
        adjacentNodeIds: ['Gym_Room', 'GIS_Lab', 'Main_Corridor_J1'],
      ),
      'GIS_Lab': OfficeNode(
        id: 'GIS_Lab',
        name: 'GIS Lab',
        x: -20,
        y: 20,
        isRoom: true,
        adjacentNodeIds: ['Left_Corridor_J'],
      ),

      // CENTER-BOTTOM: PD Room, CV Lab, Admin
      'PD_Room': OfficeNode(
        id: 'PD_Room',
        name: 'PD Room',
        x: -5,
        y: 32,
        isRoom: true,
        adjacentNodeIds: ['Bottom_Corridor_J'],
      ),
      'Bottom_Corridor_J': OfficeNode(
        id: 'Bottom_Corridor_J',
        name: 'Bottom Corridor',
        x: 0,
        y: 32,
        isRoom: false,
        adjacentNodeIds: ['Lab_Corridor_J', 'PD_Room', 'CV_Lab', 'Admin_Room'],
      ),
      'CV_Lab': OfficeNode(
        id: 'CV_Lab',
        name: 'CV Lab',
        x: 0,
        y: 40,
        isRoom: true,
        adjacentNodeIds: ['Bottom_Corridor_J'],
      ),
      'Admin_Room': OfficeNode(
        id: 'Admin_Room',
        name: 'Administrative Room',
        x: 8,
        y: 32,
        isRoom: true,
        adjacentNodeIds: ['Bottom_Corridor_J'],
      ),

      // RIGHT-CENTER: GEO Intel Lab, Discussion Area
      'GEO_Intel_Lab': OfficeNode(
        id: 'GEO_Intel_Lab',
        name: 'GEO Intel Lab',
        x: 15,
        y: 20,
        isRoom: true,
        adjacentNodeIds: ['Lab_Corridor_J'],
      ),
      'Discussion_Area': OfficeNode(
        id: 'Discussion_Area',
        name: 'Discussion Area',
        x: 20,
        y: 32,
        isRoom: true,
        adjacentNodeIds: ['Bottom_Corridor_J'],
      ),

      // BOTTOM: Washrooms
      'Washrooms': OfficeNode(
        id: 'Washrooms',
        name: 'Washrooms',
        x: 8,
        y: 40,
        isRoom: true,
        adjacentNodeIds: ['Bottom_Corridor_J'],
      ),
    };
  }

  /// Create adjacency list with edges including directions
  static Map<String, List<Edge>> _createAdjacencyList(
      Map<String, OfficeNode> nodes) {
    final adjacencyList = <String, List<Edge>>{};

    // Initialize empty lists for all nodes
    for (var nodeId in nodes.keys) {
      adjacencyList[nodeId] = [];
    }

    // Helper function to add bidirectional edges
    void addBiEdge(
        String nodeId1, String nodeId2, String direction1, String direction2) {
      final node1 = nodes[nodeId1]!;
      final node2 = nodes[nodeId2]!;
      final distance = node1.distanceTo(node2);

      adjacencyList[nodeId1]!.add(
        Edge(
          fromNodeId: nodeId1,
          toNodeId: nodeId2,
          distance: distance,
          direction: direction1,
        ),
      );

      adjacencyList[nodeId2]!.add(
        Edge(
          fromNodeId: nodeId2,
          toNodeId: nodeId1,
          distance: distance,
          direction: direction2,
        ),
      );
    }

    // MAIN VERTICAL SPINE
    addBiEdge('TIH_Board', 'Main_Corridor_J1', 'Head south down main corridor',
        'Head north to TIH Board');
    addBiEdge('Main_Corridor_J1', 'Cafeteria_J', 'Continue south',
        'Head north to main corridor');
    addBiEdge('Cafeteria_J', 'Lab_Corridor_J', 'Continue south to lab corridor',
        'Head north to cafeteria');
    addBiEdge('Lab_Corridor_J', 'Bottom_Corridor_J', 'Continue south',
        'Head north to lab corridor');

    // RIGHT WING: CEO & Meeting Rooms
    addBiEdge('Main_Corridor_J1', 'CEO_Wing_J', 'Head right to CEO wing',
        'Head left back to main corridor');
    addBiEdge(
        'CEO_Wing_J', 'CEO_Room', 'Turn right into CEO Room', 'Exit CEO Room');
    addBiEdge('CEO_Wing_J', 'Meeting_Room', 'Head down to Meeting Room',
        'Head up to CEO Wing');

    // CENTER: Cafeteria Area
    addBiEdge('Cafeteria_J', 'Cafeteria', 'Turn left into Cafeteria',
        'Exit Cafeteria');

    // LAB CORRIDOR: GNSS, LiDAR, Computational
    addBiEdge('Lab_Corridor_J', 'GNSS_Lab', 'Turn left into GNSS Lab',
        'Exit GNSS Lab');
    addBiEdge('Lab_Corridor_J', 'LiDAR_Lab', 'Turn right into LiDAR Lab',
        'Exit LiDAR Lab');
    addBiEdge('Lab_Corridor_J', 'GEO_Intel_Lab',
        'Turn right into GEO Intel Lab', 'Exit GEO Intel Lab');
    addBiEdge('Lab_Corridor_J', 'Lab_Section_J',
        'Continue right to lab section', 'Head back to lab corridor');
    addBiEdge('Lab_Section_J', 'Computational_Lab',
        'Turn right into Computational Lab', 'Exit Computational Lab');

    // LEFT SIDE: Gym, GIS Lab
    addBiEdge('Main_Corridor_J1', 'Left_Corridor_J',
        'Head left to left corridor', 'Head right back to main corridor');
    addBiEdge('Left_Corridor_J', 'Gym_Room', 'Turn left into Gym Room',
        'Exit Gym Room');
    addBiEdge('Left_Corridor_J', 'GIS_Lab', 'Head down to GIS Lab',
        'Head up from GIS Lab');

    // BOTTOM: PD Room, CV Lab, Admin, Discussion, Washrooms
    addBiEdge('Bottom_Corridor_J', 'PD_Room', 'Turn left into PD Room',
        'Exit PD Room');
    addBiEdge('Bottom_Corridor_J', 'CV_Lab', 'Head down to CV Lab',
        'Head up from CV Lab');
    addBiEdge('Bottom_Corridor_J', 'Admin_Room', 'Turn right into Admin Room',
        'Exit Admin Room');
    addBiEdge('Bottom_Corridor_J', 'Discussion_Area',
        'Head right to Discussion Area', 'Head left from Discussion Area');
    addBiEdge('Bottom_Corridor_J', 'Washrooms', 'Head right to Washrooms',
        'Exit Washrooms');

    return adjacencyList;
  }
}
