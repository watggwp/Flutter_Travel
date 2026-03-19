import 'package:flutter/material.dart';

class AppColors {
  // Primary Palette
  static const Color primary = Color(0xFF6C63FF);
  static const Color primaryDark = Color(0xFF4A44B3);
  static const Color primaryLight = Color(0xFF8E86FF);

  // Secondary / Accent
  static const Color secondary = Color(0xFF00C9A7);
  static const Color secondaryDark = Color(0xFF00A388);
  static const Color accent = Color(0xFFFF6584);

  // Background
  static const Color background = Color(0xFFF0F2FF);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1E1B4B);

  // Card
  static const Color cardColor = Colors.white;
  static const Color cardGlass = Color(0xCCFFFFFF); // Glassmorphism

  // Text
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF8B8FA8);
  static const Color textLight = Color(0xFFFFFFFF);

  // Input
  static const Color inputBackground = Color(0xFFEEF0FF);
  static const Color inputBorder = Color(0xFFD4D8FF);

  // Status
  static const Color error = Color(0xFFFF5C5C);
  static const Color success = Color(0xFF00C9A7);
  static const Color warning = Color(0xFFFFB347);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, Color(0xFF8E86FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient purpleBlueGradient = LinearGradient(
    colors: [Color(0xFF6C63FF), Color(0xFF3B82F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient tealGradient = LinearGradient(
    colors: [Color(0xFF00C9A7), Color(0xFF1BE7C0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [Color(0xFFEEF0FF), Color(0xFFE8F4FD)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardOverlayGradient = LinearGradient(
    colors: [Colors.transparent, Color(0xCC1A1A2E)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Shadows
  static List<BoxShadow> primaryShadow = [
    BoxShadow(
      color: primary.withOpacity(0.35),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: const Color(0xFF6C63FF).withOpacity(0.08),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> softShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];
}
