import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class PartnerOpportunitiesScreen extends StatelessWidget {
  const PartnerOpportunitiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Partner Opportunities'),
        centerTitle: true,
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildIntroductionCard(),
          const SizedBox(height: 20),

          Text('Choose a Partner Type', style: AppTextStyles.headlineMedium),
          const SizedBox(height: 6),
          Text(
            'Start with the service that best matches your business. '
            'Additional capabilities can be reviewed later.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),

          _PartnerTypeCard(
            icon: Icons.content_cut_rounded,
            title: 'Tailor',
            subtitle:
                'Stitching, alterations, bridal, designer and garment services',
            color: const Color(0xFF4CAF50),
            statusLabel: 'Applications opening first',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Tailor application form will be added in the next step.',
                  ),
                ),
              );
            },
          ),
          _PartnerTypeCard(
            icon: Icons.storefront_outlined,
            title: 'Boutique',
            subtitle:
                'Boutique services, specialized stitching and collections',
            color: const Color(0xFFE91E63),
            statusLabel: 'Planned',
            onTap: null,
          ),
          _PartnerTypeCard(
            icon: Icons.design_services_outlined,
            title: 'Designer / Fashion Services',
            subtitle:
                'Free, paid and premium designs, templates and consultations',
            color: const Color(0xFF9C27B0),
            statusLabel: 'Planned',
            onTap: null,
          ),
          _PartnerTypeCard(
            icon: Icons.local_mall_outlined,
            title: 'Fabric Store / Supplier',
            subtitle:
                'Fabric supply, availability, material knowledge and sourcing',
            color: const Color(0xFF795548),
            statusLabel: 'Planned',
            onTap: null,
          ),
          _PartnerTypeCard(
            icon: Icons.delivery_dining_outlined,
            title: 'Delivery Partner',
            subtitle: 'Pickup, doorstep handover and delivery services',
            color: const Color(0xFF00BCD4),
            statusLabel: 'Planned',
            onTap: null,
          ),
          _PartnerTypeCard(
            icon: Icons.handyman_outlined,
            title: 'Doorstep Services',
            subtitle:
                'Rafu, repair, alterations, pico-fall and measurement visits',
            color: const Color(0xFFFF9800),
            statusLabel: 'Planned',
            onTap: null,
          ),

          const SizedBox(height: 20),
          _buildApplicationsCard(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildIntroductionCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.78),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.handshake_rounded, color: Colors.white, size: 34),
          const SizedBox(height: 12),
          Text(
            'Grow with SuiSakhi',
            style: AppTextStyles.headlineLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Register your skills and services to become part of the '
            'SuiSakhi partner ecosystem.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Colors.white,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Every partner application is reviewed by SuiSakhi. '
                    'Partner profiles remain inactive until Admin approval.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationsCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assignment_outlined, color: AppColors.primary),
              const SizedBox(width: 10),
              Text('Your Applications', style: AppTextStyles.titleLarge),
            ],
          ),
          const SizedBox(height: 14),
          Center(
            child: Column(
              children: [
                const Icon(
                  Icons.inbox_outlined,
                  size: 44,
                  color: AppColors.textHint,
                ),
                const SizedBox(height: 10),
                Text(
                  'No partner applications yet',
                  style: AppTextStyles.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Applications and approval status will appear here.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PartnerTypeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String statusLabel;
  final VoidCallback? onTap;

  const _PartnerTypeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.statusLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: enabled ? color.withValues(alpha: 0.35) : AppColors.divider,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                subtitle,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                statusLabel,
                style: AppTextStyles.bodySmall.copyWith(
                  color: enabled ? color : AppColors.textHint,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        trailing: Icon(
          enabled ? Icons.chevron_right_rounded : Icons.schedule_outlined,
          color: enabled ? color : AppColors.textHint,
        ),
        onTap: onTap,
      ),
    );
  }
}
