import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/partner_workspace_profile.dart';
import '../../services/partner_workspace_registry.dart';
import '../../services/partner_workspace_service.dart';

class PartnerProfileViewScreen extends StatelessWidget {
  const PartnerProfileViewScreen({
    super.key,
    required this.accountId,
    required this.profileId,
  });

  final String accountId;
  final String profileId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PartnerWorkspaceProfile>(
      future: PartnerWorkspaceService.requirePartnerProfile(
        accountId: accountId,
        profileId: profileId,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('My Profile')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('${snapshot.error}', textAlign: TextAlign.center),
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final profile = snapshot.data!;
        final values = <({IconData icon, String title, String value})>[
          (
            icon: Icons.storefront_outlined,
            title: 'Business Name',
            value: profile.businessDisplayName,
          ),
          (
            icon: Icons.badge_outlined,
            title: 'Partner Category',
            value: PartnerWorkspaceRegistry.categoryLabel(profile.partnerType),
          ),
          (
            icon: Icons.person_outline_rounded,
            title: 'Contact Name',
            value: profile.contactName ?? 'Not available',
          ),
          (
            icon: Icons.phone_outlined,
            title: 'Mobile Number',
            value: profile.mobileE164 ?? 'Not available',
          ),
          (
            icon: Icons.email_outlined,
            title: 'Email Address',
            value: profile.email ?? 'Not available',
          ),
          (
            icon: Icons.verified_user_outlined,
            title: 'Approval Status',
            value: profile.approvalStatus,
          ),
          (
            icon: Icons.fact_check_outlined,
            title: 'KYC Status',
            value: profile.kycStatus,
          ),
          (
            icon: Icons.power_settings_new_rounded,
            title: 'Operational Status',
            value: profile.operationalStatus,
          ),
          (
            icon: Icons.perm_identity_outlined,
            title: 'Profile ID',
            value: profile.profileId,
          ),
        ];

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(title: const Text('My Profile'), centerTitle: true),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final item in values)
                _InfoTile(
                  icon: item.icon,
                  title: item.title,
                  value: item.value,
                ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4D6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'Approved Partner profile details are view-only in Phase P1. '
                  'Permitted edits will use a governed change-request workflow '
                  'in Phase P2.',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primary.withValues(alpha: 0.10),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
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
