import '../../models/capability_definition.dart';
import '../../services/capability_metadata_provider.dart';
import 'partner_category_metadata.dart';

/// Governed capability metadata for SuiSakhi QuickCare Partners.
///
/// Stable internal Partner category: doorstepServices.
class QuickCarePartnerCapabilityMetadata implements CapabilityMetadataProvider {
  const QuickCarePartnerCapabilityMetadata();

  static const instance = QuickCarePartnerCapabilityMetadata();
  static const String categoryCode = PartnerCategoryMetadata.doorstepServices;

  static const List<CapabilityGroupDefinition> _groups = [
    CapabilityGroupDefinition(
      code: 'doorstepServices.garmentRepair',
      label: 'Garment Repair',
      partnerCategoryCode: categoryCode,
      displayOrder: 10,
    ),
    CapabilityGroupDefinition(
      code: 'doorstepServices.garmentAssistance',
      label: 'Garment Assistance',
      partnerCategoryCode: categoryCode,
      displayOrder: 20,
    ),
    CapabilityGroupDefinition(
      code: 'doorstepServices.fieldServices',
      label: 'Field Services',
      partnerCategoryCode: categoryCode,
      displayOrder: 30,
    ),
  ];

  static const List<CapabilityDefinition> _capabilities = [
    CapabilityDefinition(
      code: 'doorstepServices.picoFall',
      label: 'Pico & Fall',
      partnerCategoryCode: categoryCode,
      groupCode: 'doorstepServices.garmentRepair',
      displayOrder: 10,
    ),
    CapabilityDefinition(
      code: 'doorstepServices.buttonReplacement',
      label: 'Button Replacement',
      partnerCategoryCode: categoryCode,
      groupCode: 'doorstepServices.garmentRepair',
      displayOrder: 20,
    ),
    CapabilityDefinition(
      code: 'doorstepServices.hookRepair',
      label: 'Hook Repair',
      partnerCategoryCode: categoryCode,
      groupCode: 'doorstepServices.garmentRepair',
      displayOrder: 30,
    ),
    CapabilityDefinition(
      code: 'doorstepServices.zipRepair',
      label: 'Zip Repair',
      partnerCategoryCode: categoryCode,
      groupCode: 'doorstepServices.garmentRepair',
      displayOrder: 40,
    ),
    CapabilityDefinition(
      code: 'doorstepServices.elasticReplacement',
      label: 'Elastic Replacement',
      partnerCategoryCode: categoryCode,
      groupCode: 'doorstepServices.garmentRepair',
      displayOrder: 50,
    ),
    CapabilityDefinition(
      code: 'doorstepServices.minorStitchRepair',
      label: 'Minor Stitch Repair',
      partnerCategoryCode: categoryCode,
      groupCode: 'doorstepServices.garmentRepair',
      displayOrder: 60,
    ),
    CapabilityDefinition(
      code: 'doorstepServices.minorTearRepair',
      label: 'Minor Tear Repair',
      partnerCategoryCode: categoryCode,
      groupCode: 'doorstepServices.garmentRepair',
      displayOrder: 70,
    ),
    CapabilityDefinition(
      code: 'doorstepServices.raffu',
      label: 'Raffu',
      partnerCategoryCode: categoryCode,
      groupCode: 'doorstepServices.garmentRepair',
      displayOrder: 80,
      requiresVerification: true,
    ),
    CapabilityDefinition(
      code: 'doorstepServices.minorAlteration',
      label: 'Minor Alteration',
      partnerCategoryCode: categoryCode,
      groupCode: 'doorstepServices.garmentRepair',
      displayOrder: 90,
    ),
    CapabilityDefinition(
      code: 'doorstepServices.blouseFitting',
      label: 'Blouse Fitting',
      partnerCategoryCode: categoryCode,
      groupCode: 'doorstepServices.garmentRepair',
      displayOrder: 100,
      requiresVerification: true,
    ),
    CapabilityDefinition(
      code: 'doorstepServices.embroideryRepair',
      label: 'Embroidery Repair',
      partnerCategoryCode: categoryCode,
      groupCode: 'doorstepServices.garmentRepair',
      displayOrder: 110,
      requiresVerification: true,
    ),
    CapabilityDefinition(
      code: 'doorstepServices.traditionalStitchRepair',
      label: 'Traditional Stitch Repair',
      partnerCategoryCode: categoryCode,
      groupCode: 'doorstepServices.garmentRepair',
      displayOrder: 120,
      requiresVerification: true,
    ),
    CapabilityDefinition(
      code: 'doorstepServices.emergencyStitchRepair',
      label: 'Emergency Stitch Repair',
      partnerCategoryCode: categoryCode,
      groupCode: 'doorstepServices.garmentRepair',
      displayOrder: 130,
      requiresVerification: true,
    ),

    CapabilityDefinition(
      code: 'doorstepServices.sareeDraping',
      label: 'Saree Draping',
      partnerCategoryCode: categoryCode,
      groupCode: 'doorstepServices.garmentAssistance',
      displayOrder: 10,
    ),
    CapabilityDefinition(
      code: 'doorstepServices.sareePrePleating',
      label: 'Saree Pre-Pleating',
      partnerCategoryCode: categoryCode,
      groupCode: 'doorstepServices.garmentAssistance',
      displayOrder: 20,
    ),
    CapabilityDefinition(
      code: 'doorstepServices.sareeFolding',
      label: 'Saree Folding',
      partnerCategoryCode: categoryCode,
      groupCode: 'doorstepServices.garmentAssistance',
      displayOrder: 30,
    ),
    CapabilityDefinition(
      code: 'doorstepServices.wardrobeAssistance',
      label: 'Wardrobe Assistance',
      partnerCategoryCode: categoryCode,
      groupCode: 'doorstepServices.garmentAssistance',
      displayOrder: 40,
    ),
    CapabilityDefinition(
      code: 'doorstepServices.wardrobeReorganization',
      label: 'Wardrobe Reorganization',
      partnerCategoryCode: categoryCode,
      groupCode: 'doorstepServices.garmentAssistance',
      displayOrder: 50,
    ),
    CapabilityDefinition(
      code: 'doorstepServices.occasionDressingAssistance',
      label: 'Occasion Dressing Assistance',
      partnerCategoryCode: categoryCode,
      groupCode: 'doorstepServices.garmentAssistance',
      displayOrder: 60,
    ),
    CapabilityDefinition(
      code: 'doorstepServices.eventReadiness',
      label: 'Event Readiness Services',
      partnerCategoryCode: categoryCode,
      groupCode: 'doorstepServices.garmentAssistance',
      displayOrder: 70,
    ),
    CapabilityDefinition(
      code: 'doorstepServices.stylingCoordination',
      label: 'Styling / Dress Coordination',
      partnerCategoryCode: categoryCode,
      groupCode: 'doorstepServices.garmentAssistance',
      displayOrder: 80,
    ),
    CapabilityDefinition(
      code: 'doorstepServices.designAssistance',
      label: 'Design Assistance',
      partnerCategoryCode: categoryCode,
      groupCode: 'doorstepServices.garmentAssistance',
      displayOrder: 90,
    ),

    CapabilityDefinition(
      code: 'doorstepServices.measurementVisit',
      label: 'Measurement Visit',
      partnerCategoryCode: categoryCode,
      groupCode: 'doorstepServices.fieldServices',
      displayOrder: 10,
      requiresVerification: true,
    ),
    CapabilityDefinition(
      code: 'doorstepServices.homeVisit',
      label: 'Home Visit Available',
      partnerCategoryCode: categoryCode,
      groupCode: 'doorstepServices.fieldServices',
      displayOrder: 20,
    ),
    CapabilityDefinition(
      code: 'doorstepServices.pickupDelivery',
      label: 'Pickup & Delivery Available',
      partnerCategoryCode: categoryCode,
      groupCode: 'doorstepServices.fieldServices',
      displayOrder: 30,
    ),
  ];

  @override
  List<CapabilityGroupDefinition> groupsForPartnerCategory(String code) =>
      _groups
          .where((item) => item.active && item.partnerCategoryCode == code)
          .toList()
        ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

  @override
  List<CapabilityDefinition> capabilitiesForPartnerCategory(String code) =>
      _capabilities
          .where((item) => item.active && item.partnerCategoryCode == code)
          .toList()
        ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

  @override
  List<CapabilityDefinition> capabilitiesForGroup({
    required String partnerCategoryCode,
    required String groupCode,
  }) =>
      _capabilities
          .where(
            (item) =>
                item.active &&
                item.partnerCategoryCode == partnerCategoryCode &&
                item.groupCode == groupCode,
          )
          .toList()
        ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

  @override
  CapabilityDefinition? capabilityForCode(String? capabilityCode) {
    final code = capabilityCode?.trim();
    if (code == null || code.isEmpty) return null;
    for (final item in _capabilities) {
      if (item.code == code) {
        return item;
      }
    }
    return null;
  }

  @override
  CapabilityGroupDefinition? groupForCode({
    required String partnerCategoryCode,
    required String groupCode,
  }) {
    for (final item in _groups) {
      if (item.active &&
          item.partnerCategoryCode == partnerCategoryCode &&
          item.code == groupCode) {
        return item;
      }
    }
    return null;
  }
}
