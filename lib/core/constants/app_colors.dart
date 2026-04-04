import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF5C35E5);
  static const Color primaryLight = Color(0xFF8B6FF0);
  static const Color primaryDark = Color(0xFF3D1FC9);

  static const Color secondary = Color(0xFFFF6B6B);
  static const Color secondaryLight = Color(0xFFFF9B9B);

  static const Color accent = Color(0xFFF5A623);
  static const Color accentLight = Color(0xFFFFC85A);

  static const Color background = Color(0xFFF9F7FF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF0ECFF);

  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B6B8A);
  static const Color textHint = Color(0xFFABABBF);

  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFE53935);

  static const Color divider = Color(0xFFE8E4FF);
  static const Color cardShadow = Color(0x1A5C35E5);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient bgGradient = LinearGradient(
    colors: [Color(0xFFF9F7FF), Color(0xFFEDE8FF)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
