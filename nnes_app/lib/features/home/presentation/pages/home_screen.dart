import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:nnes_app/features/navigation/presentation/pages/navigation_screen.dart';
import 'package:nnes_app/features/navigation/presentation/pages/hybrid_navigation_screen.dart';
import 'package:nnes_app/features/navigation/presentation/pages/accuracy_navigation_screen.dart';
import 'package:nnes_app/features/navigation/presentation/pages/virtual_marker_navigation_screen.dart';
import 'package:nnes_app/features/ui/presentation/pages/office_gallery_page.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const String officeLogoUrl =
      "https://lh3.googleusercontent.com/aida/ADBb0ugDC6rBBRIDKPQl6VtNEIlf3ORtsZuynfWpIS4gBmP770eV1AKkLn5NvN1ido76AoNt6KRRAQhYe4oXjgFl-ttA8AIub3U9iOoQUnz6IjEZmSQcYofUgEPyge0dMGi7p1iwGi2bwCRULoSMUNPV3S6dW3ewe-0yRdrKr1MeAJXKreoke6RXU3_X1vczOug1kg0YXK_NFws3TDgMHMi6QXgFuEO2V4K2ys7ciRcyGl-CfCf2N7iax5CSicg98GjtOPZNZMB995ou";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Map Background Placeholder
            Positioned.fill(
              child: Container(
                color: AppTheme.surface,
                child: const Center(
                  child: Icon(Icons.map_outlined,
                      size: 100, color: AppTheme.surfaceContainerHighest),
                ),
              ),
            ),

            // Top Right Office Logo
            Positioned(
              top: 16,
              right: 16,
              child: Image.network(
                officeLogoUrl,
                width: 60,
                height: 60,
                errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.business,
                    size: 40,
                    color: AppTheme.onSurface),
              ),
            ),

            // Bottom Asymmetrical Card for Navigation Prompts
            Positioned(
              bottom: 24,
              left: 16,
              right: 48, // Asymmetrical margins
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  color: AppTheme.surfaceContainerLow
                      .withValues(alpha: 0.85), // Tonal lift
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Building Map Overview",
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                color: AppTheme.primary,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Find your way through the NNES Innovation Hub.",
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 24),
                        // Hybrid Navigation Button
                        Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                AppTheme.primaryContainer,
                                AppTheme.onPrimaryFixedVariant
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const HybridNavigationScreen()),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              minimumSize: const Size(double.infinity, 50),
                            ),
                            child:
                                const Text("Hybrid Navigation (GPS + Indoor)"),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Accuracy Enhancements Button
                        OutlinedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const AccuracyEnhancementsScreen()),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                            side: const BorderSide(color: AppTheme.primary),
                          ),
                          child: const Text("Accuracy Enhancements"),
                        ),
                        const SizedBox(height: 12),
                        // Virtual Marker Navigation Button
                        OutlinedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const VirtualMarkerNavigationScreen()),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                            side: const BorderSide(color: AppTheme.primary),
                          ),
                          child: const Text("Virtual Marker Navigation"),
                        ),
                        const SizedBox(height: 12),
                        // Legacy GPS Navigation Button
                        OutlinedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const NavigationScreen()),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                            side: const BorderSide(color: AppTheme.primary),
                          ),
                          child: const Text("GPS Navigation (Legacy)"),
                        ),
                        const SizedBox(height: 12),
                        // Gallery Button
                        OutlinedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => OfficeGalleryPage()),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                            side: const BorderSide(color: AppTheme.primary),
                          ),
                          child: const Text("View Office Gallery"),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
