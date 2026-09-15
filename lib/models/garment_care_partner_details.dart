import 'partner_capability_selection.dart';

/// Garment Care-specific Partner onboarding information.
///
/// Storage:
/// onboardingData.extensions.garmentCare
class GarmentCarePartnerDetails {
  const GarmentCarePartnerDetails({
    this.capabilitySelection = const PartnerCapabilitySelection(),
    this.experienceYears,
    this.serviceArea,
    this.teamSize,
    this.normalDailyCapacity,
    this.peakDailyCapacity,
    this.averageTurnaroundHours,
    this.expressServiceAvailable = false,
    this.additionalNotes,
  });

  final PartnerCapabilitySelection capabilitySelection;
  final int? experienceYears;
  final String? serviceArea;
  final int? teamSize;
  final int? normalDailyCapacity;
  final int? peakDailyCapacity;

  /// Typical service completion time in hours.
  final int? averageTurnaroundHours;

  /// Whether expedited Garment Care service is generally available.
  final bool expressServiceAvailable;

  final String? additionalNotes;

  bool get hasOperationalInformation {
    return capabilitySelection.normalizedCapabilityCodes.isNotEmpty ||
        capabilitySelection.normalizedAdditionalDescriptions.isNotEmpty ||
        experienceYears != null ||
        _text(serviceArea) != null ||
        teamSize != null ||
        normalDailyCapacity != null ||
        peakDailyCapacity != null ||
        averageTurnaroundHours != null ||
        expressServiceAvailable ||
        _text(additionalNotes) != null;
  }

  Map<String, dynamic> toMap() {
    return {
      'capabilities': capabilitySelection.toMap(),
      'experienceYears': _nonNegative(experienceYears),
      'serviceArea': _text(serviceArea),
      'teamSize': _nonNegative(teamSize),
      'normalDailyCapacity': _nonNegative(normalDailyCapacity),
      'peakDailyCapacity': _nonNegative(peakDailyCapacity),
      'averageTurnaroundHours': _nonNegative(averageTurnaroundHours),
      'expressServiceAvailable': expressServiceAvailable,
      'additionalNotes': _text(additionalNotes),
    };
  }

  factory GarmentCarePartnerDetails.fromOnboardingData(
    Map<String, dynamic> onboardingData,
  ) {
    final extensionsValue = onboardingData['extensions'];

    if (extensionsValue is! Map) {
      return const GarmentCarePartnerDetails();
    }

    final extensions = Map<String, dynamic>.from(extensionsValue);
    final categoryValue = extensions['garmentCare'];

    if (categoryValue is! Map) {
      return const GarmentCarePartnerDetails();
    }

    return GarmentCarePartnerDetails.fromMap(
      Map<String, dynamic>.from(categoryValue),
    );
  }

  factory GarmentCarePartnerDetails.fromMap(Map<String, dynamic> data) {
    final capabilitiesValue = data['capabilities'];
    final capabilities = capabilitiesValue is Map
        ? Map<String, dynamic>.from(capabilitiesValue)
        : <String, dynamic>{};

    return GarmentCarePartnerDetails(
      capabilitySelection: capabilities.isEmpty
          ? const PartnerCapabilitySelection()
          : PartnerCapabilitySelection.fromMap(capabilities),
      experienceYears: _int(data['experienceYears']),
      serviceArea: _text(data['serviceArea']?.toString()),
      teamSize: _int(data['teamSize']),
      normalDailyCapacity: _int(data['normalDailyCapacity']),
      peakDailyCapacity: _int(data['peakDailyCapacity']),
      averageTurnaroundHours: _int(data['averageTurnaroundHours']),
      expressServiceAvailable: data['expressServiceAvailable'] == true,
      additionalNotes: _text(data['additionalNotes']?.toString()),
    );
  }

  static int? _int(Object? value) {
    final parsed = value is int ? value : int.tryParse(value?.toString() ?? '');

    return _nonNegative(parsed);
  }

  static int? _nonNegative(int? value) {
    if (value == null || value < 0) {
      return null;
    }

    return value;
  }

  static String? _text(String? value) {
    final normalized = value?.trim() ?? '';

    return normalized.isEmpty ? null : normalized;
  }
}
