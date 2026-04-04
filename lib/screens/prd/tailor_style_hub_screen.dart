import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/prd_catalog.dart';

/// PRD Section 1 — Core: pick Ladies vs Kids, then occasion → designer.
class TailorStyleHubScreen extends StatelessWidget {
  const TailorStyleHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Tailor Your Style'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded),
            onPressed: () => context.pop(),
          ),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'Ladies'),
              Tab(text: 'Kids'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _OccasionGrid(
              occasions: kLadiesOccasions,
              isKidsFlow: false,
            ),
            _OccasionGrid(
              occasions: kKidsOccasions,
              isKidsFlow: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _OccasionGrid extends StatelessWidget {
  const _OccasionGrid({
    required this.occasions,
    required this.isKidsFlow,
  });

  final List<OccasionCategory> occasions;
  final bool isKidsFlow;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Select occasion',
          style: AppTextStyles.headlineSmall,
        ),
        const SizedBox(height: 6),
        Text(
          'Measurement → design → tailoring → QC → delivery',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
        ),
        const SizedBox(height: 20),
        ...occasions.map((o) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  final q =
                      'occasion=${Uri.encodeComponent(o.name)}&kids=${isKidsFlow ? '1' : '0'}';
                  context.push('/designer?$q');
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.checkroom_rounded, color: AppColors.primary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          o.displayName,
                          style: AppTextStyles.titleMedium,
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
