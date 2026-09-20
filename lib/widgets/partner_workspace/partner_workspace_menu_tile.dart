import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/partner_workspace_module.dart';

class PartnerWorkspaceMenuTile extends StatelessWidget {
  const PartnerWorkspaceMenuTile({
    super.key,
    required this.module,
    required this.onTap,
  });
  final PartnerWorkspaceModule module;
  final VoidCallback? onTap;

  String get _stateLabel => switch (module.state) {
    PartnerWorkspaceModuleState.available => 'Available',
    PartnerWorkspaceModuleState.viewOnly => 'View only',
    PartnerWorkspaceModuleState.comingSoon => 'Coming soon',
    PartnerWorkspaceModuleState.requiresSetup => 'Requires setup',
    PartnerWorkspaceModuleState.adminReviewRequired => 'Admin review',
  };

  @override
  Widget build(BuildContext context) {
    final destructive = module.code == 'account.logout';
    final color = destructive ? AppColors.error : AppColors.primary;
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.10),
          child: Icon(module.icon, color: color),
        ),
        title: Text(
          module.label,
          style: AppTextStyles.titleMedium.copyWith(
            color: destructive ? AppColors.error : AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              module.subtitle,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              _stateLabel,
              style: AppTextStyles.bodySmall.copyWith(
                color: module.isEnabled ? color : AppColors.textHint,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        trailing: module.isEnabled
            ? const Icon(Icons.chevron_right_rounded)
            : const Icon(Icons.lock_clock_outlined, size: 19),
        onTap: onTap,
      ),
    );
  }
}
