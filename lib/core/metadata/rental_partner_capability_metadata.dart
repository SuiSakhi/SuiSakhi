import '../../models/capability_definition.dart';
import '../../services/capability_metadata_provider.dart';
import 'partner_category_metadata.dart';

class RentalPartnerCapabilityMetadata implements CapabilityMetadataProvider {
  const RentalPartnerCapabilityMetadata();
  static const instance = RentalPartnerCapabilityMetadata();
  static const String categoryCode = PartnerCategoryMetadata.rental;

  static const List<CapabilityGroupDefinition> _groups = [
    CapabilityGroupDefinition(
      code: 'rental.kidsEvents',
      label: 'Kids Event Rentals',
      partnerCategoryCode: categoryCode,
      displayOrder: 10,
    ),
    CapabilityGroupDefinition(
      code: 'rental.ladiesEvents',
      label: 'Ladies Event Rentals',
      partnerCategoryCode: categoryCode,
      displayOrder: 20,
    ),
    CapabilityGroupDefinition(
      code: 'rental.weddingOccasion',
      label: 'Wedding & Occasion Wear',
      partnerCategoryCode: categoryCode,
      displayOrder: 30,
    ),
    CapabilityGroupDefinition(
      code: 'rental.jewelleryAccessories',
      label: 'Jewellery & Accessories',
      partnerCategoryCode: categoryCode,
      displayOrder: 40,
    ),
    CapabilityGroupDefinition(
      code: 'rental.props',
      label: 'Props & Event Accessories',
      partnerCategoryCode: categoryCode,
      displayOrder: 50,
    ),
    CapabilityGroupDefinition(
      code: 'rental.fulfillment',
      label: 'Collection & Delivery',
      partnerCategoryCode: categoryCode,
      displayOrder: 60,
    ),
  ];

  static const List<CapabilityDefinition> _capabilities = [
    CapabilityDefinition(
      code: 'rental.fancyDress',
      label: 'Fancy Dress',
      partnerCategoryCode: categoryCode,
      groupCode: 'rental.kidsEvents',
      displayOrder: 10,
    ),
    CapabilityDefinition(
      code: 'rental.danceCostumes',
      label: 'Dance Costumes',
      partnerCategoryCode: categoryCode,
      groupCode: 'rental.kidsEvents',
      displayOrder: 20,
    ),
    CapabilityDefinition(
      code: 'rental.dramaCostumes',
      label: 'Drama Costumes',
      partnerCategoryCode: categoryCode,
      groupCode: 'rental.kidsEvents',
      displayOrder: 30,
    ),
    CapabilityDefinition(
      code: 'rental.schoolEventCostumes',
      label: 'School Event Costumes',
      partnerCategoryCode: categoryCode,
      groupCode: 'rental.kidsEvents',
      displayOrder: 40,
    ),
    CapabilityDefinition(
      code: 'rental.characterCostumes',
      label: 'Character Costumes',
      partnerCategoryCode: categoryCode,
      groupCode: 'rental.kidsEvents',
      displayOrder: 50,
    ),
    CapabilityDefinition(
      code: 'rental.propsAccessories',
      label: 'Props & Accessories',
      partnerCategoryCode: categoryCode,
      groupCode: 'rental.kidsEvents',
      displayOrder: 60,
    ),
    CapabilityDefinition(
      code: 'rental.fancyDressThemeWear',
      label: 'Fancy Dress / Theme Wear',
      partnerCategoryCode: categoryCode,
      groupCode: 'rental.ladiesEvents',
      displayOrder: 10,
    ),
    CapabilityDefinition(
      code: 'rental.danceCostumes',
      label: 'Dance Costumes',
      partnerCategoryCode: categoryCode,
      groupCode: 'rental.ladiesEvents',
      displayOrder: 20,
    ),
    CapabilityDefinition(
      code: 'rental.dramaCostumes',
      label: 'Drama Costumes',
      partnerCategoryCode: categoryCode,
      groupCode: 'rental.ladiesEvents',
      displayOrder: 30,
    ),
    CapabilityDefinition(
      code: 'rental.partyWear',
      label: 'Party Wear',
      partnerCategoryCode: categoryCode,
      groupCode: 'rental.ladiesEvents',
      displayOrder: 40,
    ),
    CapabilityDefinition(
      code: 'rental.traditionalWear',
      label: 'Traditional Wear',
      partnerCategoryCode: categoryCode,
      groupCode: 'rental.ladiesEvents',
      displayOrder: 50,
    ),
    CapabilityDefinition(
      code: 'rental.designerWear',
      label: 'Designer Wear',
      partnerCategoryCode: categoryCode,
      groupCode: 'rental.ladiesEvents',
      displayOrder: 60,
    ),
    CapabilityDefinition(
      code: 'rental.bridalWear',
      label: 'Bridal Wear',
      partnerCategoryCode: categoryCode,
      groupCode: 'rental.weddingOccasion',
      displayOrder: 10,
      requiresVerification: true,
    ),
    CapabilityDefinition(
      code: 'rental.weddingGuestWear',
      label: 'Wedding Guest Wear',
      partnerCategoryCode: categoryCode,
      groupCode: 'rental.weddingOccasion',
      displayOrder: 20,
    ),
    CapabilityDefinition(
      code: 'rental.engagementWear',
      label: 'Engagement Wear',
      partnerCategoryCode: categoryCode,
      groupCode: 'rental.weddingOccasion',
      displayOrder: 30,
    ),
    CapabilityDefinition(
      code: 'rental.receptionWear',
      label: 'Reception Wear',
      partnerCategoryCode: categoryCode,
      groupCode: 'rental.weddingOccasion',
      displayOrder: 40,
    ),
    CapabilityDefinition(
      code: 'rental.festivalWear',
      label: 'Festival Wear',
      partnerCategoryCode: categoryCode,
      groupCode: 'rental.weddingOccasion',
      displayOrder: 50,
    ),
    CapabilityDefinition(
      code: 'rental.otherOccasionWear',
      label: 'Other Occasion Wear',
      partnerCategoryCode: categoryCode,
      groupCode: 'rental.weddingOccasion',
      displayOrder: 60,
    ),
    CapabilityDefinition(
      code: 'rental.bridalJewellery',
      label: 'Bridal Jewellery',
      partnerCategoryCode: categoryCode,
      groupCode: 'rental.jewelleryAccessories',
      displayOrder: 10,
      requiresVerification: true,
    ),
    CapabilityDefinition(
      code: 'rental.artificialJewellery',
      label: 'Artificial Jewellery',
      partnerCategoryCode: categoryCode,
      groupCode: 'rental.jewelleryAccessories',
      displayOrder: 20,
    ),
    CapabilityDefinition(
      code: 'rental.occasionJewellery',
      label: 'Occasion Jewellery',
      partnerCategoryCode: categoryCode,
      groupCode: 'rental.jewelleryAccessories',
      displayOrder: 30,
    ),
    CapabilityDefinition(
      code: 'rental.fashionJewellery',
      label: 'Fashion Jewellery',
      partnerCategoryCode: categoryCode,
      groupCode: 'rental.jewelleryAccessories',
      displayOrder: 40,
    ),
    CapabilityDefinition(
      code: 'rental.hairAccessories',
      label: 'Hair Accessories',
      partnerCategoryCode: categoryCode,
      groupCode: 'rental.jewelleryAccessories',
      displayOrder: 50,
    ),
    CapabilityDefinition(
      code: 'rental.clutchesBags',
      label: 'Clutches / Bags',
      partnerCategoryCode: categoryCode,
      groupCode: 'rental.jewelleryAccessories',
      displayOrder: 60,
    ),
    CapabilityDefinition(
      code: 'rental.stageProps',
      label: 'Stage Props',
      partnerCategoryCode: categoryCode,
      groupCode: 'rental.props',
      displayOrder: 10,
    ),
    CapabilityDefinition(
      code: 'rental.themeProps',
      label: 'Theme Props',
      partnerCategoryCode: categoryCode,
      groupCode: 'rental.props',
      displayOrder: 20,
    ),
    CapabilityDefinition(
      code: 'rental.danceProps',
      label: 'Dance Props',
      partnerCategoryCode: categoryCode,
      groupCode: 'rental.props',
      displayOrder: 30,
    ),
    CapabilityDefinition(
      code: 'rental.dramaProps',
      label: 'Drama Props',
      partnerCategoryCode: categoryCode,
      groupCode: 'rental.props',
      displayOrder: 40,
    ),
    CapabilityDefinition(
      code: 'rental.eventAccessories',
      label: 'Event Accessories',
      partnerCategoryCode: categoryCode,
      groupCode: 'rental.props',
      displayOrder: 50,
    ),
    CapabilityDefinition(
      code: 'rental.otherRentalCategory',
      label: 'Other Rental Category',
      partnerCategoryCode: categoryCode,
      groupCode: 'rental.props',
      displayOrder: 60,
    ),
    CapabilityDefinition(
      code: 'rental.pickupDeliveryAvailable',
      label: 'Pickup & Delivery Available',
      partnerCategoryCode: categoryCode,
      groupCode: 'rental.fulfillment',
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
