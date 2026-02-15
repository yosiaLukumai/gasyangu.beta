import 'package:flutter/material.dart';
import 'core/app_colors.dart';
import 'presentation/landing.dart';

void main() {
  runApp(const GasYanguApp());
}

class GasYanguApp extends StatelessWidget {
  const GasYanguApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GasYangu',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.brandPrimary,
          primary: AppColors.brandPrimary,
          secondary: AppColors.brandSecondary,
          surface: AppColors.surface,
        ),
        scaffoldBackgroundColor: AppColors.background,
      ),
      home: const LandingScreen(),
    );
  }
}