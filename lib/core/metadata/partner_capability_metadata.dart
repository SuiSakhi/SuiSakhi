import '../../models/capability_definition.dart';
import '../../services/capability_metadata_provider.dart';

class PartnerCapabilityMetadata implements CapabilityMetadataProvider {
  const PartnerCapabilityMetadata();

  static const instance = PartnerCapabilityMetadata();

  static const String tailorCategoryCode = 'tailor';

  static const List<CapabilityGroupDefinition> _groups = [
    CapabilityGroupDefinition(
      code: 'tailor.garmentStitching',
      label: 'Garment Stitching',
      partnerCategoryCode: tailorCategoryCode,
      displayOrder: 10,
    ),
    CapabilityGroupDefinition(
      code: 'tailor.alterationRepair',
      label: 'Alteration & Repair',
      partnerCategoryCode: tailorCategoryCode,
      displayOrder: 20,
    ),
    CapabilityGroupDefinition(
      code: 'tailor.decorativeWork',
      label: 'Decorative Work',
      partnerCategoryCode: tailorCategoryCode,
      displayOrder: 30,
    ),
    CapabilityGroupDefinition(
      code: 'tailor.specialOrders',
      label: 'Special Orders',
      partnerCategoryCode: tailorCategoryCode,
      displayOrder: 40,
    ),
  ];

  static const List<CapabilityDefinition> _capabilities = [
    CapabilityDefinition(
      code: 'tailor.blouseStitching',
      label: 'Blouse Stitching',
      partnerCategoryCode: tailorCategoryCode,
      groupCode: 'tailor.garmentStitching',
      displayOrder: 10,
    ),
    CapabilityDefinition(
      code: 'tailor.kurtiSuit',
      label: 'Kurti / Suit',
      partnerCategoryCode: tailorCategoryCode,
      groupCode: 'tailor.garmentStitching',
      displayOrder: 20,
    ),
    CapabilityDefinition(
      code: 'tailor.dressStitching',
      label: 'Dress Stitching',
      partnerCategoryCode: tailorCategoryCode,
      groupCode: 'tailor.garmentStitching',
      displayOrder: 30,
    ),
    CapabilityDefinition(
      code: 'tailor.lehenga',
      label: 'Lehenga',
      partnerCategoryCode: tailorCategoryCode,
      groupCode: 'tailor.garmentStitching',
      displayOrder: 40,
      requiresVerification: true,
    ),
    CapabilityDefinition(
      code: 'tailor.bridalWear',
      label: 'Bridal Wear',
      partnerCategoryCode: tailorCategoryCode,
      groupCode: 'tailor.garmentStitching',
      displayOrder: 50,
      requiresVerification: true,
      requiresCertification: true,
    ),
    CapabilityDefinition(
      code: 'tailor.designerWear',
      label: 'Designer Wear',
      partnerCategoryCode: tailorCategoryCode,
      groupCode: 'tailor.garmentStitching',
      displayOrder: 60,
      requiresVerification: true,
    ),
    CapabilityDefinition(
      code: 'tailor.designerReplication',
      label: 'Designer Replication',
      partnerCategoryCode: tailorCategoryCode,
      groupCode: 'tailor.garmentStitching',
      displayOrder: 70,
      requiresVerification: true,
    ),
    CapabilityDefinition(
      code: 'tailor.girlsWear',
      label: 'Girls Wear',
      partnerCategoryCode: tailorCategoryCode,
      groupCode: 'tailor.garmentStitching',
      displayOrder: 80,
    ),
    CapabilityDefinition(
      code: 'tailor.alteration',
      label: 'Alteration',
      partnerCategoryCode: tailorCategoryCode,
      groupCode: 'tailor.alterationRepair',
      displayOrder: 10,
    ),
    CapabilityDefinition(
      code: 'tailor.sareePicoFall',
      label: 'Saree Pico / Fall',
      partnerCategoryCode: tailorCategoryCode,
      groupCode: 'tailor.alterationRepair',
      displayOrder: 20,
    ),
    CapabilityDefinition(
      code: 'tailor.embroidery',
      label: 'Embroidery',
      partnerCategoryCode: tailorCategoryCode,
      groupCode: 'tailor.decorativeWork',
      displayOrder: 10,
      requiresVerification: true,
    ),
    CapabilityDefinition(
      code: 'tailor.aari',
      label: 'Aari Work',
      partnerCategoryCode: tailorCategoryCode,
      groupCode: 'tailor.decorativeWork',
      displayOrder: 20,
      requiresVerification: true,
    ),
    CapabilityDefinition(
      code: 'tailor.zardozi',
      label: 'Zardozi Work',
      partnerCategoryCode: tailorCategoryCode,
      groupCode: 'tailor.decorativeWork',
      displayOrder: 30,
      requiresVerification: true,
    ),
    CapabilityDefinition(
      code: 'tailor.schoolUniform',
      label: 'School Uniforms',
      partnerCategoryCode: tailorCategoryCode,
      groupCode: 'tailor.specialOrders',
      displayOrder: 10,
    ),
    CapabilityDefinition(
      code: 'tailor.weddingOrders',
      label: 'Wedding Orders',
      partnerCategoryCode: tailorCategoryCode,
      groupCode: 'tailor.specialOrders',
      displayOrder: 20,
      requiresVerification: true,
    ),
    CapabilityDefinition(
      code: 'tailor.urgentOrders',
      label: 'Urgent Orders',
      partnerCategoryCode: tailorCategoryCode,
      groupCode: 'tailor.specialOrders',
      displayOrder: 30,
      requiresVerification: true,
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
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
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
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
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
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
  }

  @override
  CapabilityDefinition? capabilityForCode(String? capabilityCode) {
    if (capabilityCode == null) {
      return null;
    }

    try {
      return _capabilities.firstWhere(
        (capability) => capability.code == capabilityCode,
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
