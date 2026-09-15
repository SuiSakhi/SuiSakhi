/*
 * SuiSakhi Brand Partner Capability Metadata
 *
 * Purpose:
 * Defines governed Brand capabilities for onboarding and future matching,
 * allocation, analytics, catalogue, and AI services.
 *
 * This is metadata only; persistence and Partner lifecycle remain in the
 * common Partner foundation.
 */

import '../../models/capability_definition.dart';
import '../../services/capability_metadata_provider.dart';
import 'partner_category_metadata.dart';

class BrandPartnerCapabilityMetadata implements CapabilityMetadataProvider {
  const BrandPartnerCapabilityMetadata();

  static const instance = BrandPartnerCapabilityMetadata();
  static const String categoryCode = PartnerCategoryMetadata.brand;

  static const List<CapabilityGroupDefinition> _groups = [
    CapabilityGroupDefinition(
      code: 'brand.catalogue',
      label: 'Catalogue & Collections',
      partnerCategoryCode: categoryCode,
      displayOrder: 10,
    ),
    CapabilityGroupDefinition(
      code: 'brand.products',
      label: 'Products & Inventory',
      partnerCategoryCode: categoryCode,
      displayOrder: 20,
    ),
    CapabilityGroupDefinition(
      code: 'brand.fulfillment',
      label: 'Fulfillment & Logistics',
      partnerCategoryCode: categoryCode,
      displayOrder: 30,
    ),
    CapabilityGroupDefinition(
      code: 'brand.customerPolicy',
      label: 'Customer Policies',
      partnerCategoryCode: categoryCode,
      displayOrder: 40,
    ),
  ];

  static const List<CapabilityDefinition> _capabilities = [
    CapabilityDefinition(
      code: 'brand.catalogueManagement',
      label: 'Catalogue Management',
      partnerCategoryCode: categoryCode,
      groupCode: 'brand.catalogue',
      displayOrder: 10,
    ),
    CapabilityDefinition(
      code: 'brand.collectionManagement',
      label: 'Collection Management',
      partnerCategoryCode: categoryCode,
      groupCode: 'brand.catalogue',
      displayOrder: 20,
    ),
    CapabilityDefinition(
      code: 'brand.productVariants',
      label: 'Size / Colour / Variant Management',
      partnerCategoryCode: categoryCode,
      groupCode: 'brand.products',
      displayOrder: 10,
    ),
    CapabilityDefinition(
      code: 'brand.inventoryManagement',
      label: 'Inventory Management',
      partnerCategoryCode: categoryCode,
      groupCode: 'brand.products',
      displayOrder: 20,
    ),
    CapabilityDefinition(
      code: 'brand.readyStock',
      label: 'Ready Stock',
      partnerCategoryCode: categoryCode,
      groupCode: 'brand.products',
      displayOrder: 30,
    ),
    CapabilityDefinition(
      code: 'brand.partnerFulfillment',
      label: 'Partner Fulfillment / Dispatch',
      partnerCategoryCode: categoryCode,
      groupCode: 'brand.fulfillment',
      displayOrder: 10,
    ),
    CapabilityDefinition(
      code: 'brand.pickupDelivery',
      label: 'Pickup & Delivery',
      partnerCategoryCode: categoryCode,
      groupCode: 'brand.fulfillment',
      displayOrder: 20,
    ),
    CapabilityDefinition(
      code: 'brand.returnExchange',
      label: 'Return / Exchange Handling',
      partnerCategoryCode: categoryCode,
      groupCode: 'brand.customerPolicy',
      displayOrder: 10,
    ),
    CapabilityDefinition(
      code: 'brand.customerSupport',
      label: 'Customer Support',
      partnerCategoryCode: categoryCode,
      groupCode: 'brand.customerPolicy',
      displayOrder: 20,
    ),
  ];

  @override
  List<CapabilityGroupDefinition> groupsForPartnerCategory(String code) =>
      _groups
          .where((group) => group.active && group.partnerCategoryCode == code)
          .toList()
        ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

  @override
  List<CapabilityDefinition> capabilitiesForPartnerCategory(String code) =>
      _capabilities
          .where(
            (capability) =>
                capability.active && capability.partnerCategoryCode == code,
          )
          .toList()
        ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

  @override
  List<CapabilityDefinition> capabilitiesForGroup({
    required String partnerCategoryCode,
    required String groupCode,
  }) =>
      _capabilities
          .where(
            (capability) =>
                capability.active &&
                capability.partnerCategoryCode == partnerCategoryCode &&
                capability.groupCode == groupCode,
          )
          .toList()
        ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

  @override
  CapabilityDefinition? capabilityForCode(String? capabilityCode) {
    final code = capabilityCode?.trim();
    if (code == null || code.isEmpty) return null;
    for (final capability in _capabilities) {
      if (capability.code == code) return capability;
    }
    return null;
  }

  @override
  CapabilityGroupDefinition? groupForCode({
    required String partnerCategoryCode,
    required String groupCode,
  }) {
    for (final group in _groups) {
      if (group.partnerCategoryCode == partnerCategoryCode &&
          group.code == groupCode) {
        return group;
      }
    }
    return null;
  }
}
