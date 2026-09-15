import '../../models/capability_definition.dart';
import '../../services/capability_metadata_provider.dart';
import 'partner_category_metadata.dart';

class DeliveryPartnerCapabilityMetadata implements CapabilityMetadataProvider {
  const DeliveryPartnerCapabilityMetadata();
  static const instance = DeliveryPartnerCapabilityMetadata();
  static const String categoryCode = PartnerCategoryMetadata.deliveryPartner;

  static const List<CapabilityGroupDefinition> _groups = [
    CapabilityGroupDefinition(
      code: 'deliveryPartner.services',
      label: 'Logistics Services',
      partnerCategoryCode: categoryCode,
      displayOrder: 10,
    ),
    CapabilityGroupDefinition(
      code: 'deliveryPartner.coverage',
      label: 'Coverage',
      partnerCategoryCode: categoryCode,
      displayOrder: 20,
    ),
  ];

  static const List<CapabilityDefinition> _capabilities = [
    CapabilityDefinition(
      code: 'deliveryPartner.customerPickup',
      label: 'Customer Pickup',
      partnerCategoryCode: categoryCode,
      groupCode: 'deliveryPartner.services',
      displayOrder: 10,
    ),
    CapabilityDefinition(
      code: 'deliveryPartner.customerDelivery',
      label: 'Customer Delivery',
      partnerCategoryCode: categoryCode,
      groupCode: 'deliveryPartner.services',
      displayOrder: 20,
    ),
    CapabilityDefinition(
      code: 'deliveryPartner.pickupDelivery',
      label: 'Pickup & Delivery',
      partnerCategoryCode: categoryCode,
      groupCode: 'deliveryPartner.services',
      displayOrder: 30,
    ),
    CapabilityDefinition(
      code: 'deliveryPartner.sameDayDelivery',
      label: 'Same-Day Delivery',
      partnerCategoryCode: categoryCode,
      groupCode: 'deliveryPartner.services',
      displayOrder: 40,
    ),
    CapabilityDefinition(
      code: 'deliveryPartner.expressDelivery',
      label: 'Express Delivery',
      partnerCategoryCode: categoryCode,
      groupCode: 'deliveryPartner.services',
      displayOrder: 50,
    ),
    CapabilityDefinition(
      code: 'deliveryPartner.interPartnerTransfer',
      label: 'Inter-Partner Transfer',
      partnerCategoryCode: categoryCode,
      groupCode: 'deliveryPartner.services',
      displayOrder: 60,
      requiresVerification: true,
    ),
    CapabilityDefinition(
      code: 'deliveryPartner.returnPickup',
      label: 'Return Pickup',
      partnerCategoryCode: categoryCode,
      groupCode: 'deliveryPartner.services',
      displayOrder: 70,
    ),
    CapabilityDefinition(
      code: 'deliveryPartner.localArea',
      label: 'Local Area',
      partnerCategoryCode: categoryCode,
      groupCode: 'deliveryPartner.coverage',
      displayOrder: 10,
    ),
    CapabilityDefinition(
      code: 'deliveryPartner.city',
      label: 'City',
      partnerCategoryCode: categoryCode,
      groupCode: 'deliveryPartner.coverage',
      displayOrder: 20,
    ),
    CapabilityDefinition(
      code: 'deliveryPartner.district',
      label: 'District',
      partnerCategoryCode: categoryCode,
      groupCode: 'deliveryPartner.coverage',
      displayOrder: 30,
    ),
    CapabilityDefinition(
      code: 'deliveryPartner.intercity',
      label: 'Intercity',
      partnerCategoryCode: categoryCode,
      groupCode: 'deliveryPartner.coverage',
      displayOrder: 40,
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
