import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/home/presentation/pages/landing_screen.dart';

void main() {
  runApp(const NnesApp());
}

class NnesApp extends StatelessWidget {
  const NnesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Navavishkar Navigation Enabled System',
      theme: AppTheme.theme,
      home: const LandingScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
