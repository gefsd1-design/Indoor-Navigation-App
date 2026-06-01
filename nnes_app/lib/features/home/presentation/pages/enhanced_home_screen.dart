import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/image_recognition_service.dart';
import '../../../navigation/presentation/pages/lab_detection_screen.dart';
import '../../../navigation/presentation/pages/hybrid_navigation_screen.dart';
import '../../../navigation/presentation/pages/navigation_screen.dart';
import '../../../navigation/presentation/pages/office_map_view_screen.dart';
import '../../../navigation/presentation/pages/accuracy_navigation_screen.dart';
import '../../../navigation/presentation/pages/virtual_marker_navigation_screen.dart';
import '../../../est_location/presentation/pages/est_location_screen.dart';
import 'package:nnes_app/features/ui/presentation/pages/office_gallery_page.dart';

class EnhancedHomeScreen extends StatefulWidget {
  const EnhancedHomeScreen({super.key});

  @override
  State<EnhancedHomeScreen> createState() => _EnhancedHomeScreenState();
}

class _EnhancedHomeScreenState extends State<EnhancedHomeScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  bool _isProcessing = false;

  void _showHelp() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How to Use This App'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('1. Visual Marker Navigation',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text(
                  ' - Tap "Virtual Marker Navigation".\n - Tap "Scan Marker" and scan a QR code at your location.\n - Select your destination from the dropdown.\n - Follow the path and directions shown on the map.\n - Voice guidance will read out the steps.'),
              SizedBox(height: 12),
              Text('2. Accuracy Enhancements',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text(
                  ' - Tap "Accuracy Enhancements".\n - Enable BLE and Sensor Fusion for improved indoor accuracy.\n - Start enhancements to use BLE beacons, Wi-Fi, and sensors.\n - Your estimated room and position will update live.'),
              SizedBox(height: 12),
              Text('3. GPS Navigation',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text(
                  ' - Tap "GPS Navigation".\n - Use standard GPS-based navigation for outdoor or fallback scenarios.'),
              SizedBox(height: 12),
              Text('4. Hybrid Navigation',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text(
                  ' - Tap "Hybrid Navigation (GPS + Indoor)".\n - Combines GPS and indoor positioning for seamless transitions.'),
              SizedBox(height: 12),
              Text('5. Lab Detection',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text(
                  ' - Tap "Find Your Location".\n - Capture a clear image of your lab or room.\n - Confirm the detected location and start navigation.'),
              SizedBox(height: 12),
              Text('6. Office Gallery',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text(' - Browse lab and office photos for reference.'),
              SizedBox(height: 12),
              Text('Tips:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(
                  ' - For best results, scan QR markers at doors.\n - Capture images from multiple angles for accurate lab detection.\n - Use the voice guidance for step-by-step indoor navigation.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _captureAndRecognizeImage(ImageSource source) async {
    try {
      setState(() => _isProcessing = true);

      final capturedFiles = <File>[];

      if (source == ImageSource.camera) {
        for (int i = 0; i < 3; i++) {
          final XFile? image = await _imagePicker.pickImage(
            source: source,
            imageQuality: 85,
          );
          if (image == null) {
            break;
          }
          capturedFiles.add(File(image.path));
        }
      } else {
        final XFile? image = await _imagePicker.pickImage(
          source: source,
          imageQuality: 85,
        );
        if (image != null) {
          capturedFiles.add(File(image.path));
        }
      }

      if (capturedFiles.isEmpty) {
        setState(() => _isProcessing = false);
        return;
      }

      // Show processing dialog
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppTheme.primary),
                const SizedBox(height: 24),
                Text(
                  capturedFiles.length > 1
                      ? 'Analyzing Images...'
                      : 'Analyzing Image...',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppTheme.onSurface,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  capturedFiles.length > 1
                      ? 'Identifying your location from multiple angles'
                      : 'Identifying your location',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ),
      );

      // Recognize lab from image
      final outcome = capturedFiles.length > 1
          ? await ImageRecognitionService.matchLocationFromImages(capturedFiles)
          : await ImageRecognitionService.matchLocationFromImage(
              capturedFiles.first,
            );

      if (!mounted) return;
      Navigator.pop(context); // Close processing dialog

      if (outcome.detection != null) {
        // Navigate to lab detection confirmation screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                LabDetectionScreen(detection: outcome.detection!),
          ),
        );
      } else {
        final message =
            outcome.hint ?? 'Could not recognize location. Please try again.';
        if (!mounted) return;
        final useGps = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Location Not Found'),
            content: Text('$message\n\nUse GPS instead?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Try Again'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Use GPS'),
              ),
            ],
          ),
        );

        if (useGps == true && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const NavigationScreen(),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppTheme.primary),
                title: const Text('Capture Image'),
                onTap: () {
                  Navigator.pop(context);
                  _captureAndRecognizeImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.photo_library, color: AppTheme.secondary),
                title: const Text('Upload from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _captureAndRecognizeImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Gradient background
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.background,
                    AppTheme.surfaceContainerLow.withValues(alpha: 0.5),
                  ],
                ),
              ),
            ),
            Positioned(
              top: -60,
              right: -40,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: 140,
              left: -40,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  color: AppTheme.secondary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            // Top branding section
            Positioned.fill(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // App name and logo
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 32,
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              color: AppTheme.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.gps_fixed,
                              size: 48,
                              color: AppTheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Navavishkar',
                            style: Theme.of(context)
                                .textTheme
                                .displayMedium
                                ?.copyWith(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Navigation Enabled System',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  color: AppTheme.onSurfaceVariant,
                                  fontSize: 14,
                                  letterSpacing: 0.5,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 2,
                            width: 60,
                            color: AppTheme.primary,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Main CTA: Image Capture
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: GestureDetector(
                        onTap: _isProcessing ? null : _showImageSourcePicker,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.primaryContainer,
                                AppTheme.primaryContainer
                                    .withValues(alpha: 0.7),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primary.withValues(alpha: 0.3),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 28,
                            ),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: AppTheme.onPrimaryContainer
                                        .withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt_outlined,
                                    size: 48,
                                    color: AppTheme.onPrimaryContainer,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  'Find Your Location',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        color: AppTheme.onPrimaryContainer,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Capture an image to identify the lab and get directions',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: AppTheme.onPrimaryContainer
                                            .withValues(alpha: 0.8),
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Feature cards
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          // Direct Navigation Card
                          _FeatureCard(
                            icon: Icons.navigation,
                            title: 'Direct Navigation',
                            subtitle: 'Navigate without image capture',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const HybridNavigationScreen(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          _FeatureCard(
                            icon: Icons.gps_fixed,
                            title: 'GPS Navigation',
                            subtitle: 'Navigate using GPS positioning',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const NavigationScreen(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          _FeatureCard(
                            icon: Icons.gps_not_fixed,
                            title: 'Accuracy Enhancements',
                            subtitle: 'BLE, Wi-Fi, and sensors',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const AccuracyEnhancementsScreen(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          _FeatureCard(
                            icon: Icons.location_history,
                            title: 'Estimated Location',
                            subtitle: 'Sensor-based position tracking',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const EstLocationScreen(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          _FeatureCard(
                            icon: Icons.qr_code_scanner,
                            title: 'Virtual Marker Navigation',
                            subtitle: 'QR-based indoor anchoring',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const VirtualMarkerNavigationScreen(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          // Office Map Card
                          _FeatureCard(
                            icon: Icons.map,
                            title: 'Office Map',
                            subtitle: 'View complete building layout',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const OfficeMapViewScreen(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          // Gallery Card
                          _FeatureCard(
                            icon: Icons.photo_library,
                            title: 'Office Gallery',
                            subtitle: 'Explore lab photos and details',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => OfficeGalleryPage(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.info_outline, color: AppTheme.onSurface),
                onPressed: _showHelp,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reusable feature card widget
class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.secondary.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.secondary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: AppTheme.secondary,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppTheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: AppTheme.primary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
