import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_state.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class TailorAccountCenterScreen extends StatelessWidget {
  const TailorAccountCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = AppState.instance.profile;
    final user = FirebaseAuth.instance.currentUser;

    final displayName = profile?.name.trim().isNotEmpty == true
        ? profile!.name.trim()
        : AppState.instance.displayName;

    final phone = user?.phoneNumber ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Tailor Account'),
        centerTitle: true,
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _TailorHeader(
            displayName: displayName,
            phone: phone,
          ),
          const SizedBox(height: 20),

          const _SectionTitle(title: 'Profile'),
          _MenuItem(
            icon: Icons.person_outline_rounded,
            title: 'View Tailor Profile',
            subtitle: 'See your tailor profile details',
            onTap: () => _comingSoon(context, 'View Tailor Profile'),
          ),
          _MenuItem(
            icon: Icons.edit_outlined,
            title: 'Edit Tailor Profile',
            subtitle: 'Update tailor profile and contact details',
            onTap: () => _comingSoon(context, 'Edit Tailor Profile'),
          ),

          const SizedBox(height: 16),
          const _SectionTitle(title: 'Business Details'),
          _MenuItem(
            icon: Icons.storefront_outlined,
            title: 'Workshop Details',
            subtitle: 'Shop address, photos, timings and staff details',
            onTap: () => _comingSoon(context, 'Workshop Details'),
          ),
          _MenuItem(
            icon: Icons.content_cut_rounded,
            title: 'Tailor Expertise',
            subtitle: 'Specialization, experience and skills',
            onTap: () => _comingSoon(context, 'Tailor Expertise'),
          ),
          _MenuItem(
            icon: Icons.checklist_rounded,
            title: 'Service Matrix',
            subtitle: 'Blouse, alterations, bridal, kids and more',
            onTap: () => _comingSoon(context, 'Service Matrix'),
          ),
          _MenuItem(
            icon: Icons.currency_rupee_rounded,
            title: 'Rate Card',
            subtitle: 'Normal, peak and express service rates',
            onTap: () => _comingSoon(context, 'Rate Card'),
          ),

          const SizedBox(height: 16),
          const _SectionTitle(title: 'Operations'),
          _MenuItem(
            icon: Icons.inventory_2_outlined,
            title: 'Assigned Orders',
            subtitle: 'Orders currently assigned to you',
            onTap: () => _comingSoon(context, 'Assigned Orders'),
          ),
          _MenuItem(
            icon: Icons.done_all_rounded,
            title: 'Completed Orders',
            subtitle: 'Orders completed by you',
            onTap: () => _comingSoon(context, 'Completed Orders'),
          ),
          _MenuItem(
            icon: Icons.speed_rounded,
            title: 'Capacity Management',
            subtitle: 'Daily capacity, team size and seasonal load',
            onTap: () => _comingSoon(context, 'Capacity Management'),
          ),
          _MenuItem(
            icon: Icons.straighten_rounded,
            title: 'Measurement Preferences',
            subtitle: 'Standard sheet, QC check and video verification',
            onTap: () => _comingSoon(context, 'Measurement Preferences'),
          ),

          const SizedBox(height: 16),
          const _SectionTitle(title: 'Quality & Trust'),
          _MenuItem(
            icon: Icons.verified_outlined,
            title: 'Quality Checklist',
            subtitle: 'Delivery checklist, trial and rework policy',
            onTap: () => _comingSoon(context, 'Quality Checklist'),
          ),
          _MenuItem(
            icon: Icons.workspace_premium_outlined,
            title: 'Certification Tier',
            subtitle: 'Basic, blouse/suits, bridal/designer levels',
            onTap: () => _comingSoon(context, 'Certification Tier'),
          ),
          _MenuItem(
            icon: Icons.star_border_rounded,
            title: 'Ratings & Reviews',
            subtitle: 'Customer ratings and feedback',
            onTap: () => _comingSoon(context, 'Ratings & Reviews'),
          ),

          const SizedBox(height: 16),
          const _SectionTitle(title: 'Payments & Support'),
          _MenuItem(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Payouts',
            subtitle: 'Weekly payouts and payment settings',
            onTap: () => _comingSoon(context, 'Payouts'),
          ),
          _MenuItem(
            icon: Icons.support_agent_rounded,
            title: 'Help & Support',
            subtitle: 'Contact SuiSakhi support',
            onTap: () => _comingSoon(context, 'Help & Support'),
          ),

          const SizedBox(height: 16),
          _MenuItem(
            icon: Icons.logout_rounded,
            title: 'Logout',
            subtitle: 'Sign out from SuiSakhi',
            isDestructive: true,
            onTap: () async {
              await AppState.instance.signOut();
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  static void _comingSoon(BuildContext context, String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title coming soon'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _TailorHeader extends StatelessWidget {
  final String displayName;
  final String phone;

  const _TailorHeader({
    required this.displayName,
    required this.phone,
  });

  @override
  Widget build(BuildContext context) {
    final initial = displayName.trim().isNotEmpty
        ? displayName.trim()[0].toUpperCase()
        : 'T';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: const Color(0xFF4CAF50).withValues(alpha: 0.12),
            child: Text(
              initial,
              style: const TextStyle(
                color: Color(0xFF4CAF50),
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: AppTextStyles.titleLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  phone.isNotEmpty ? phone : 'Tailor Profile',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Tailor Partner',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: const Color(0xFF4CAF50),
                      fontWeight: FontWeight.w700,
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
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: AppTextStyles.labelLarge.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = isDestructive
        ? AppColors.error
        : const Color(0xFF4CAF50);

    final titleColor = isDestructive
        ? AppColors.error
        : AppColors.textPrimary;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withValues(alpha: 0.10),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(
          title,
          style: AppTextStyles.titleMedium.copyWith(
            color: titleColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
