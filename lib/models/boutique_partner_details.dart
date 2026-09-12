/*
 * =============================================================================
 * SuiSakhi Boutique Partner Details Model
 *
 * Purpose:
 * Stores Boutique-specific onboarding information under:
 *
 * onboardingData.extensions.boutique
 *
 * This model contains ONLY Boutique-specific information.
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
// BOUTIQUE PARTNER DETAILS
// =============================================================================

class BoutiquePartnerDetails {
  const BoutiquePartnerDetails({
    this.capabilitySelection = const PartnerCapabilitySelection(),
    this.specialization,
    this.experienceYears,
    this.serviceArea,
    this.teamSize,
    this.normalDailyCapacity,
    this.peakDailyCapacity,
    this.homeVisitAvailable = false,
    this.pickupAndDeliveryAvailable = false,
    this.readyMadeInventory = false,
    this.returnExchangeAvailable = false,
    this.portfolioSummary,
    this.additionalNotes,
  });

  // ===========================================================================
  // BOUTIQUE CAPABILITIES
  // ===========================================================================

  final PartnerCapabilitySelection capabilitySelection;

  // ===========================================================================
  // PROFESSIONAL / BUSINESS INFORMATION
  // ===========================================================================

  final String? specialization;

  final int? experienceYears;

  final String? serviceArea;

  // ===========================================================================
  // CAPACITY
  // ===========================================================================

  final int? teamSize;

  final int? normalDailyCapacity;

  final int? peakDailyCapacity;

  // ===========================================================================
  // CUSTOMER SERVICE / FULFILLMENT
  // ===========================================================================

  final bool homeVisitAvailable;

  final bool pickupAndDeliveryAvailable;

  final bool readyMadeInventory;

  final bool returnExchangeAvailable;

  // ===========================================================================
  // ADDITIONAL INFORMATION
  // ===========================================================================

  final String? portfolioSummary;

  final String? additionalNotes;

  // ===========================================================================
  // SERIALIZATION
  // ===========================================================================

  Map<String, dynamic> toMap() {
    return {
      'capabilities': capabilitySelection.toMap(),
      'specialization': _text(specialization),
      'experienceYears': _nonNegative(experienceYears),
      'serviceArea': _text(serviceArea),
      'teamSize': _nonNegative(teamSize),
      'normalDailyCapacity': _nonNegative(normalDailyCapacity),
      'peakDailyCapacity': _nonNegative(peakDailyCapacity),
      'homeVisitAvailable': homeVisitAvailable,
      'pickupAndDeliveryAvailable': pickupAndDeliveryAvailable,
      'readyMadeInventory': readyMadeInventory,
      'returnExchangeAvailable': returnExchangeAvailable,
      'portfolioSummary': _text(portfolioSummary),
      'additionalNotes': _text(additionalNotes),
    };
  }

  // ===========================================================================
  // HYDRATION FROM COMMON PARTNER APPLICATION
  // ===========================================================================

  factory BoutiquePartnerDetails.fromOnboardingData(
    Map<String, dynamic> data,
  ) {
    final extensionsValue = data['extensions'];

    if (extensionsValue is! Map) {
      return const BoutiquePartnerDetails();
    }

    final extensions = Map<String, dynamic>.from(extensionsValue);

    final boutiqueValue = extensions['boutique'];

    if (boutiqueValue is! Map) {
      return const BoutiquePartnerDetails();
    }

    return BoutiquePartnerDetails.fromMap(
      Map<String, dynamic>.from(boutiqueValue),
    );
  }

  // ===========================================================================
  // HYDRATION FROM CATEGORY EXTENSION MAP
  // ===========================================================================

  factory BoutiquePartnerDetails.fromMap(
    Map<String, dynamic> data,
  ) {
    final capabilitiesValue = data['capabilities'];

    final capabilitySelection = capabilitiesValue is Map
        ? PartnerCapabilitySelection.fromMap(
            Map<String, dynamic>.from(capabilitiesValue),
          )
        : const PartnerCapabilitySelection();

    return BoutiquePartnerDetails(
      capabilitySelection: capabilitySelection,
      specialization: _text(
        data['specialization']?.toString(),
      ),
      experienceYears: _int(
        data['experienceYears'],
      ),
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
      homeVisitAvailable:
          data['homeVisitAvailable'] == true,
      pickupAndDeliveryAvailable:
          data['pickupAndDeliveryAvailable'] == true,
      readyMadeInventory:
          data['readyMadeInventory'] == true,
      returnExchangeAvailable:
          data['returnExchangeAvailable'] == true,
      portfolioSummary: _text(
        data['portfolioSummary']?.toString(),
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
