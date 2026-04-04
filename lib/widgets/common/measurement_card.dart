import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/measurement_unit.dart';

class MeasurementTile extends StatelessWidget {
  final String label;
  /// Stored centimetres from [BodyMeasurements].
  final double? valueCm;
  final MeasurementUnit unit;
  final IconData icon;
  final Color? color;

  const MeasurementTile({
    super.key,
    required this.label,
    this.valueCm,
    this.unit = MeasurementUnit.cm,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tileColor = color ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: tileColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: tileColor, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: AppTextStyles.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          valueCm != null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      MeasurementFormat.formatWithUnit(valueCm, unit),
                      style: AppTextStyles.headlineSmall.copyWith(color: tileColor),
                    ),
                    Text(
                      unit == MeasurementUnit.cm
                          ? '(${MeasurementFormat.formatValue(valueCm, MeasurementUnit.inch)} in)'
                          : '(${MeasurementFormat.formatValue(valueCm, MeasurementUnit.cm)} cm)',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textHint,
                        fontSize: 11,
                      ),
                    ),
                  ],
                )
              : Text('—', style: AppTextStyles.headlineSmall.copyWith(color: AppColors.textHint)),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            title,
            style: AppTextStyles.headlineMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (actionLabel != null) ...[
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onAction,
            child: Text(
              actionLabel!,
              style: AppTextStyles.labelLarge,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}
