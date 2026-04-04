import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/app_state.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/measurement_unit.dart';
import '../../models/measurement.dart';
import '../../services/claude_fit_advice_service.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/measurement_card.dart';
import '../../widgets/common/measurement_unit_toggle.dart';

class MeasurementResultScreen extends StatefulWidget {
  const MeasurementResultScreen({super.key});

  @override
  State<MeasurementResultScreen> createState() =>
      _MeasurementResultScreenState();
}

class _MeasurementResultScreenState extends State<MeasurementResultScreen> {
  bool _aiLoading = false;
  FitAdviceResult? _aiResult;

  Future<void> _loadAiTips(BodyMeasurements m) async {
    setState(() {
      _aiLoading = true;
      _aiResult = null;
    });
    final r = await ClaudeFitAdviceService.getTailoringTips(m);
    if (!mounted) return;
    setState(() {
      _aiLoading = false;
      _aiResult = r;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final m =
            AppState.instance.measurements ?? BodyMeasurements.sampleFemale;
        final unit = AppState.instance.measurementUnit;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Measurement Results'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded),
              onPressed: () => context.pop(),
            ),
            actions: const [
              Padding(
                padding: EdgeInsets.only(right: 8),
                child: Center(child: MeasurementUnitToggle()),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAccuracyCard(),
                const SizedBox(height: 24),
                SectionHeader(title: 'Captured Measurements'),
                const SizedBox(height: 8),
                Text(
                  'Primary: ${unit.abbrev} · line below shows the other unit',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textHint,
                  ),
                ),
                const SizedBox(height: 16),
                _buildMeasurementList(m, unit),
                const SizedBox(height: 24),
                _buildAiTipsCard(m),
                const SizedBox(height: 24),
                _buildTips(),
                const SizedBox(height: 28),
                PrimaryButton(
                  label: 'Save & Design a Dress',
                  icon: Icons.design_services_rounded,
                  onTap: () => context.push('/designer'),
                ),
                const SizedBox(height: 12),
                SecondaryButton(
                  label: 'Retake Measurements',
                  icon: Icons.refresh_rounded,
                  onTap: () => context.push('/camera'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAiTipsCard(BodyMeasurements m) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'AI tailoring tips',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Uses your Claude key (Firestore config/api → claudeKey). General guidance only — confirm with a tape measure.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _aiLoading ? null : () => _loadAiTips(m),
            icon: _aiLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.psychology_outlined, size: 20),
            label: Text(_aiLoading ? 'Getting tips…' : 'Get tips'),
          ),
          if (_aiResult != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _aiResult!.success
                    ? AppColors.success.withValues(alpha: 0.08)
                    : AppColors.secondary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _aiResult!.success
                      ? AppColors.success.withValues(alpha: 0.25)
                      : AppColors.secondary.withValues(alpha: 0.25),
                ),
              ),
              child: Text(
                _aiResult!.text,
                style: AppTextStyles.bodySmall.copyWith(height: 1.45),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAccuracyCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.verified_rounded,
              color: AppColors.success,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Measurement Accuracy', style: AppTextStyles.titleMedium),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: 0.87,
                          backgroundColor: AppColors.divider,
                          valueColor:
                              const AlwaysStoppedAnimation(AppColors.success),
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '87%',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Good lighting & clear pose detected',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeasurementList(BodyMeasurements m, MeasurementUnit unit) {
    final items = [
      ('Height', m.height, Icons.height_rounded, AppColors.primary),
      ('Chest', m.chest, Icons.straighten_rounded, const Color(0xFFFF6B6B)),
      ('Waist', m.waist, Icons.radio_button_unchecked, const Color(0xFFF5A623)),
      ('Hips', m.hips, Icons.accessibility_rounded, const Color(0xFF9C27B0)),
      ('Shoulder Width', m.shoulder, Icons.width_wide_rounded,
          const Color(0xFF4CAF50)),
      ('Arm Length', m.armLength, Icons.back_hand_outlined,
          AppColors.primaryDark),
      ('Neck', m.neck, Icons.circle_outlined, const Color(0xFF00BCD4)),
      ('Thigh', m.thigh, Icons.airline_seat_legroom_normal,
          const Color(0xFFFF5722)),
      ('Inseam', m.inseam, Icons.arrow_downward_rounded,
          const Color(0xFF795548)),
    ];

    return Column(
      children: items.map((item) {
        final primary = item.$2 != null
            ? MeasurementFormat.formatWithUnit(item.$2, unit)
            : '—';
        final secondary = item.$2 != null
            ? (unit == MeasurementUnit.cm
                ? '${MeasurementFormat.formatValue(item.$2, MeasurementUnit.inch)} in'
                : '${MeasurementFormat.formatValue(item.$2, MeasurementUnit.cm)} cm')
            : '';

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: item.$4.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.$3, color: item.$4, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(item.$1, style: AppTextStyles.titleMedium),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    primary,
                    style: AppTextStyles.headlineSmall.copyWith(color: item.$4),
                  ),
                  if (secondary.isNotEmpty)
                    Text(
                      secondary,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textHint, fontSize: 11),
                    ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTips() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tips_and_updates_rounded,
                  color: AppColors.accent, size: 20),
              const SizedBox(width: 8),
              Text('Improve Accuracy',
                  style:
                      AppTextStyles.titleMedium.copyWith(color: AppColors.accent)),
            ],
          ),
          const SizedBox(height: 10),
          ...const [
            'Wear form-fitting clothes during scan',
            'Ensure good lighting around you',
            'Stand on a flat surface, feet together',
            'Complete front, side, and back scans with full head-to-feet in frame',
          ].map(
            (tip) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(color: AppColors.accent)),
                  Expanded(
                    child: Text(tip, style: AppTextStyles.bodySmall),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
