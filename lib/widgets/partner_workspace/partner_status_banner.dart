import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/partner_workspace_profile.dart';

class PartnerStatusBanner extends StatelessWidget {
  const PartnerStatusBanner({super.key, required this.profile});
  final PartnerWorkspaceProfile profile;

  @override
  Widget build(BuildContext context) {
    if (profile.canUseOperations) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4D6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, color: AppColors.warning),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Some Partner operations are restricted. Review the profile status or contact SuiSakhi Support.',
            ),
          ),
        ],
      ),
    );
  }
}
