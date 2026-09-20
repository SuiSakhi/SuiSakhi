import 'package:flutter/material.dart';
import 'partner_workspace_screen.dart';

@Deprecated('Use PartnerWorkspaceScreen and /partner/workspace.')
class PartnerProfileLandingScreen extends StatelessWidget {
  const PartnerProfileLandingScreen({
    super.key,
    this.accountId,
    this.partnerProfileId,
    this.partnerCategoryCode,
  });
  final String? accountId;
  final String? partnerProfileId;
  final String? partnerCategoryCode;
  @override
  Widget build(BuildContext context) => PartnerWorkspaceScreen(
    accountId: accountId?.trim() ?? '',
    partnerProfileId: partnerProfileId?.trim() ?? '',
    partnerCategoryCode: partnerCategoryCode,
  );
}
