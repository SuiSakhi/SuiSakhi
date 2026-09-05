// ============================================================================
// COMMON PARTNER FOUNDATION
// ============================================================================
//
// Partner Category:
//   Represents the Partner's primary business identity.
//
// Service Capabilities:
//   Represent the services that an approved Partner can perform.
//
// A Partner category must not permanently restrict the services offered.
// One Partner profile may provide multiple governed services.
//
// Examples:
//
//   Tailor
//   + Stitching
//   + Measurement
//   + Pickup
//   + Delivery
//
//   Measurement Partner
//   + Measurement
//   + Reference-garment pickup
//   + Pickup and drop
//
//   Laundry Partner
//   + Laundry
//   + Pressing
//   + Pickup
//   + Delivery
//
// IMPORTANT:
// - Keep category codes stable after production data is created.
// - Do not use display labels as Firestore identifiers.
// - Add new categories here instead of using hard-coded strings in screens.
// - Cross-category services belong in capability metadata, not in this file.
// ============================================================================

/// Centrally managed Partner category identifiers.
///
/// A category represents the Partner's primary business identity.
/// It does not define the complete list of services that the Partner may offer.
///
/// Shared and cross-category services are managed separately through governed
/// capability metadata.
abstract final class PartnerCategoryMetadata {
  // Prevent direct construction. This class is a constant registry only.
  PartnerCategoryMetadata._();

  // ==========================================================================
  // CORE PRODUCTION AND SERVICE PARTNERS
  // ==========================================================================

  /// Partner whose primary business is garment stitching and alteration.
  static const String tailor = 'tailor';

  /// Independent Partner whose primary business is measurement services.
  static const String measurementPartner = 'measurementPartner';

  /// Partner providing customer-location or other field services.
  static const String doorstepServices = 'doorstepServices';

  /// Partner whose primary business is pickup and delivery.
  static const String deliveryPartner = 'deliveryPartner';

  /// Partner whose primary business is garment laundry services.
  static const String laundry = 'laundry';

  /// Partner whose primary business is garment pressing services.
  static const String pressing = 'pressing';

  // ==========================================================================
  // FASHION, CATALOG, AND COMMERCE PARTNERS
  // ==========================================================================

  /// Partner whose primary business is fashion or garment design.
  static const String designer = 'designer';

  /// Partner whose primary business is boutique services or garment sales.
  static const String boutique = 'boutique';

  /// Partner whose primary business is garment or accessory rental.
  static const String rental = 'rental';

  // ==========================================================================
  // GOVERNED CATEGORY REGISTRY
  // ==========================================================================

  /// All currently governed Phase-1 Partner category codes.
  ///
  /// Use this collection for validation, filters, dropdowns, and Admin
  /// category-level counts. Do not duplicate this list in individual screens.
  static const Set<String> all = {
    tailor,
    measurementPartner,
    doorstepServices,
    deliveryPartner,
    laundry,
    pressing,
    designer,
    boutique,
    rental,
  };

  /// Returns whether [categoryCode] is a governed Partner category.
  static bool isSupported(String? categoryCode) {
    final normalizedCode = categoryCode?.trim();

    return normalizedCode != null &&
        normalizedCode.isNotEmpty &&
        all.contains(normalizedCode);
  }
}
