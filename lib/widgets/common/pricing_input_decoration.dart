import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

InputDecoration pricingInputDecoration({
  String? labelText,
  String? prefixText,
  required double verticalPadding,
  double horizontalPadding = 9,
  bool compact = false,
}) {
  final radius = BorderRadius.circular(12);
  final outline = OutlineInputBorder(
    borderRadius: radius,
    borderSide: BorderSide(
      color: AppColors.primary.withValues(alpha: 0.42),
      width: 1.1,
    ),
  );

  return InputDecoration(
    labelText: labelText,
    prefixText: prefixText,
    isDense: true,
    contentPadding: EdgeInsets.symmetric(
      horizontal: compact ? 8 : horizontalPadding,
      vertical: verticalPadding,
    ),
    labelStyle: compact
        ? const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)
        : null,
    floatingLabelStyle: TextStyle(
      color: AppColors.primary,
      fontSize: compact ? 13 : null,
      fontWeight: compact ? FontWeight.w500 : null,
    ),
    border: outline,
    enabledBorder: outline,
    focusedBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: const BorderSide(color: AppColors.primary, width: 2),
    ),
  );
}
