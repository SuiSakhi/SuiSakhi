import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/app_state.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/measurement_unit.dart';
import '../../models/measurement.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/measurement_card.dart';
import '../../widgets/common/measurement_unit_toggle.dart';

class MeasurementDashboardScreen extends StatelessWidget {
  const MeasurementDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final measurements =
            AppState.instance.measurements ?? BodyMeasurements.sampleFemale;
        final unit = AppState.instance.measurementUnit;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('My Measurements'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded),
              onPressed: () => context.pop(),
            ),
            actions: [
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Center(child: MeasurementUnitToggle()),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () {},
                tooltip: 'Edit',
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMeasurementSummaryCard(measurements, unit),
                const SizedBox(height: 28),
                Text('Body Measurements', style: AppTextStyles.headlineMedium),
                const SizedBox(height: 4),
                Text(
                  'Last updated: Today · values shown in ${unit.abbrev} (with alternate)',
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: 16),
                _buildGrid(measurements, unit),
                const SizedBox(height: 28),
                PrimaryButton(
                  label: 'Re-take Measurements',
                  icon: Icons.camera_alt_rounded,
                  onTap: () => context.push('/camera'),
                ),
                const SizedBox(height: 12),
                SecondaryButton(
                  label: 'Design a Dress with These',
                  icon: Icons.design_services_rounded,
                  onTap: () => context.push('/designer'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMeasurementSummaryCard(BodyMeasurements m, MeasurementUnit unit) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.accessibility_new_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Body Profile',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                Text(
                  m.height != null
                      ? MeasurementFormat.formatDual(m.height, unit,
                          fractionDigits: 0)
                      : 'Height: —',
                  style: AppTextStyles.headlineMedium.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _statChip('Chest', m.chest, unit),
                    _statChip('Waist', m.waist, unit),
                    _statChip('Hips', m.hips, unit),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, double? val, MeasurementUnit unit) {
    final t = val != null
        ? MeasurementFormat.formatDual(val, unit, fractionDigits: 0)
        : '—';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$label: $t',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildGrid(BodyMeasurements m, MeasurementUnit unit) {
    final items = [
      ('Chest', m.chest, Icons.straighten_rounded, AppColors.primary),
      ('Waist', m.waist, Icons.radio_button_unchecked, const Color(0xFFFF6B6B)),
      ('Hips', m.hips, Icons.accessibility_rounded, const Color(0xFFF5A623)),
      ('Shoulder', m.shoulder, Icons.width_wide_rounded, const Color(0xFF4CAF50)),
      ('Arm Length', m.armLength, Icons.back_hand_outlined, AppColors.primaryDark),
      ('Height', m.height, Icons.height_rounded, const Color(0xFF9C27B0)),
      ('Neck', m.neck, Icons.circle_outlined, const Color(0xFF00BCD4)),
      ('Thigh', m.thigh, Icons.airline_seat_legroom_normal, const Color(0xFFFF5722)),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.1,
      ),
      itemCount: items.length,
      itemBuilder: (ctx, i) => MeasurementTile(
        label: items[i].$1,
        valueCm: items[i].$2,
        unit: unit,
        icon: items[i].$3,
        color: items[i].$4,
      ),
    );
  }
}
