import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/image_recognition_service.dart';
import '../../../../core/models/office_graph_factory.dart';
import '../pages/hybrid_navigation_screen.dart';
import '../pages/navigation_screen.dart';

class LabDetectionScreen extends StatefulWidget {
  final LabDetectionResult detection;

  const LabDetectionScreen({
    super.key,
    required this.detection,
  });

  @override
  State<LabDetectionScreen> createState() => _LabDetectionScreenState();
}

class _LabDetectionScreenState extends State<LabDetectionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late AnimationController _ctaPulseController;
  late Animation<double> _ctaGlow;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _ctaPulseController = AnimationController(
      duration: const Duration(milliseconds: 2400),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _ctaGlow = Tween<double>(begin: 0.18, end: 0.38).animate(
      CurvedAnimation(parent: _ctaPulseController, curve: Curves.easeInOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _ctaPulseController.dispose();
    super.dispose();
  }

  void _proceedToNavigation() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HybridNavigationScreen(
          presetSourceLabId: widget.detection.labId,
        ),
      ),
    );
  }

  void _proceedToGpsNavigation() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const NavigationScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final graph = OfficeGraphFactory.buildGraph();
    final sourceNode = graph.nodes[widget.detection.labId];

    return Scaffold(
      backgroundColor: AppTheme.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerLow.withValues(alpha: 0.8),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back, color: AppTheme.onSurface),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top spacer
            const SizedBox(height: 24),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.secondary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppTheme.secondary.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome,
                        size: 18, color: AppTheme.secondary),
                    const SizedBox(width: 8),
                    Text(
                      'Location Locked',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AppTheme.secondary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Animated detection card
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: Column(
                        children: [
                          // Confidence indicator
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              color: AppTheme.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_circle,
                              size: 64,
                              color: AppTheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Lab name
                          Text(
                            'You are in',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  color: AppTheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.detection.labName,
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .displaySmall
                                ?.copyWith(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.6,
                                ),
                          ),
                          const SizedBox(height: 24),

                          // Confidence score
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryContainer
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.primaryContainer
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.verified,
                                  color: AppTheme.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Confidence: ${(widget.detection.confidence * 100).toStringAsFixed(1)}%',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: AppTheme.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 48),

                    // Location details
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppTheme.secondary.withValues(alpha: 0.3),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Location Coordinates',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 16),
                            _LocationDetailRow(
                              icon: Icons.location_on,
                              label: 'Latitude',
                              value:
                                  widget.detection.latitude.toStringAsFixed(6),
                            ),
                            const SizedBox(height: 12),
                            _LocationDetailRow(
                              icon: Icons.location_on,
                              label: 'Longitude',
                              value:
                                  widget.detection.longitude.toStringAsFixed(6),
                            ),
                            const SizedBox(height: 12),
                            _LocationDetailRow(
                              icon: Icons.image,
                              label: 'Image Name',
                              value: widget.detection.imageName,
                            ),
                            if (sourceNode != null) ...[
                              const SizedBox(height: 12),
                              _LocationDetailRow(
                                icon: Icons.location_on,
                                label: 'Lab ID',
                                value: sourceNode.id,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),

            // Navigation buttons
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Primary CTA: Start Navigation
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: AnimatedBuilder(
                      animation: _ctaGlow,
                      builder: (context, child) => Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              AppTheme.primaryContainer,
                              AppTheme.onPrimaryFixedVariant
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary
                                  .withValues(alpha: _ctaGlow.value),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: child,
                      ),
                      child: ElevatedButton(
                        onPressed: _proceedToNavigation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Start Navigation',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Secondary button: Capture again
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: AppTheme.primary,
                          width: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Capture Again',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      onPressed: _proceedToGpsNavigation,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: AppTheme.secondary,
                          width: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Use GPS Navigation',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.secondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _LocationDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primary, size: 24),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.onSurface,
                  ),
            ),
          ],
        ),
      ],
    );
  }
}
