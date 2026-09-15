import '../../models/capability_definition.dart';
import '../../services/capability_metadata_provider.dart';
import 'partner_category_metadata.dart';

/// Governed capability metadata for Garment Care Partners.
///
/// Partner category:
/// garmentCare
///
/// Covers Laundry, Pressing, Stain Treatment, Dry Cleaning,
/// specialized garment care, and the common Pickup & Delivery capability.
class GarmentCarePartnerCapabilityMetadata
    implements CapabilityMetadataProvider {
  const GarmentCarePartnerCapabilityMetadata();

  static const instance = GarmentCarePartnerCapabilityMetadata();

  static const String categoryCode = PartnerCategoryMetadata.garmentCare;

  static const List<CapabilityGroupDefinition> _groups = [
    CapabilityGroupDefinition(
      code: 'garmentCare.services',
      label: 'Garment Care Services',
      partnerCategoryCode: categoryCode,
      displayOrder: 10,
    ),
    CapabilityGroupDefinition(
      code: 'garmentCare.materialSpecialization',
      label: 'Garment & Material Specialization',
      partnerCategoryCode: categoryCode,
      displayOrder: 20,
    ),
    CapabilityGroupDefinition(
      code: 'garmentCare.fulfillment',
      label: 'Collection & Delivery',
      partnerCategoryCode: categoryCode,
      displayOrder: 30,
    ),
  ];

  static const List<CapabilityDefinition> _capabilities = [
    // GARMENT CARE SERVICES
    CapabilityDefinition(
      code: 'garmentCare.laundry',
      label: 'Laundry',
      partnerCategoryCode: categoryCode,
      groupCode: 'garmentCare.services',
      displayOrder: 10,
    ),
    CapabilityDefinition(
      code: 'garmentCare.dryCleaning',
      label: 'Dry Cleaning',
      partnerCategoryCode: categoryCode,
      groupCode: 'garmentCare.services',
      displayOrder: 20,
      requiresVerification: true,
    ),
    CapabilityDefinition(
      code: 'garmentCare.pressing',
      label: 'Pressing / Ironing',
      partnerCategoryCode: categoryCode,
      groupCode: 'garmentCare.services',
      displayOrder: 30,
    ),
    CapabilityDefinition(
      code: 'garmentCare.steamPressing',
      label: 'Steam Pressing',
      partnerCategoryCode: categoryCode,
      groupCode: 'garmentCare.services',
      displayOrder: 40,
    ),
    CapabilityDefinition(
      code: 'garmentCare.rollPress',
      label: 'Roll Press',
      partnerCategoryCode: categoryCode,
      groupCode: 'garmentCare.services',
      displayOrder: 45,
    ),
    CapabilityDefinition(
      code: 'garmentCare.stainRemoval',
      label: 'Stain Removal',
      partnerCategoryCode: categoryCode,
      groupCode: 'garmentCare.services',
      displayOrder: 50,
      requiresVerification: true,
    ),
    CapabilityDefinition(
      code: 'garmentCare.fabricCare',
      label: 'Fabric Care Treatment',
      partnerCategoryCode: categoryCode,
      groupCode: 'garmentCare.services',
      displayOrder: 60,
      requiresVerification: true,
    ),
    CapabilityDefinition(
      code: 'garmentCare.sareeCare',
      label: 'Saree Care',
      partnerCategoryCode: categoryCode,
      groupCode: 'garmentCare.services',
      displayOrder: 70,
    ),
    CapabilityDefinition(
      code: 'garmentCare.specialGarmentCare',
      label: 'Special Garment Care',
      partnerCategoryCode: categoryCode,
      groupCode: 'garmentCare.services',
      displayOrder: 90,
      requiresVerification: true,
    ),

    // GARMENT AND MATERIAL SPECIALIZATION
    CapabilityDefinition(
      code: 'garmentCare.cotton',
      label: 'Cotton',
      partnerCategoryCode: categoryCode,
      groupCode: 'garmentCare.materialSpecialization',
      displayOrder: 10,
    ),
    CapabilityDefinition(
      code: 'garmentCare.silk',
      label: 'Silk',
      partnerCategoryCode: categoryCode,
      groupCode: 'garmentCare.materialSpecialization',
      displayOrder: 20,
      requiresVerification: true,
    ),
    CapabilityDefinition(
      code: 'garmentCare.linen',
      label: 'Linen',
      partnerCategoryCode: categoryCode,
      groupCode: 'garmentCare.materialSpecialization',
      displayOrder: 30,
    ),
    CapabilityDefinition(
      code: 'garmentCare.wool',
      label: 'Wool / Winter Wear',
      partnerCategoryCode: categoryCode,
      groupCode: 'garmentCare.materialSpecialization',
      displayOrder: 40,
    ),
    CapabilityDefinition(
      code: 'garmentCare.denim',
      label: 'Denim',
      partnerCategoryCode: categoryCode,
      groupCode: 'garmentCare.materialSpecialization',
      displayOrder: 50,
    ),
    CapabilityDefinition(
      code: 'garmentCare.syntheticBlend',
      label: 'Synthetic / Blended Fabric',
      partnerCategoryCode: categoryCode,
      groupCode: 'garmentCare.materialSpecialization',
      displayOrder: 60,
    ),
    CapabilityDefinition(
      code: 'garmentCare.delicateFabric',
      label: 'Delicate Fabrics',
      partnerCategoryCode: categoryCode,
      groupCode: 'garmentCare.materialSpecialization',
      displayOrder: 70,
      requiresVerification: true,
    ),
    CapabilityDefinition(
      code: 'garmentCare.embellishedGarment',
      label: 'Embroidered / Embellished Garments',
      partnerCategoryCode: categoryCode,
      groupCode: 'garmentCare.materialSpecialization',
      displayOrder: 80,
      requiresVerification: true,
    ),
    CapabilityDefinition(
      code: 'garmentCare.heavyGarment',
      label: 'Bridal / Heavy Garments',
      partnerCategoryCode: categoryCode,
      groupCode: 'garmentCare.materialSpecialization',
      displayOrder: 90,
      requiresVerification: true,
    ),

    // COLLECTION AND DELIVERY
    CapabilityDefinition(
      code: 'garmentCare.pickupDelivery',
      label: 'Pickup & Delivery',
      partnerCategoryCode: categoryCode,
      groupCode: 'garmentCare.fulfillment',
      displayOrder: 10,
    ),
  ];

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

    for (final capability in _capabilities) {
      if (capability.code == normalizedCode) {
        return capability;
      }
    }

    return null;
  }

  @override
  CapabilityGroupDefinition? groupForCode({
    required String partnerCategoryCode,
    required String groupCode,
  }) {
    for (final group in _groups) {
      if (group.active &&
          group.partnerCategoryCode == partnerCategoryCode &&
          group.code == groupCode) {
        return group;
      }
    }

    return null;
  }
}
