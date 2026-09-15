import 'partner_capability_selection.dart';

class RentalPartnerDetails {
  const RentalPartnerDetails({
    this.capabilitySelection = const PartnerCapabilitySelection(),
    this.serviceArea,
    this.teamSize,
    this.normalDailyCapacity,
    this.peakDailyCapacity,
    this.inventorySummary,
    this.rentalTermsSummary,
    this.cleaningReadinessSummary,
    this.trialFacilityAvailable = false,
    this.homeTrialAvailable = false,
    this.securityDepositRequired = false,
    this.additionalNotes,
  });

  final PartnerCapabilitySelection capabilitySelection;
  final String? serviceArea;
  final int? teamSize;
  final int? normalDailyCapacity;
  final int? peakDailyCapacity;
  final String? inventorySummary;
  final String? rentalTermsSummary;
  final String? cleaningReadinessSummary;
  final bool trialFacilityAvailable;
  final bool homeTrialAvailable;
  final bool securityDepositRequired;
  final String? additionalNotes;

  Map<String, dynamic> toMap() => {
    'capabilities': capabilitySelection.toMap(),
    'serviceArea': _text(serviceArea),
    'teamSize': _nonNegative(teamSize),
    'normalDailyCapacity': _nonNegative(normalDailyCapacity),
    'peakDailyCapacity': _nonNegative(peakDailyCapacity),
    'inventorySummary': _text(inventorySummary),
    'rentalTermsSummary': _text(rentalTermsSummary),
    'cleaningReadinessSummary': _text(cleaningReadinessSummary),
    'trialFacilityAvailable': trialFacilityAvailable,
    'homeTrialAvailable': homeTrialAvailable,
    'securityDepositRequired': securityDepositRequired,
    'additionalNotes': _text(additionalNotes),
  };

  factory RentalPartnerDetails.fromOnboardingData(Map<String, dynamic> data) {
    final extensions = data['extensions'];
    if (extensions is! Map) {
      return const RentalPartnerDetails();
    }
    final value = extensions['rental'];
    if (value is! Map) {
      return const RentalPartnerDetails();
    }
    return RentalPartnerDetails.fromMap(Map<String, dynamic>.from(value));
  }

  factory RentalPartnerDetails.fromMap(Map<String, dynamic> data) {
    final capabilityValue = data['capabilities'];
    final capabilities = capabilityValue is Map
        ? Map<String, dynamic>.from(capabilityValue)
        : <String, dynamic>{};
    return RentalPartnerDetails(
      capabilitySelection: capabilities.isEmpty
          ? const PartnerCapabilitySelection()
          : PartnerCapabilitySelection.fromMap(capabilities),
      serviceArea: _text(data['serviceArea']?.toString()),
      teamSize: _int(data['teamSize']),
      normalDailyCapacity: _int(data['normalDailyCapacity']),
      peakDailyCapacity: _int(data['peakDailyCapacity']),
      inventorySummary: _text(data['inventorySummary']?.toString()),
      rentalTermsSummary: _text(data['rentalTermsSummary']?.toString()),
      cleaningReadinessSummary: _text(
        data['cleaningReadinessSummary']?.toString(),
      ),
      trialFacilityAvailable: data['trialFacilityAvailable'] == true,
      homeTrialAvailable: data['homeTrialAvailable'] == true,
      securityDepositRequired: data['securityDepositRequired'] == true,
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
