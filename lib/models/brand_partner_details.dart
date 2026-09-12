/*
 * =============================================================================
 * SuiSakhi Brand Partner Details Model
 *
 * Purpose:
 * Stores Brand-specific onboarding information under:
 *
 * onboardingData.extensions.brand
 *
 * This model contains ONLY Brand-specific information.
 *
 * Common Partner information such as:
 * - Basic Details
 * - Business Address
 * - Operating Schedule
 * - Application lifecycle
 * - KYC / verification
 * - Admin approval
 * - Partner profile activation
 *
 * remains in the common Partner foundation.
 *
 * This model does not perform:
 * - KYC
 * - approval
 * - Partner activation
 * - catalogue publishing
 * - order allocation
 * =============================================================================
 */

import 'partner_capability_selection.dart';

// =============================================================================
// BRAND PARTNER DETAILS
// =============================================================================

class BrandPartnerDetails {
  const BrandPartnerDetails({
    this.capabilitySelection = const PartnerCapabilitySelection(),
    this.brandSpecialization,
    this.experienceYears,
    this.productCategories,
    this.targetMarket,
    this.catalogueReady = false,
    this.inventoryManaged = false,
    this.readyStock = false,
    this.pickupAndDeliveryAvailable = false,
    this.returnExchangeAvailable = false,
    this.serviceArea,
    this.teamSize,
    this.normalDailyCapacity,
    this.peakDailyCapacity,
    this.additionalNotes,
  });

  // ===========================================================================
  // BRAND CAPABILITIES
  // ===========================================================================

  final PartnerCapabilitySelection capabilitySelection;

  // ===========================================================================
  // BRAND INFORMATION
  // ===========================================================================

  final String? brandSpecialization;

  final int? experienceYears;

  final String? productCategories;

  final String? targetMarket;

  // ===========================================================================
  // CATALOGUE / INVENTORY
  // ===========================================================================

  final bool catalogueReady;

  final bool inventoryManaged;

  final bool readyStock;

  // ===========================================================================
  // FULFILLMENT / CUSTOMER SERVICE
  // ===========================================================================

  final bool pickupAndDeliveryAvailable;

  final bool returnExchangeAvailable;

  final String? serviceArea;

  // ===========================================================================
  // CAPACITY
  // ===========================================================================

  final int? teamSize;

  final int? normalDailyCapacity;

  final int? peakDailyCapacity;

  // ===========================================================================
  // ADDITIONAL INFORMATION
  // ===========================================================================

  final String? additionalNotes;

  // ===========================================================================
  // SERIALIZATION
  // ===========================================================================

  Map<String, dynamic> toMap() {
    return {
      'capabilities': capabilitySelection.toMap(),
      'brandSpecialization': _text(brandSpecialization),
      'experienceYears': _nonNegative(experienceYears),
      'productCategories': _text(productCategories),
      'targetMarket': _text(targetMarket),
      'catalogueReady': catalogueReady,
      'inventoryManaged': inventoryManaged,
      'readyStock': readyStock,
      'pickupAndDeliveryAvailable': pickupAndDeliveryAvailable,
      'returnExchangeAvailable': returnExchangeAvailable,
      'serviceArea': _text(serviceArea),
      'teamSize': _nonNegative(teamSize),
      'normalDailyCapacity': _nonNegative(normalDailyCapacity),
      'peakDailyCapacity': _nonNegative(peakDailyCapacity),
      'additionalNotes': _text(additionalNotes),
    };
  }

  // ===========================================================================
  // HYDRATION FROM COMMON PARTNER APPLICATION
  // ===========================================================================

  factory BrandPartnerDetails.fromOnboardingData(
    Map<String, dynamic> data,
  ) {
    final extensionsValue = data['extensions'];

    if (extensionsValue is! Map) {
      return const BrandPartnerDetails();
    }

    final extensions = Map<String, dynamic>.from(extensionsValue);

    final brandValue = extensions['brand'];

    if (brandValue is! Map) {
      return const BrandPartnerDetails();
    }

    return BrandPartnerDetails.fromMap(
      Map<String, dynamic>.from(brandValue),
    );
  }

  // ===========================================================================
  // HYDRATION FROM CATEGORY EXTENSION MAP
  // ===========================================================================

  factory BrandPartnerDetails.fromMap(
    Map<String, dynamic> data,
  ) {
    final capabilitiesValue = data['capabilities'];

    final capabilitySelection = capabilitiesValue is Map
        ? PartnerCapabilitySelection.fromMap(
            Map<String, dynamic>.from(capabilitiesValue),
          )
        : const PartnerCapabilitySelection();

    return BrandPartnerDetails(
      capabilitySelection: capabilitySelection,
      brandSpecialization: _text(
        data['brandSpecialization']?.toString(),
      ),
      experienceYears: _int(
        data['experienceYears'],
      ),
      productCategories: _text(
        data['productCategories']?.toString(),
      ),
      targetMarket: _text(
        data['targetMarket']?.toString(),
      ),
      catalogueReady:
          data['catalogueReady'] == true,
      inventoryManaged:
          data['inventoryManaged'] == true,
      readyStock:
          data['readyStock'] == true,
      pickupAndDeliveryAvailable:
          data['pickupAndDeliveryAvailable'] == true,
      returnExchangeAvailable:
          data['returnExchangeAvailable'] == true,
      serviceArea: _text(
        data['serviceArea']?.toString(),
      ),
      teamSize: _int(
        data['teamSize'],
      ),
      normalDailyCapacity: _int(
        data['normalDailyCapacity'],
      ),
      peakDailyCapacity: _int(
        data['peakDailyCapacity'],
      ),
      additionalNotes: _text(
        data['additionalNotes']?.toString(),
      ),
    );
  }

  // ===========================================================================
  // VALUE NORMALIZATION HELPERS
  // ===========================================================================

  static String? _text(String? value) {
    final normalized = value?.trim() ?? '';

    if (normalized.isEmpty) {
      return null;
    }

    return normalized;
  }

  static int? _int(Object? value) {
    final parsed = value is int
        ? value
        : int.tryParse(
            value?.toString() ?? '',
          );

    if (parsed == null || parsed < 0) {
      return null;
    }

    return parsed;
  }

  static int? _nonNegative(int? value) {
    if (value == null || value < 0) {
      return null;
    }

    return value;
  }
}
