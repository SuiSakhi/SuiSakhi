import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/dress.dart';
import '../../widgets/common/custom_button.dart';
import 'dress_catalog_screen.dart';

class DressDetailScreen extends StatelessWidget {
  final String dressId;
  const DressDetailScreen({super.key, required this.dressId});

  DressType? _findDress() {
    try {
      return ladiesDresses.firstWhere((d) => d.id == dressId);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dress = _findDress();

    if (dress == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Not Found')),
        body: const Center(child: Text('Dress not found')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: dress.color.withValues(alpha: 0.15),
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.arrow_back_ios_rounded, size: 18),
              ),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: dress.color.withValues(alpha: 0.1),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 60),
                      Icon(dress.icon, color: dress.color, size: 90),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(dress.name, style: AppTextStyles.displayMedium),
                            const SizedBox(height: 4),
                            Text(dress.description, style: AppTextStyles.bodyMedium),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: dress.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Ladies',
                          style: AppTextStyles.labelMedium.copyWith(
                            color: dress.color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text('Measurements Required',
                      style: AppTextStyles.headlineMedium),
                  const SizedBox(height: 4),
                  Text(
                    '${dress.measurements.length} measurements needed for a perfect fit',
                    style: AppTextStyles.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  ...dress.measurements.asMap().entries.map(
                        (entry) => _MeasurementRow(
                          index: entry.key + 1,
                          label: entry.value,
                          color: dress.color,
                        ),
                      ),
                  const SizedBox(height: 28),
                  _buildFabricSection(),
                  const SizedBox(height: 28),
                  PrimaryButton(
                    label: 'Design This Dress',
                    icon: Icons.design_services_rounded,
                    onTap: () => context.push('/designer'),
                  ),
                  const SizedBox(height: 12),
                  SecondaryButton(
                    label: 'Take Measurements First',
                    icon: Icons.camera_alt_rounded,
                    onTap: () => context.push('/camera'),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFabricSection() {
    final fabrics = [
      ('Cotton', Icons.eco_rounded, Color(0xFF4CAF50)),
      ('Silk', Icons.auto_awesome_rounded, Color(0xFF9C27B0)),
      ('Georgette', Icons.waves_rounded, Color(0xFF2196F3)),
      ('Linen', Icons.texture_rounded, Color(0xFFF5A623)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Popular Fabric Choices', style: AppTextStyles.headlineMedium),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: fabrics
              .map(
                (f) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: f.$3.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: f.$3.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(f.$2, color: f.$3, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        f.$1,
                        style: AppTextStyles.labelMedium.copyWith(color: f.$3),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _MeasurementRow extends StatelessWidget {
  final int index;
  final String label;
  final Color color;

  const _MeasurementRow({
    required this.index,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$index',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(label, style: AppTextStyles.titleMedium),
          const Spacer(),
          const Icon(Icons.straighten_rounded,
              size: 18, color: AppColors.textHint),
        ],
      ),
    );
  }
}
