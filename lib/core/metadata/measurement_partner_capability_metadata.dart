import '../../models/capability_definition.dart';
import '../../services/capability_metadata_provider.dart';
import 'partner_category_metadata.dart';

// ============================================================================
// MEASUREMENT PARTNER EXTENSION
// ============================================================================
//
// This metadata defines measurement services for a Partner whose primary
// business category is Measurement Partner.
//
// MEASUREMENT AUTHORITY RULE:
//
// - A Measurement Partner may collect and record measurement information.
// - A Measurement Partner may provide measurement-only services.
// - A Measurement Partner may provide measurement plus pickup services.
// - AI or camera measurement remains an estimate only.
// - The assigned Tailor must review all available measurement inputs.
// - Only the assigned Tailor can confirm the final measurement version.
// - Cutting or stitching must not begin before Tailor confirmation.
//
// ECOSYSTEM PRINCIPLE:
//
// Partner category represents the primary business identity.
// Service capabilities represent the services that a Partner can perform.
//
// Similar measurement capabilities may later be enabled for Tailor, Boutique,
// Doorstep Services, or another eligible Partner category through a shared
// multi-service capability registry.
//
// Keep capability and group codes stable after production data is created.
// ============================================================================

/// Governed capability metadata for dedicated Measurement Partners.
///
/// This implementation uses the common [CapabilityMetadataProvider] contract,
/// allowing the existing CapabilityMultiSelector widget to be reused.
///
/// Measurement collection and final measurement confirmation are separate:
///
/// - Measurement Partner: collects and records measurement inputs.
/// - Assigned Tailor: confirms the final measurement before stitching.
class MeasurementPartnerCapabilityMetadata
    implements CapabilityMetadataProvider {
  const MeasurementPartnerCapabilityMetadata();

  static const instance = MeasurementPartnerCapabilityMetadata();

  /// Primary category code for an independent Measurement Partner.
  static const String categoryCode = PartnerCategoryMetadata.measurementPartner;

  // ==========================================================================
  // MEASUREMENT SERVICE GROUPS
  // ==========================================================================

  static const List<CapabilityGroupDefinition> _groups = [
    CapabilityGroupDefinition(
      code: 'measurement.collection',
      label: 'Measurement Collection',
      partnerCategoryCode: categoryCode,
      displayOrder: 10,
    ),
    CapabilityGroupDefinition(
      code: 'measurement.remoteAssistance',
      label: 'Remote Measurement Assistance',
      partnerCategoryCode: categoryCode,
      displayOrder: 20,
    ),
    CapabilityGroupDefinition(
      code: 'measurement.referenceSupport',
      label: 'Reference Garment Support',
      partnerCategoryCode: categoryCode,
      displayOrder: 30,
    ),
    CapabilityGroupDefinition(
      code: 'measurement.logistics',
      label: 'Measurement Logistics',
      partnerCategoryCode: categoryCode,
      displayOrder: 40,
    ),
  ];

  // ==========================================================================
  // MEASUREMENT-SPECIFIC CAPABILITIES
  // ==========================================================================
  static const List<CapabilityDefinition> _capabilities = [
    // ------------------------------------------------------------------------
    // MEASUREMENT COLLECTION
    // ------------------------------------------------------------------------
    CapabilityDefinition(
      code: 'measurement.measurementOnly',
      label: 'Measurement Only',
      partnerCategoryCode: categoryCode,
      groupCode: 'measurement.collection',
      displayOrder: 10,
    ),
    CapabilityDefinition(
      code: 'measurement.homeVisit',
      label: 'Home Measurement Visit',
      partnerCategoryCode: categoryCode,
      groupCode: 'measurement.collection',
      displayOrder: 20,
      requiresVerification: true,
    ),

    // ------------------------------------------------------------------------
    // REMOTE MEASUREMENT ASSISTANCE
    // ------------------------------------------------------------------------
    CapabilityDefinition(
      code: 'measurement.videoAssisted',
      label: 'Video-Assisted Measurement',
      partnerCategoryCode: categoryCode,
      groupCode: 'measurement.remoteAssistance',
      displayOrder: 10,
      requiresVerification: true,
    ),

    // ------------------------------------------------------------------------
    // REFERENCE GARMENT SUPPORT
    // ------------------------------------------------------------------------
    CapabilityDefinition(
      code: 'measurement.referenceGarment',
      label: 'Reference Garment Measurement',
      partnerCategoryCode: categoryCode,
      groupCode: 'measurement.referenceSupport',
      displayOrder: 10,
      requiresVerification: true,
    ),
    CapabilityDefinition(
      code: 'measurement.referenceGarmentPickup',
      label: 'Reference Garment Pickup',
      partnerCategoryCode: categoryCode,
      groupCode: 'measurement.referenceSupport',
      displayOrder: 20,
    ),

    // ------------------------------------------------------------------------
    // SHARED MULTI-SERVICE CAPABILITY
    // ------------------------------------------------------------------------
    //
    // These logistics capabilities are initially registered for Measurement
    // Partners. A later shared logistics registry may expose equivalent
    // governed services to Tailor, Doorstep Services, Delivery Partner, and
    // other eligible Partner categories.
    // ------------------------------------------------------------------------
    CapabilityDefinition(
      code: 'measurement.measurementAndPickup',
      label: 'Measurement and Pickup',
      partnerCategoryCode: categoryCode,
      groupCode: 'measurement.logistics',
      displayOrder: 10,
      requiresVerification: true,
    ),
    CapabilityDefinition(
      code: 'measurement.pickupAndDrop',
      label: 'Pickup and Drop',
      partnerCategoryCode: categoryCode,
      groupCode: 'measurement.logistics',
      displayOrder: 20,
      requiresVerification: true,
    ),
  ];

  // ==========================================================================
  // COMMON CAPABILITY METADATA PROVIDER IMPLEMENTATION
  // ==========================================================================
  //
  // The methods below intentionally follow the same provider contract used by
  // Tailor capability metadata. Do not duplicate this filtering logic in
  // Measurement Partner screens.
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
    try {
      return _groups.firstWhere(
        (group) =>
            group.partnerCategoryCode == partnerCategoryCode &&
            group.code == groupCode,
      );
    } catch (_) {
      return null;
    }
  }
}
