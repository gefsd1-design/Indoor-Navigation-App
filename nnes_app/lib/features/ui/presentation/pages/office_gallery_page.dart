import 'package:flutter/material.dart';

class OfficeGalleryPage extends StatelessWidget {
  final List<String> images = [
    'PD Room.jpg',
    'CEO Room.jpg',
    'Corridor_.jpg',
    'Stair Way_.jpg',
    'CV Lab TIH_.jpg',
    'GIS Lab TIH.jpg',
    'Coffee Area_.jpg',
    'Corridor TIH.jpg',
    'GNSS Lab TIH.jpg',
    'Interns Room.jpg',
    'Corridor TIH_.jpg',
    'LiDAR Lab TIH.jpg',
    'TIH Back Side.jpg',
    'TIH Building_.jpg',
    'TIH Corridor_.jpg',
    'Front Desk TIH.jpg',
    'TIH Cafeteria_.jpg',
    'TIH Labs List_.jpg',
    'Discussion Area.jpg',
    'Gents Washroom_.jpg',
    'TIH Lift Inside.jpg',
    'Ladies Washroom_.jpg',
    'TIH Corridor_(1).jpg',
    'TIH Lift Outside.jpg',
    'CEO Room Outside_.jpg',
    'Geo Intel Lab TIH.jpg',
    'Main Meeting Room.jpg',
    'TIH Backside Door.jpg',
    'TIH Starting Door.jpg',
    'Discussion Area(1).jpg',
    'TIH Lift 2nd Floor.jpg',
    'TIH Starting Board.jpg',
    'Infront of LiDAR Lab.jpg',
    'Computational Lab TIH.jpg',
    'Corridor near PD room.jpg',
    'CV Lab Glass Windows_.jpg',
    'TIH Main Meeting Room.jpg',
    'TIH Building Left Side.jpg',
    'TIH Building Left View.jpg',
    'TIH Building Starting_.jpg',
    'TIH Lift Ground Floor_.jpg',
    'Display Board Corridor_.jpg',
    'TIH Building Right Side.jpg',
    'TIH Building Right View.jpg',
    'TIH Building Left View 2.jpg',
    'TIH Building Ground Floor.jpg',
    'Perpendicular to LiDAR Lab.jpg',
    'TIH Building Starting Arch.jpg',
    'TIH Building Starting Door.jpg',
    'TIH Lift Outside 2nd Floor.jpg',
    'Drinking Water Filling Area_.jpg',
    'Corridor infront of LiDAR Lab.jpg',
    'TIH Back Side Door Ground Floor.jpg',
    'TIH Ground Floor Lift Entrance_.jpg',
    'Back Side of TIH Lecture Hall way.jpg',
    'Discussion Place infront of CV Lab_.jpg',
    'TIH Building Ground Floor Security_.jpg',
  ];

  OfficeGalleryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Office Gallery'),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(8.0),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8.0,
          mainAxisSpacing: 8.0,
          childAspectRatio: 0.8,
        ),
        itemCount: images.length,
        itemBuilder: (context, index) {
          final imageName = images[index];
          final displayName = imageName.replaceAll('.jpg', '').replaceAll('_', ' ');
          return Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Image.asset(
                    'assets/office_dataset/TIH Photos/$imageName',
                    fit: BoxFit.cover,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    displayName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
