import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/partner_workspace_profile.dart';
import '../../services/partner_workspace_registry.dart';

class PartnerWorkspaceHeader extends StatelessWidget {
  const PartnerWorkspaceHeader({super.key, required this.profile});

  final PartnerWorkspaceProfile profile;

  @override
  Widget build(BuildContext context) {
    final photoUrl = profile.profilePhotoUrl?.trim() ?? '';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.primary.withValues(alpha: 0.10),
            backgroundImage: photoUrl.isEmpty ? null : NetworkImage(photoUrl),
            child: photoUrl.isEmpty
                ? Text(
                    profile.initial,
                    style: AppTextStyles.titleLarge.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.businessDisplayName,
                  style: AppTextStyles.titleLarge.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  PartnerWorkspaceRegistry.categoryLabel(profile.partnerType),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _badge('Approved', AppColors.success),
                    _badge('KYC Verified', AppColors.primary),
                    _badge(
                      profile.isOperationallyActive
                          ? 'Operationally Active'
                          : 'Restricted',
                      profile.isOperationallyActive
                          ? AppColors.success
                          : AppColors.error,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(
            PartnerWorkspaceRegistry.categoryIcon(profile.partnerType),
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Text(
      label,
      style: AppTextStyles.bodySmall.copyWith(
        color: color,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
