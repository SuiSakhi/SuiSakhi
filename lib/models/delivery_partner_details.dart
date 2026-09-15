import 'partner_capability_selection.dart';

class DeliveryPartnerDetails {
  const DeliveryPartnerDetails({
    this.capabilitySelection = const PartnerCapabilitySelection(),
    this.serviceArea,
    this.teamSize,
    this.normalDailyCapacity,
    this.peakDailyCapacity,
    this.vehicleTypeCode,
    this.riderOrTeamCount,
    this.averageDeliveryTimeHours,

    this.additionalNotes,
  });

  final PartnerCapabilitySelection capabilitySelection;
  final String? serviceArea;
  final int? teamSize;
  final int? normalDailyCapacity;
  final int? peakDailyCapacity;
  final String? vehicleTypeCode;
  final int? riderOrTeamCount;
  final int? averageDeliveryTimeHours;

  final String? additionalNotes;

  Map<String, dynamic> toMap() => {
    'capabilities': capabilitySelection.toMap(),
    'serviceArea': _text(serviceArea),
    'teamSize': _nonNegative(teamSize),
    'normalDailyCapacity': _nonNegative(normalDailyCapacity),
    'peakDailyCapacity': _nonNegative(peakDailyCapacity),
    'vehicleTypeCode': _text(vehicleTypeCode),
    'riderOrTeamCount': _nonNegative(riderOrTeamCount),
    'averageDeliveryTimeHours': _nonNegative(averageDeliveryTimeHours),

    'additionalNotes': _text(additionalNotes),
  };

  factory DeliveryPartnerDetails.fromOnboardingData(Map<String, dynamic> data) {
    final extensions = data['extensions'];
    if (extensions is! Map) {
      return const DeliveryPartnerDetails();
    }
    final value = extensions['deliveryPartner'];
    if (value is! Map) {
      return const DeliveryPartnerDetails();
    }
    return DeliveryPartnerDetails.fromMap(Map<String, dynamic>.from(value));
  }

  factory DeliveryPartnerDetails.fromMap(Map<String, dynamic> data) {
    final capabilityValue = data['capabilities'];
    final capabilities = capabilityValue is Map
        ? Map<String, dynamic>.from(capabilityValue)
        : <String, dynamic>{};
    return DeliveryPartnerDetails(
      capabilitySelection: capabilities.isEmpty
          ? const PartnerCapabilitySelection()
          : PartnerCapabilitySelection.fromMap(capabilities),
      serviceArea: _text(data['serviceArea']?.toString()),
      teamSize: _int(data['teamSize']),
      normalDailyCapacity: _int(data['normalDailyCapacity']),
      peakDailyCapacity: _int(data['peakDailyCapacity']),
      vehicleTypeCode: _text(data['vehicleTypeCode']?.toString()),
      riderOrTeamCount: _int(data['riderOrTeamCount']),
      averageDeliveryTimeHours: _int(data['averageDeliveryTimeHours']),

      additionalNotes: _text(data['additionalNotes']?.toString()),
    );
  }

  static int? _int(Object? value) => _nonNegative(
    value is int ? value : int.tryParse(value?.toString() ?? ''),
  );
  static int? _nonNegative(int? value) =>
      value == null || value < 0 ? null : value;
  static String? _text(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }
}
