/// SuiSakhi Designer Partner Capability Metadata
///
/// Purpose:
/// Defines the governed capability groups and professional capabilities
/// available to a Designer Partner during onboarding.
///
/// Architecture:
/// - Uses the common CapabilityMetadataProvider contract.
/// - Reuses the existing CapabilityMultiSelector widget.
/// - Stores governed capability codes rather than display labels.
/// - Designer-specific application data will later be persisted under:
///   onboardingData.extensions.designer
///
/// Important:
/// This file contains metadata only. It does not persist data, perform
/// authorization, or implement Designer onboarding UI.
library;

import '../../models/capability_definition.dart';
import '../../services/capability_metadata_provider.dart';
import 'partner_category_metadata.dart';

// ============================================================================
// DESIGNER PARTNER CAPABILITY METADATA
// ============================================================================
//
// Partner category:
//   designer
//
// Designer Partner capabilities are intentionally kept separate from Tailor
// capabilities. A Designer creates/designs fashion concepts and may support
// special/custom design work; normal catalogue stitching remains assigned to
// the Tailor.
//
// Keep capability codes stable once production data depends on them.
// ============================================================================

/// Governed capability metadata for Designer Partners.
class DesignerPartnerCapabilityMetadata implements CapabilityMetadataProvider {
  const DesignerPartnerCapabilityMetadata();

  static const instance = DesignerPartnerCapabilityMetadata();

  /// Primary Partner category code.
  static const String categoryCode = PartnerCategoryMetadata.designer;

  // ==========================================================================
  // DESIGNER CAPABILITY GROUPS
  // ==========================================================================

  static const List<CapabilityGroupDefinition> _groups = [
    CapabilityGroupDefinition(
      code: 'designer.fashionDesign',
      label: 'Fashion Design',
      partnerCategoryCode: categoryCode,
      displayOrder: 10,
    ),
    CapabilityGroupDefinition(
      code: 'designer.customDesign',
      label: 'Custom & Special Design',
      partnerCategoryCode: categoryCode,
      displayOrder: 20,
    ),
    CapabilityGroupDefinition(
      code: 'designer.occasionDesign',
      label: 'Occasion & Bridal Design',
      partnerCategoryCode: categoryCode,
      displayOrder: 30,
    ),
    CapabilityGroupDefinition(
      code: 'designer.bulkAndEvents',
      label: 'Bulk & Event Design',
      partnerCategoryCode: categoryCode,
      displayOrder: 40,
    ),
  ];

  // ==========================================================================
  // DESIGNER CAPABILITIES
  // ==========================================================================

  static const List<CapabilityDefinition> _capabilities = [
    // ------------------------------------------------------------------------
    // FASHION DESIGN
    // ------------------------------------------------------------------------
    CapabilityDefinition(
      code: 'designer.fashionDesign',
      label: 'Fashion Design',
      partnerCategoryCode: categoryCode,
      groupCode: 'designer.fashionDesign',
      displayOrder: 10,
    ),

    CapabilityDefinition(
      code: 'designer.conceptDesign',
      label: 'Concept Design',
      partnerCategoryCode: categoryCode,
      groupCode: 'designer.fashionDesign',
      displayOrder: 20,
    ),

    CapabilityDefinition(
      code: 'designer.designReplication',
      label: 'Design Replication / Inspiration',
      partnerCategoryCode: categoryCode,
      groupCode: 'designer.fashionDesign',
      displayOrder: 30,
      requiresVerification: true,
    ),

    // ------------------------------------------------------------------------
    // CUSTOM & SPECIAL DESIGN
    // ------------------------------------------------------------------------
    CapabilityDefinition(
      code: 'designer.customDesign',
      label: 'Custom Design',
      partnerCategoryCode: categoryCode,
      groupCode: 'designer.customDesign',
      displayOrder: 10,
    ),

    CapabilityDefinition(
      code: 'designer.personalizedDesign',
      label: 'Personalized Customer Design',
      partnerCategoryCode: categoryCode,
      groupCode: 'designer.customDesign',
      displayOrder: 20,
    ),

    CapabilityDefinition(
      code: 'designer.specialOrderDesign',
      label: 'Special Order Design',
      partnerCategoryCode: categoryCode,
      groupCode: 'designer.customDesign',
      displayOrder: 30,
      requiresVerification: true,
    ),

    // ------------------------------------------------------------------------
    // OCCASION & BRIDAL DESIGN
    // ------------------------------------------------------------------------
    CapabilityDefinition(
      code: 'designer.weddingDesign',
      label: 'Wedding Design',
      partnerCategoryCode: categoryCode,
      groupCode: 'designer.occasionDesign',
      displayOrder: 10,
      requiresVerification: true,
    ),

    CapabilityDefinition(
      code: 'designer.bridalDesign',
      label: 'Bridal Design',
      partnerCategoryCode: categoryCode,
      groupCode: 'designer.occasionDesign',
      displayOrder: 20,
      requiresVerification: true,
      requiresCertification: true,
    ),

    CapabilityDefinition(
      code: 'designer.partyWearDesign',
      label: 'Party Wear Design',
      partnerCategoryCode: categoryCode,
      groupCode: 'designer.occasionDesign',
      displayOrder: 30,
    ),

    // ------------------------------------------------------------------------
    // BULK & EVENT DESIGN
    // ------------------------------------------------------------------------
    CapabilityDefinition(
      code: 'designer.bulkDesign',
      label: 'Bulk Design Orders',
      partnerCategoryCode: categoryCode,
      groupCode: 'designer.bulkAndEvents',
      displayOrder: 10,
      requiresVerification: true,
    ),

    CapabilityDefinition(
      code: 'designer.eventDesign',
      label: 'Event / Group Design',
      partnerCategoryCode: categoryCode,
      groupCode: 'designer.bulkAndEvents',
      displayOrder: 20,
      requiresVerification: true,
    ),

    CapabilityDefinition(
      code: 'designer.corporateDesign',
      label: 'Corporate / Institutional Design',
      partnerCategoryCode: categoryCode,
      groupCode: 'designer.bulkAndEvents',
      displayOrder: 30,
    ),
  ];

  // ==========================================================================
  // METADATA PROVIDER IMPLEMENTATION
  // ==========================================================================

  @override
  List<CapabilityGroupDefinition> groupsForPartnerCategory(
    String partnerCategoryCode,
  ) {
    return _groups
        .where(
          (group) =>
              group.active && group.partnerCategoryCode == partnerCategoryCode,
        )
        .toList()
      ..sort(
        (first, second) => first.displayOrder.compareTo(second.displayOrder),
      );
  }

  @override
  List<CapabilityDefinition> capabilitiesForPartnerCategory(
    String partnerCategoryCode,
  ) {
    return _capabilities
        .where(
          (capability) =>
              capability.active &&
              capability.partnerCategoryCode == partnerCategoryCode,
        )
        .toList()
      ..sort(
        (first, second) => first.displayOrder.compareTo(second.displayOrder),
      );
  }

  @override
  List<CapabilityDefinition> capabilitiesForGroup({
    required String partnerCategoryCode,
    required String groupCode,
  }) {
    return _capabilities
        .where(
          (capability) =>
              capability.active &&
              capability.partnerCategoryCode == partnerCategoryCode &&
              capability.groupCode == groupCode,
        )
        .toList()
      ..sort(
        (first, second) => first.displayOrder.compareTo(second.displayOrder),
      );
  }

  @override
  CapabilityDefinition? capabilityForCode(String? capabilityCode) {
    final normalizedCode = capabilityCode?.trim();

    if (normalizedCode == null || normalizedCode.isEmpty) {
      return null;
    }

    try {
      return _capabilities.firstWhere(
        (capability) => capability.code == normalizedCode,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  CapabilityGroupDefinition? groupForCode({
    required String partnerCategoryCode,
    required String groupCode,
  }) {
    final normalizedGroupCode = groupCode.trim();

    if (normalizedGroupCode.isEmpty) {
      return null;
    }

    try {
      return _groups.firstWhere(
        (group) =>
            group.active &&
            group.partnerCategoryCode == partnerCategoryCode &&
            group.code == normalizedGroupCode,
      );
    } catch (_) {
      return null;
    }
  }
}
