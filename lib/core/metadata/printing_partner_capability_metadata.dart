import '../../models/capability_definition.dart';
import '../../services/capability_metadata_provider.dart';

class PrintingPartnerCapabilityMetadata implements CapabilityMetadataProvider {
  const PrintingPartnerCapabilityMetadata();
  static const instance = PrintingPartnerCapabilityMetadata();
  static const String categoryCode = 'printing';

  static const List<CapabilityGroupDefinition> _groups = [
    CapabilityGroupDefinition(
      code: 'printing.services',
      label: 'Printing Services',
      partnerCategoryCode: categoryCode,
      displayOrder: 10,
    ),
    CapabilityGroupDefinition(
      code: 'printing.materials',
      label: 'Material Compatibility',
      partnerCategoryCode: categoryCode,
      displayOrder: 20,
    ),
    CapabilityGroupDefinition(
      code: 'printing.fulfillment',
      label: 'Collection & Delivery',
      partnerCategoryCode: categoryCode,
      displayOrder: 30,
    ),
  ];

  static const List<CapabilityDefinition> _capabilities = [
    CapabilityDefinition(
      code: 'printing.digitalPrinting',
      label: 'Digital Printing',
      partnerCategoryCode: categoryCode,
      groupCode: 'printing.services',
      displayOrder: 10,
    ),
    CapabilityDefinition(
      code: 'printing.screenPrinting',
      label: 'Screen Printing',
      partnerCategoryCode: categoryCode,
      groupCode: 'printing.services',
      displayOrder: 20,
    ),
    CapabilityDefinition(
      code: 'printing.dtfPrinting',
      label: 'DTF Printing',
      partnerCategoryCode: categoryCode,
      groupCode: 'printing.services',
      displayOrder: 30,
    ),
    CapabilityDefinition(
      code: 'printing.sublimation',
      label: 'Sublimation',
      partnerCategoryCode: categoryCode,
      groupCode: 'printing.services',
      displayOrder: 40,
    ),
    CapabilityDefinition(
      code: 'printing.vinylHeatTransfer',
      label: 'Vinyl / Heat Transfer',
      partnerCategoryCode: categoryCode,
      groupCode: 'printing.services',
      displayOrder: 50,
    ),
    CapabilityDefinition(
      code: 'printing.customLogoPrinting',
      label: 'Custom Logo Printing',
      partnerCategoryCode: categoryCode,
      groupCode: 'printing.services',
      displayOrder: 60,
    ),
    CapabilityDefinition(
      code: 'printing.nameNumberPrinting',
      label: 'Name / Number Printing',
      partnerCategoryCode: categoryCode,
      groupCode: 'printing.services',
      displayOrder: 70,
    ),
    CapabilityDefinition(
      code: 'printing.uniformPrinting',
      label: 'Uniform Printing',
      partnerCategoryCode: categoryCode,
      groupCode: 'printing.services',
      displayOrder: 80,
    ),
    CapabilityDefinition(
      code: 'printing.cotton',
      label: 'Cotton',
      partnerCategoryCode: categoryCode,
      groupCode: 'printing.materials',
      displayOrder: 10,
    ),
    CapabilityDefinition(
      code: 'printing.polyester',
      label: 'Polyester',
      partnerCategoryCode: categoryCode,
      groupCode: 'printing.materials',
      displayOrder: 20,
    ),
    CapabilityDefinition(
      code: 'printing.silk',
      label: 'Silk',
      partnerCategoryCode: categoryCode,
      groupCode: 'printing.materials',
      displayOrder: 30,
    ),
    CapabilityDefinition(
      code: 'printing.syntheticBlended',
      label: 'Synthetic / Blended',
      partnerCategoryCode: categoryCode,
      groupCode: 'printing.materials',
      displayOrder: 40,
    ),
    CapabilityDefinition(
      code: 'printing.otherMaterials',
      label: 'Other Materials',
      partnerCategoryCode: categoryCode,
      groupCode: 'printing.materials',
      displayOrder: 50,
    ),
    CapabilityDefinition(
      code: 'printing.pickupDeliveryAvailable',
      label: 'Pickup & Delivery Available',
      partnerCategoryCode: categoryCode,
      groupCode: 'printing.fulfillment',
      displayOrder: 10,
    ),
  ];

  @override
  List<CapabilityGroupDefinition> groupsForPartnerCategory(String category) =>
      _groups
          .where((item) => item.active && item.partnerCategoryCode == category)
          .toList()
        ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

  @override
  List<CapabilityDefinition> capabilitiesForPartnerCategory(String category) =>
      _capabilities
          .where((item) => item.active && item.partnerCategoryCode == category)
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
    final normalized = capabilityCode?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    for (final item in _capabilities) {
      if (item.code == normalized) {
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
