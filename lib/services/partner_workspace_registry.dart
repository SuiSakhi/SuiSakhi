import 'package:flutter/material.dart';

import '../models/partner_workspace_definition.dart';
import '../models/partner_workspace_module.dart';

class PartnerWorkspaceRegistry {
  PartnerWorkspaceRegistry._();

  static const profileSection = 'Profile';
  static const financeSection = 'Business & Finance';
  static const performanceSection = 'Performance';
  static const supportSection = 'Communication & Support';
  static const accountSection = 'Account';
  static const operationsSection = 'Category Operations';

  static const sections = <String>[
    profileSection,
    financeSection,
    performanceSection,
    supportSection,
    accountSection,
    operationsSection,
  ];

  static String categoryLabel(String code) => switch (code.trim()) {
    'tailor' => 'Tailor Partner',
    'measurementPartner' => 'Measurement Partner',
    'garmentCare' => 'Garment Care Partner',
    'boutique' => 'Boutique Partner',
    'designer' => 'Designer Partner',
    'fabricSupplier' => 'Fabric Supplier',
    'printing' => 'Printing Partner',
    'embroidery' => 'Embroidery Partner',
    'rental' => 'Rental Partner',
    'accessories' => 'Accessories Partner',
    'brand' => 'Brand Partner',
    'deliveryPartner' => 'Delivery Partner',
    'doorstepServices' => 'QuickCare Partner',
    _ => 'SuiSakhi Partner',
  };

  static IconData categoryIcon(String code) => switch (code.trim()) {
    'tailor' => Icons.content_cut_rounded,
    'measurementPartner' => Icons.straighten_rounded,
    'garmentCare' => Icons.local_laundry_service_outlined,
    'boutique' => Icons.storefront_outlined,
    'designer' => Icons.design_services_outlined,
    'fabricSupplier' => Icons.inventory_2_outlined,
    'printing' => Icons.print_outlined,
    'embroidery' => Icons.auto_awesome_outlined,
    'rental' => Icons.checkroom_outlined,
    'accessories' => Icons.watch_outlined,
    'brand' => Icons.business_outlined,
    'deliveryPartner' => Icons.local_shipping_outlined,
    'doorstepServices' => Icons.home_repair_service_outlined,
    _ => Icons.handshake_outlined,
  };

  static PartnerWorkspaceDefinition definitionFor(String partnerType) {
    final modules = <PartnerWorkspaceModule>[
      const PartnerWorkspaceModule(
        code: 'profile.view',
        label: 'My Profile',
        subtitle: 'View approved Partner profile',
        icon: Icons.person_outline_rounded,
        section: profileSection,
        route: 'profile',
        state: PartnerWorkspaceModuleState.viewOnly,
        order: 10,
      ),
      const PartnerWorkspaceModule(
        code: 'profile.business',
        label: 'Business Details',
        subtitle: 'Approved business and category-specific information',
        icon: Icons.storefront_outlined,
        section: profileSection,
        route: 'business-details',
        state: PartnerWorkspaceModuleState.viewOnly,
        order: 20,
      ),
      const PartnerWorkspaceModule(
        code: 'profile.addresses',
        label: 'Addresses',
        subtitle: 'Approved business, service and pickup locations',
        icon: Icons.location_on_outlined,
        section: profileSection,
        route: 'partner-addresses',
        state: PartnerWorkspaceModuleState.viewOnly,
        order: 30,
      ),
      const PartnerWorkspaceModule(
        code: 'profile.team',
        label: 'Team Members',
        subtitle: 'People who support Partner operations',
        icon: Icons.groups_outlined,
        section: profileSection,
        state: PartnerWorkspaceModuleState.comingSoon,
        order: 40,
      ),
      const PartnerWorkspaceModule(
        code: 'profile.preferences',
        label: 'Operational Preferences',
        subtitle: 'Availability, capacity and service settings',
        icon: Icons.tune_rounded,
        section: profileSection,
        state: PartnerWorkspaceModuleState.comingSoon,
        order: 50,
      ),
      const PartnerWorkspaceModule(
        code: 'finance.requests',
        label: 'Service Requests / Orders',
        subtitle: 'Open the applicable operational queue',
        icon: Icons.receipt_long_outlined,
        section: financeSection,
        state: PartnerWorkspaceModuleState.comingSoon,
        order: 10,
      ),
      const PartnerWorkspaceModule(
        code: 'finance.commercials',
        label: 'Rates & Commercials',
        subtitle: 'Category-specific rates and commercial terms',
        icon: Icons.currency_rupee_rounded,
        section: financeSection,
        state: PartnerWorkspaceModuleState.comingSoon,
        order: 20,
      ),
      const PartnerWorkspaceModule(
        code: 'finance.payouts',
        label: 'Payouts',
        subtitle: 'Balances, schedules and settlement status',
        icon: Icons.account_balance_wallet_outlined,
        section: financeSection,
        state: PartnerWorkspaceModuleState.comingSoon,
        order: 30,
      ),
      const PartnerWorkspaceModule(
        code: 'finance.statements',
        label: 'Statements',
        subtitle: 'Transparent transaction and payout history',
        icon: Icons.description_outlined,
        section: financeSection,
        state: PartnerWorkspaceModuleState.comingSoon,
        order: 40,
      ),
      const PartnerWorkspaceModule(
        code: 'performance.ratings',
        label: 'Ratings & Reviews',
        subtitle: 'Customer ratings and governed feedback',
        icon: Icons.star_border_rounded,
        section: performanceSection,
        state: PartnerWorkspaceModuleState.comingSoon,
        order: 10,
      ),
      const PartnerWorkspaceModule(
        code: 'performance.feedback',
        label: 'Customer Feedback',
        subtitle: 'Positive feedback and improvement areas',
        icon: Icons.forum_outlined,
        section: performanceSection,
        state: PartnerWorkspaceModuleState.comingSoon,
        order: 20,
      ),
      const PartnerWorkspaceModule(
        code: 'performance.insights',
        label: 'Improvement Insights',
        subtitle: 'Actionable guidance to improve services',
        icon: Icons.insights_outlined,
        section: performanceSection,
        state: PartnerWorkspaceModuleState.comingSoon,
        order: 30,
      ),
      const PartnerWorkspaceModule(
        code: 'support.notifications',
        label: 'Notifications',
        subtitle: 'Business, review and operational updates',
        icon: Icons.notifications_none_rounded,
        section: supportSection,
        state: PartnerWorkspaceModuleState.comingSoon,
        order: 10,
      ),
      const PartnerWorkspaceModule(
        code: 'support.help',
        label: 'Help & Support',
        subtitle: 'Raise and track support requests',
        icon: Icons.support_agent_rounded,
        section: supportSection,
        state: PartnerWorkspaceModuleState.comingSoon,
        order: 20,
      ),
      const PartnerWorkspaceModule(
        code: 'account.changeProfile',
        label: 'Change Profile',
        subtitle: 'Switch Customer or Partner profile',
        icon: Icons.switch_account_outlined,
        section: accountSection,
        route: 'change-profile',
        state: PartnerWorkspaceModuleState.available,
        order: 10,
      ),
      const PartnerWorkspaceModule(
        code: 'account.logout',
        label: 'Logout',
        subtitle: 'Sign out from SuiSakhi',
        icon: Icons.logout_rounded,
        section: accountSection,
        route: 'logout',
        state: PartnerWorkspaceModuleState.available,
        order: 20,
      ),
    ];
    if (partnerType == 'designer') {
      modules.add(
        const PartnerWorkspaceModule(
          code: 'designer.catalogue',
          label: 'My Catalogue Designs',
          subtitle: 'Upload, review and manage governed Designs',
          icon: Icons.design_services_outlined,
          section: operationsSection,
          route: 'designer-catalogue',
          state: PartnerWorkspaceModuleState.available,
          order: 10,
        ),
      );
    } else {
      modules.add(
        PartnerWorkspaceModule(
          code: '$partnerType.operations',
          label: '${categoryLabel(partnerType)} Operations',
          subtitle:
              'Category operations will be connected in the next implementation phase',
          icon: categoryIcon(partnerType),
          section: operationsSection,
          state: PartnerWorkspaceModuleState.comingSoon,
          order: 10,
        ),
      );
    }
    return PartnerWorkspaceDefinition(
      partnerType: partnerType,
      categoryLabel: categoryLabel(partnerType),
      modules: modules,
    );
  }
}
