import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/prd_catalog.dart';
import '../../services/order_service.dart';

/// PRD Section 4 — Shop & Explore (phase-1: interest capture → admin / partner handoff).
class ShopExploreScreen extends StatelessWidget {
  const ShopExploreScreen({super.key});

  Future<void> _onCategory(BuildContext context, ShopExploreCategory cat) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(cat.title),
        content: Text(
          'Partner marketplace orders are handled with our team in phase 1. '
          'Submit interest and we will connect you with the right partner.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Submit interest'),
          ),
        ],
      ),
    );
    if (go != true || !context.mounted) return;
    final id = await OrderService.createMarketplaceInterest(
      shopCategoryId: cat.id,
      title: cat.title,
      notes: 'Shop & Explore interest',
    );
    if (!context.mounted) return;
    if (id != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks — we will reach out shortly')),
      );
      context.push('/orders');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to submit interest')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Shop & Explore'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Partners & collections', style: AppTextStyles.headlineSmall),
          const SizedBox(height: 6),
          Text(
            'Rentals, fabrics, accessories, kids wear, festivals & printing — commission-based partners (PRD phase 1: manual coordination).',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
          ),
          const SizedBox(height: 20),
          ...ShopExploreCategory.items.map((cat) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _onCategory(context, cat),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(cat.icon, color: AppColors.secondary),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(cat.title, style: AppTextStyles.titleMedium),
                              const SizedBox(height: 2),
                              Text(cat.subtitle, style: AppTextStyles.bodySmall),
                            ],
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
      ),
    );
  }
}
