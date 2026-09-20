import 'package:flutter/material.dart';

enum PartnerWorkspaceModuleState {
  available,
  viewOnly,
  comingSoon,
  requiresSetup,
  adminReviewRequired,
}

class PartnerWorkspaceModule {
  const PartnerWorkspaceModule({
    required this.code,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.section,
    this.route,
    this.state = PartnerWorkspaceModuleState.comingSoon,
    this.order = 0,
  });

  final String code;
  final String label;
  final String subtitle;
  final IconData icon;
  final String section;
  final String? route;
  final PartnerWorkspaceModuleState state;
  final int order;

  bool get isEnabled =>
      state == PartnerWorkspaceModuleState.available ||
      state == PartnerWorkspaceModuleState.viewOnly;
}
