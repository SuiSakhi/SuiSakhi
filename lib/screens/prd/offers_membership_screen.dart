import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

/// PRD Section 5 — Offers & Membership (Prime / Gold benefits).
class OffersMembershipScreen extends StatelessWidget {
  const OffersMembershipScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Offers & Membership'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Subscriptions', style: AppTextStyles.headlineSmall),
          const SizedBox(height: 6),
          Text(
            'Preferred tailor, priority assignment, discounts & trials — coming soon for in-app billing.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
          ),
          const SizedBox(height: 20),
          _PlanCard(
            title: 'Prime',
            price: '₹499 / year',
            perks: const [
              'Preferred tailor list',
              'Priority order assignment',
              'Free pickup on orders above ₹1000 (else partner rate)',
            ],
            color: const Color(0xFF5C6BC0),
          ),
          const SizedBox(height: 14),
          _PlanCard(
            title: 'Gold',
            price: '₹999 / year',
            perks: const [
              'Everything in Prime',
              'One free trial stitch (T&Cs)',
              'Extra coupon drops during festivals',
            ],
            color: const Color(0xFFFFA000),
          ),
          const SizedBox(height: 28),
          Text('Promotions', style: AppTextStyles.headlineSmall),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Wedding packages', style: AppTextStyles.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Bundle pricing for bridal party — enquire via Bulk Orders or support.',
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: 12),
                Text('Coupon codes', style: AppTextStyles.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Seasonal codes will appear here and at checkout when payment is enabled.',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Membership purchase will be available in a future release'),
                ),
              );
            },
            child: const Text('Notify me when membership launches'),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.price,
    required this.perks,
    required this.color,
  });

  final String title;
  final String price;
  final List<String> perks;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.06)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: AppTextStyles.headlineSmall),
              const Spacer(),
              Text(price, style: AppTextStyles.titleMedium.copyWith(color: color)),
            ],
          ),
          const SizedBox(height: 12),
          ...perks.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_rounded, size: 18, color: color),
                  const SizedBox(width: 8),
                  Expanded(child: Text(p, style: AppTextStyles.bodyMedium)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
