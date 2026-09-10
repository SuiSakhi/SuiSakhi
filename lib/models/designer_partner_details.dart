/*
 * SuiSakhi Designer Partner Details Model
 *
 * Purpose:
 * Stores Designer Partner-specific onboarding and operational
 * information under:
 *
 * onboardingData.extensions.designer
 *
 * This model intentionally contains only Designer-specific data.
 * Common Partner application lifecycle, KYC, approval, ownership,
 * and profile activation remain part of the common Partner foundation.
 */

// ============================================================================
// DESIGNER PARTNER EXTENSION: OPERATIONAL DETAILS
// ============================================================================
//
// STORAGE LOCATION:
//
// partner_applications/{applicationId}
//   onboardingData.extensions.designer
//
// This model does not contain:
//
// - Account ownership
// - Application lifecycle status
// - KYC status
// - Admin review information
// - Partner-profile activation information
//
// Those remain part of the common Partner Application foundation.
//
// ============================================================================

import 'partner_capability_selection.dart';

class DesignerPartnerDetails {
  const DesignerPartnerDetails({
    this.professionalType,
    this.experienceYears,
    this.specialization,
    this.capabilitySelection = const PartnerCapabilitySelection(),
    this.portfolioSummary,
    this.acceptsCustomDesign = false,
    this.acceptsBulkOrders = false,
    this.acceptsWeddingOrders = false,
    this.consultationAvailable = false,
    this.originalWorkDeclaration = false,
    this.additionalNotes,
  });

  // ==========================================================================
  // DESIGNER PROFESSIONAL DETAILS
  // ==========================================================================

  /// Type of Designer's professional practice.
  ///
  /// Examples may include:
  /// - fashionDesigner
  /// - freelanceDesigner
  /// - boutiqueDesigner
  /// - bridalDesigner
  ///
  /// Stored as a governed code rather than a display label.
  final String? professionalType;

  /// Number of years of professional design experience.
  final int? experienceYears;

  /// Short description of the Designer's primary specialization.
  final String? specialization;

  // ==========================================================================
  // DESIGNER CAPABILITIES
  // ==========================================================================

  /// Metadata-driven Designer capability selection.
  ///
  /// Capability codes are defined by:
  /// designer_partner_capability_metadata.dart
  final PartnerCapabilitySelection capabilitySelection;

  // ==========================================================================
  // PORTFOLIO INFORMATION
  // ==========================================================================

  /// Short description of the Designer's portfolio and design experience.
  ///
  /// Actual portfolio assets can be added later through a dedicated
  /// portfolio/design publishing flow.
  final String? portfolioSummary;

  // ==========================================================================
  // SERVICE PREFERENCES
  // ==========================================================================

  /// Whether the Designer accepts custom design requirements.
  final bool acceptsCustomDesign;

  /// Whether the Designer accepts bulk design requirements.
  final bool acceptsBulkOrders;

  /// Whether the Designer accepts wedding-related design requirements.
  final bool acceptsWeddingOrders;

  /// Whether the Designer provides consultation.
  final bool consultationAvailable;

  // ==========================================================================
  // DESIGN OWNERSHIP / ORIGINAL WORK DECLARATION
  // ==========================================================================

  /// Indicates that the Designer has acknowledged the original-work /
  /// rights declaration applicable to submitted designs.
  ///
  /// This is only a declaration flag.
  /// Detailed licensing and design-rights management are intentionally
  /// outside this Phase-1 model.
  final bool originalWorkDeclaration;

  // ==========================================================================
  // ADDITIONAL INFORMATION
  // ==========================================================================

  /// Optional additional information provided by the Designer.
  final String? additionalNotes;

  // ==========================================================================
  // NORMALIZATION / VALIDATION HELPERS
  // ==========================================================================

  bool get hasOperationalInformation {
    return _normalizedOptionalText(professionalType) != null ||
        experienceYears != null ||
        _normalizedOptionalText(specialization) != null ||
        capabilitySelection.normalizedCapabilityCodes.isNotEmpty ||
        capabilitySelection.normalizedAdditionalDescriptions.isNotEmpty ||
        _normalizedOptionalText(portfolioSummary) != null ||
        acceptsCustomDesign ||
        acceptsBulkOrders ||
        acceptsWeddingOrders ||
        consultationAvailable ||
        originalWorkDeclaration ||
        _normalizedOptionalText(additionalNotes) != null;
  }

  // ==========================================================================
  // SERIALIZATION
  // ==========================================================================

  Map<String, dynamic> toMap() {
    return {
      'professionalType': _normalizedOptionalText(professionalType),
      'experienceYears': _nonNegativeIntOrNull(experienceYears),
      'specialization': _normalizedOptionalText(specialization),

      'capabilities': capabilitySelection.toMap(),

      'portfolioSummary': _normalizedOptionalText(portfolioSummary),

      'servicePreferences': {
        'acceptsCustomDesign': acceptsCustomDesign,
        'acceptsBulkOrders': acceptsBulkOrders,
        'acceptsWeddingOrders': acceptsWeddingOrders,
        'consultationAvailable': consultationAvailable,
      },

      'originalWorkDeclaration': originalWorkDeclaration,

      'additionalNotes': _normalizedOptionalText(additionalNotes),
    };
  }

  // ==========================================================================
  // DESERIALIZATION FROM ONBOARDING DATA
  // ==========================================================================

  factory DesignerPartnerDetails.fromOnboardingData(
    Map<String, dynamic> onboardingData,
  ) {
    final extensionsValue = onboardingData['extensions'];

    if (extensionsValue is! Map) {
      return const DesignerPartnerDetails();
    }

    final extensions = Map<String, dynamic>.from(extensionsValue);

    final designerValue = extensions['designer'];

    if (designerValue is! Map) {
      return const DesignerPartnerDetails();
    }

    return DesignerPartnerDetails.fromMap(
      Map<String, dynamic>.from(designerValue),
    );
  }

  // ==========================================================================
  // DESERIALIZATION FROM DESIGNER EXTENSION MAP
  // ==========================================================================

  factory DesignerPartnerDetails.fromMap(Map<String, dynamic> data) {
    final capabilities = _mapFromValue(data['capabilities']);

    final servicePreferences = _mapFromValue(data['servicePreferences']);

    return DesignerPartnerDetails(
      professionalType: _normalizedOptionalText(
        data['professionalType']?.toString(),
      ),

      experienceYears: _nonNegativeIntFromValue(data['experienceYears']),

      specialization: _normalizedOptionalText(
        data['specialization']?.toString(),
      ),

      capabilitySelection: capabilities.isEmpty
          ? const PartnerCapabilitySelection()
          : PartnerCapabilitySelection.fromMap(capabilities),

      portfolioSummary: _normalizedOptionalText(
        data['portfolioSummary']?.toString(),
      ),

      acceptsCustomDesign: servicePreferences['acceptsCustomDesign'] == true,

      acceptsBulkOrders: servicePreferences['acceptsBulkOrders'] == true,

      acceptsWeddingOrders: servicePreferences['acceptsWeddingOrders'] == true,

      consultationAvailable:
          servicePreferences['consultationAvailable'] == true,

      originalWorkDeclaration: data['originalWorkDeclaration'] == true,

      additionalNotes: _normalizedOptionalText(
        data['additionalNotes']?.toString(),
      ),
    );
  }

  // ==========================================================================
  // PRIVATE CONVERSION HELPERS
  // ==========================================================================

  static Map<String, dynamic> _mapFromValue(Object? value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return <String, dynamic>{};
  }

  static int? _nonNegativeIntFromValue(Object? value) {
    final parsedValue = value is int
        ? value
        : int.tryParse(value?.toString() ?? '');

    if (parsedValue == null || parsedValue < 0) {
      return null;
    }

    return parsedValue;
  }

  static int? _nonNegativeIntOrNull(int? value) {
    if (value == null || value < 0) {
      return null;
    }

    return value;
  }

  static String? _normalizedOptionalText(String? value) {
    final normalizedValue = value?.trim() ?? '';

    return normalizedValue.isEmpty ? null : normalizedValue;
  }
}
