import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFFB70D5C);
  static const Color primaryLight = Color(0xFFE84F8B);
  static const Color primaryDark = Color(0xFF79003F);

  static const Color secondary = Color(0xFFE84F8B);
  static const Color secondaryLight = Color(0xFFF69AB9);

  static const Color accent = Color(0xFFF5A623);
  static const Color accentLight = Color(0xFFFFC85A);

  static const Color background = Color(0xFFFFF8FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFFCEAF1);

  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B6B8A);
  static const Color textHint = Color(0xFFABABBF);

  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFE53935);

  static const Color divider = Color(0xFFF0DDE5);
  static const Color cardShadow = Color(0x1AB70D5C);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient bgGradient = LinearGradient(
    colors: [Color(0xFFFFF8FA), Color(0xFFFFEDF3)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
