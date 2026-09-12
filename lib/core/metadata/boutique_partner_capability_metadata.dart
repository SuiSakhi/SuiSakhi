/*
 * SuiSakhi Boutique Partner Capability Metadata
 *
 * Purpose:
 * Defines governed Boutique capabilities used during Partner onboarding and
 * later by matching, allocation, analytics, and AI services.
 *
 * This file contains metadata only. It does not implement persistence,
 * approval, activation, or the Boutique operational UI.
 */

import '../../models/capability_definition.dart';
import '../../services/capability_metadata_provider.dart';
import 'partner_category_metadata.dart';

class BoutiquePartnerCapabilityMetadata implements CapabilityMetadataProvider {
  const BoutiquePartnerCapabilityMetadata();

  static const instance = BoutiquePartnerCapabilityMetadata();
  static const String categoryCode = PartnerCategoryMetadata.boutique;

  static const List<CapabilityGroupDefinition> _groups = [
    CapabilityGroupDefinition(
      code: 'boutique.retail',
      label: 'Boutique Retail',
      partnerCategoryCode: categoryCode,
      displayOrder: 10,
    ),
    CapabilityGroupDefinition(
      code: 'boutique.fashionServices',
      label: 'Fashion Services',
      partnerCategoryCode: categoryCode,
      displayOrder: 20,
    ),
    CapabilityGroupDefinition(
      code: 'boutique.specialization',
      label: 'Specialization',
      partnerCategoryCode: categoryCode,
      displayOrder: 30,
    ),
    CapabilityGroupDefinition(
      code: 'boutique.fulfillment',
      label: 'Fulfillment & Customer Service',
      partnerCategoryCode: categoryCode,
      displayOrder: 40,
    ),
  ];

  static const List<CapabilityDefinition> _capabilities = [
    CapabilityDefinition(
      code: 'boutique.readyMadeSales',
      label: 'Ready-Made Sales',
      partnerCategoryCode: categoryCode,
      groupCode: 'boutique.retail',
      displayOrder: 10,
    ),
    CapabilityDefinition(
      code: 'boutique.inventoryFulfillment',
      label: 'Inventory-Based Fulfillment',
      partnerCategoryCode: categoryCode,
      groupCode: 'boutique.retail',
      displayOrder: 20,
    ),
    CapabilityDefinition(
      code: 'boutique.customStitching',
      label: 'Custom Stitching',
      partnerCategoryCode: categoryCode,
      groupCode: 'boutique.fashionServices',
      displayOrder: 10,
      requiresVerification: true,
    ),
    CapabilityDefinition(
      code: 'boutique.tailoringServices',
      label: 'Tailoring Services',
      partnerCategoryCode: categoryCode,
      groupCode: 'boutique.fashionServices',
      displayOrder: 20,
      requiresVerification: true,
    ),
    CapabilityDefinition(
      code: 'boutique.designerServices',
      label: 'Designer Services',
      partnerCategoryCode: categoryCode,
      groupCode: 'boutique.fashionServices',
      displayOrder: 30,
    ),
    CapabilityDefinition(
      code: 'boutique.trialFacility',
      label: 'Trial Facility',
      partnerCategoryCode: categoryCode,
      groupCode: 'boutique.fashionServices',
      displayOrder: 40,
    ),
    CapabilityDefinition(
      code: 'boutique.homeConsultation',
      label: 'Home Consultation',
      partnerCategoryCode: categoryCode,
      groupCode: 'boutique.fashionServices',
      displayOrder: 50,
    ),
    CapabilityDefinition(
      code: 'boutique.partyWear',
      label: 'Party Wear Specialist',
      partnerCategoryCode: categoryCode,
      groupCode: 'boutique.specialization',
      displayOrder: 10,
    ),
    CapabilityDefinition(
      code: 'boutique.bridal',
      label: 'Bridal Specialist',
      partnerCategoryCode: categoryCode,
      groupCode: 'boutique.specialization',
      displayOrder: 20,
    ),
    CapabilityDefinition(
      code: 'boutique.premiumFashion',
      label: 'Premium Fashion',
      partnerCategoryCode: categoryCode,
      groupCode: 'boutique.specialization',
      displayOrder: 30,
    ),
    CapabilityDefinition(
      code: 'boutique.inStorePickup',
      label: 'In-Store Pickup',
      partnerCategoryCode: categoryCode,
      groupCode: 'boutique.fulfillment',
      displayOrder: 10,
    ),
    CapabilityDefinition(
      code: 'boutique.pickupDelivery',
      label: 'Pickup & Delivery',
      partnerCategoryCode: categoryCode,
      groupCode: 'boutique.fulfillment',
      displayOrder: 20,
    ),
  ];

  @override
  List<CapabilityGroupDefinition> groupsForPartnerCategory(String code) =>
      _groups.where((group) => group.active && group.partnerCategoryCode == code).toList()
        ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

  @override
  List<CapabilityDefinition> capabilitiesForPartnerCategory(String code) =>
      _capabilities.where((capability) => capability.active && capability.partnerCategoryCode == code).toList()
        ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

  @override
  List<CapabilityDefinition> capabilitiesForGroup({
    required String partnerCategoryCode,
    required String groupCode,
  }) => _capabilities
      .where((capability) => capability.active && capability.partnerCategoryCode == partnerCategoryCode && capability.groupCode == groupCode)
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
      if (group.partnerCategoryCode == partnerCategoryCode && group.code == groupCode) return group;
    }
    return null;
  }
}
