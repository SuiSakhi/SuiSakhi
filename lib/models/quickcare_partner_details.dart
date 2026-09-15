import 'partner_capability_selection.dart';

/// QuickCare-specific onboarding information.
/// Storage: onboardingData.extensions.doorstepServices
class QuickCarePartnerDetails {
  const QuickCarePartnerDetails({
    this.capabilitySelection = const PartnerCapabilitySelection(),
    this.providerTypeCode,
    this.skillLevelCode,
    this.experienceYears,
    this.experienceSummary,
    this.serviceArea,
    this.serviceRadiusKm,
    this.willingToTravelForUrgentSpecial = false,
    this.teamSize,
    this.normalDailyCapacity,
    this.peakDailyCapacity,
    this.typicalServiceDurationCode,
    this.typicalResponseTimeCode,
    this.sameDayServiceAvailable = false,
    this.emergencyServiceAvailable = false,
    this.transportModeCode,
    this.customerCoordinationComfortable = false,
    this.additionalNotes,
  });

  final PartnerCapabilitySelection capabilitySelection;
  final String? providerTypeCode;
  final String? skillLevelCode;
  final int? experienceYears;
  final String? experienceSummary;
  final String? serviceArea;
  final int? serviceRadiusKm;
  final bool willingToTravelForUrgentSpecial;
  final int? teamSize;
  final int? normalDailyCapacity;
  final int? peakDailyCapacity;
  final String? typicalServiceDurationCode;
  final String? typicalResponseTimeCode;
  final bool sameDayServiceAvailable;
  final bool emergencyServiceAvailable;
  final String? transportModeCode;
  final bool customerCoordinationComfortable;
  final String? additionalNotes;

  Map<String, dynamic> toMap() => {
    'capabilities': capabilitySelection.toMap(),
    'providerTypeCode': _text(providerTypeCode),
    'skillLevelCode': _text(skillLevelCode),
    'experienceYears': _nonNegative(experienceYears),
    'experienceSummary': _text(experienceSummary),
    'serviceArea': _text(serviceArea),
    'serviceRadiusKm': _nonNegative(serviceRadiusKm),
    'willingToTravelForUrgentSpecial': willingToTravelForUrgentSpecial,
    'teamSize': _nonNegative(teamSize),
    'normalDailyCapacity': _nonNegative(normalDailyCapacity),
    'peakDailyCapacity': _nonNegative(peakDailyCapacity),
    'typicalServiceDurationCode': _text(typicalServiceDurationCode),
    'typicalResponseTimeCode': _text(typicalResponseTimeCode),
    'sameDayServiceAvailable': sameDayServiceAvailable,
    'emergencyServiceAvailable': emergencyServiceAvailable,
    'transportModeCode': _text(transportModeCode),
    'customerCoordinationComfortable': customerCoordinationComfortable,
    'additionalNotes': _text(additionalNotes),
  };

  factory QuickCarePartnerDetails.fromOnboardingData(
    Map<String, dynamic> data,
  ) {
    final extensions = data['extensions'];
    if (extensions is! Map) return const QuickCarePartnerDetails();
    final category = extensions['doorstepServices'];
    if (category is! Map) return const QuickCarePartnerDetails();
    return QuickCarePartnerDetails.fromMap(Map<String, dynamic>.from(category));
  }

  factory QuickCarePartnerDetails.fromMap(Map<String, dynamic> data) {
    final value = data['capabilities'];
    final capabilities = value is Map
        ? Map<String, dynamic>.from(value)
        : <String, dynamic>{};
    return QuickCarePartnerDetails(
      capabilitySelection: capabilities.isEmpty
          ? const PartnerCapabilitySelection()
          : PartnerCapabilitySelection.fromMap(capabilities),
      providerTypeCode: _text(data['providerTypeCode']?.toString()),
      skillLevelCode: _text(data['skillLevelCode']?.toString()),
      experienceYears: _int(data['experienceYears']),
      experienceSummary: _text(data['experienceSummary']?.toString()),
      serviceArea: _text(data['serviceArea']?.toString()),
      serviceRadiusKm: _int(data['serviceRadiusKm']),
      willingToTravelForUrgentSpecial:
          data['willingToTravelForUrgentSpecial'] == true,
      teamSize: _int(data['teamSize']),
      normalDailyCapacity: _int(data['normalDailyCapacity']),
      peakDailyCapacity: _int(data['peakDailyCapacity']),
      typicalServiceDurationCode: _text(
        data['typicalServiceDurationCode']?.toString(),
      ),
      typicalResponseTimeCode: _text(
        data['typicalResponseTimeCode']?.toString(),
      ),
      sameDayServiceAvailable: data['sameDayServiceAvailable'] == true,
      emergencyServiceAvailable: data['emergencyServiceAvailable'] == true,
      transportModeCode: _text(data['transportModeCode']?.toString()),
      customerCoordinationComfortable:
          data['customerCoordinationComfortable'] == true,
      additionalNotes: _text(data['additionalNotes']?.toString()),
    );
  }

  static int? _int(Object? value) => _nonNegative(
    value is int ? value : int.tryParse(value?.toString() ?? ''),
  );
  static int? _nonNegative(int? value) =>
      value == null || value < 0 ? null : value;
  static String? _text(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? null : text;
  }
}
