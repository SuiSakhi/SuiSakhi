import '../../models/capability_definition.dart';
import '../../services/capability_metadata_provider.dart';

class FabricSupplierPartnerCapabilityMetadata
    implements CapabilityMetadataProvider {
  const FabricSupplierPartnerCapabilityMetadata();
  static const instance = FabricSupplierPartnerCapabilityMetadata();
  static const String categoryCode = 'fabricSupplier';

  static const List<CapabilityGroupDefinition> _groups = [
    CapabilityGroupDefinition(
      code: 'fabricSupplier.fabricCategories',
      label: 'Fabric Categories',
      partnerCategoryCode: categoryCode,
      displayOrder: 10,
    ),
    CapabilityGroupDefinition(
      code: 'fabricSupplier.supplyServices',
      label: 'Supply Services',
      partnerCategoryCode: categoryCode,
      displayOrder: 20,
    ),
    CapabilityGroupDefinition(
      code: 'fabricSupplier.fulfillment',
      label: 'Collection & Delivery',
      partnerCategoryCode: categoryCode,
      displayOrder: 30,
    ),
  ];

  static const List<CapabilityDefinition> _capabilities = [
    CapabilityDefinition(
      code: 'fabricSupplier.cotton',
      label: 'Cotton',
      partnerCategoryCode: categoryCode,
      groupCode: 'fabricSupplier.fabricCategories',
      displayOrder: 10,
    ),
    CapabilityDefinition(
      code: 'fabricSupplier.silk',
      label: 'Silk',
      partnerCategoryCode: categoryCode,
      groupCode: 'fabricSupplier.fabricCategories',
      displayOrder: 20,
    ),
    CapabilityDefinition(
      code: 'fabricSupplier.linen',
      label: 'Linen',
      partnerCategoryCode: categoryCode,
      groupCode: 'fabricSupplier.fabricCategories',
      displayOrder: 30,
    ),
    CapabilityDefinition(
      code: 'fabricSupplier.denim',
      label: 'Denim',
      partnerCategoryCode: categoryCode,
      groupCode: 'fabricSupplier.fabricCategories',
      displayOrder: 40,
    ),
    CapabilityDefinition(
      code: 'fabricSupplier.syntheticBlended',
      label: 'Synthetic / Blended',
      partnerCategoryCode: categoryCode,
      groupCode: 'fabricSupplier.fabricCategories',
      displayOrder: 50,
    ),
    CapabilityDefinition(
      code: 'fabricSupplier.designerFabrics',
      label: 'Designer Fabrics',
      partnerCategoryCode: categoryCode,
      groupCode: 'fabricSupplier.fabricCategories',
      displayOrder: 60,
    ),
    CapabilityDefinition(
      code: 'fabricSupplier.bridalFabrics',
      label: 'Bridal Fabrics',
      partnerCategoryCode: categoryCode,
      groupCode: 'fabricSupplier.fabricCategories',
      displayOrder: 70,
      requiresVerification: true,
    ),
    CapabilityDefinition(
      code: 'fabricSupplier.uniformFabrics',
      label: 'Uniform Fabrics',
      partnerCategoryCode: categoryCode,
      groupCode: 'fabricSupplier.fabricCategories',
      displayOrder: 80,
    ),
    CapabilityDefinition(
      code: 'fabricSupplier.childrenFabrics',
      label: 'Children Fabrics',
      partnerCategoryCode: categoryCode,
      groupCode: 'fabricSupplier.fabricCategories',
      displayOrder: 90,
    ),
    CapabilityDefinition(
      code: 'fabricSupplier.retailSales',
      label: 'Retail Sales',
      partnerCategoryCode: categoryCode,
      groupCode: 'fabricSupplier.supplyServices',
      displayOrder: 10,
    ),
    CapabilityDefinition(
      code: 'fabricSupplier.wholesaleSupply',
      label: 'Wholesale Supply',
      partnerCategoryCode: categoryCode,
      groupCode: 'fabricSupplier.supplyServices',
      displayOrder: 20,
    ),
    CapabilityDefinition(
      code: 'fabricSupplier.customFabricSourcing',
      label: 'Custom Fabric Sourcing',
      partnerCategoryCode: categoryCode,
      groupCode: 'fabricSupplier.supplyServices',
      displayOrder: 30,
    ),
    CapabilityDefinition(
      code: 'fabricSupplier.fabricRecommendations',
      label: 'Fabric Recommendations',
      partnerCategoryCode: categoryCode,
      groupCode: 'fabricSupplier.supplyServices',
      displayOrder: 40,
    ),
    CapabilityDefinition(
      code: 'fabricSupplier.sampleSwatchSupply',
      label: 'Sample / Swatch Supply',
      partnerCategoryCode: categoryCode,
      groupCode: 'fabricSupplier.supplyServices',
      displayOrder: 50,
    ),
    CapabilityDefinition(
      code: 'fabricSupplier.pickupDeliveryAvailable',
      label: 'Pickup & Delivery Available',
      partnerCategoryCode: categoryCode,
      groupCode: 'fabricSupplier.fulfillment',
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
