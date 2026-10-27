import 'package:flutter/material.dart';

/// Garment Care brand palette sampled from the approved SuiSakhi logo.
/// Kept scoped to this product area so existing tailoring screens are stable.
class GarmentCareColors {
  GarmentCareColors._();

  static const Color primary = Color(0xFFB70D5C);
  static const Color primaryLight = Color(0xFFE84F8B);
  static const Color primaryDark = Color(0xFF79003F);
  static const Color background = Color(0xFFFFF8F7);
  static const Color surface = Colors.white;
  static const Color selected = Color(0xFFFCE8F0);
  static const Color textPrimary = Color(0xFF21171D);
  static const Color textSecondary = Color(0xFF6F5C66);
  static const Color textHint = Color(0xFF9B8791);
  static const Color divider = Color(0xFFF0DDE5);
}

class GarmentCareTheme extends StatelessWidget {
  const GarmentCareTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(
        colorScheme: base.colorScheme.copyWith(
          primary: GarmentCareColors.primary,
          secondary: GarmentCareColors.primaryLight,
          surface: GarmentCareColors.surface,
        ),
        scaffoldBackgroundColor: GarmentCareColors.background,
        appBarTheme: base.appBarTheme.copyWith(
          backgroundColor: GarmentCareColors.background,
          foregroundColor: GarmentCareColors.textPrimary,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: GarmentCareColors.primary,
            foregroundColor: Colors.white,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: GarmentCareColors.primary,
            side: const BorderSide(
              color: GarmentCareColors.primary,
              width: 1.4,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: GarmentCareColors.primary,
          ),
        ),
        inputDecorationTheme: base.inputDecorationTheme.copyWith(
          filled: true,
          fillColor: GarmentCareColors.surface,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: GarmentCareColors.primary,
              width: 2,
            ),
          ),
        ),
      ),
      child: child,
    );
  }
}
