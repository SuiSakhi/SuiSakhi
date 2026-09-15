import 'partner_capability_selection.dart';

class PrintingPartnerDetails {
  const PrintingPartnerDetails({
    this.capabilitySelection = const PartnerCapabilitySelection(),
    this.serviceArea,
    this.teamSize,
    this.normalDailyCapacity,
    this.peakDailyCapacity,
    this.minimumOrderQuantity,
    this.averageTurnaroundHours,
    this.expressOrdersAvailable = false,
    this.additionalNotes,
  });

  final PartnerCapabilitySelection capabilitySelection;
  final String? serviceArea;
  final int? teamSize;
  final int? normalDailyCapacity;
  final int? peakDailyCapacity;
  final int? minimumOrderQuantity;
  final int? averageTurnaroundHours;
  final bool expressOrdersAvailable;
  final String? additionalNotes;

  Map<String, dynamic> toMap() => {
    'capabilities': capabilitySelection.toMap(),
    'serviceArea': _text(serviceArea),
    'teamSize': _nonNegative(teamSize),
    'normalDailyCapacity': _nonNegative(normalDailyCapacity),
    'peakDailyCapacity': _nonNegative(peakDailyCapacity),
    'minimumOrderQuantity': _nonNegative(minimumOrderQuantity),
    'averageTurnaroundHours': _nonNegative(averageTurnaroundHours),
    'expressOrdersAvailable': expressOrdersAvailable,
    'additionalNotes': _text(additionalNotes),
  };

  factory PrintingPartnerDetails.fromOnboardingData(Map<String, dynamic> data) {
    final extensions = data['extensions'];
    if (extensions is! Map) {
      return const PrintingPartnerDetails();
    }
    final value = extensions['printing'];
    if (value is! Map) {
      return const PrintingPartnerDetails();
    }
    return PrintingPartnerDetails.fromMap(Map<String, dynamic>.from(value));
  }

  factory PrintingPartnerDetails.fromMap(Map<String, dynamic> data) {
    final capabilityValue = data['capabilities'];
    final capabilities = capabilityValue is Map
        ? Map<String, dynamic>.from(capabilityValue)
        : <String, dynamic>{};
    return PrintingPartnerDetails(
      capabilitySelection: capabilities.isEmpty
          ? const PartnerCapabilitySelection()
          : PartnerCapabilitySelection.fromMap(capabilities),
      serviceArea: _text(data['serviceArea']?.toString()),
      teamSize: _int(data['teamSize']),
      normalDailyCapacity: _int(data['normalDailyCapacity']),
      peakDailyCapacity: _int(data['peakDailyCapacity']),
      minimumOrderQuantity: _int(data['minimumOrderQuantity']),
      averageTurnaroundHours: _int(data['averageTurnaroundHours']),
      expressOrdersAvailable: data['expressOrdersAvailable'] == true,
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
