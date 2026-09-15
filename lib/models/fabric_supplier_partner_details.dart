import 'partner_capability_selection.dart';

class FabricSupplierPartnerDetails {
  const FabricSupplierPartnerDetails({
    this.capabilitySelection = const PartnerCapabilitySelection(),
    this.serviceArea,
    this.teamSize,
    this.normalDailyCapacity,
    this.peakDailyCapacity,
    this.inventorySummary,
    this.minimumOrderQuantity,
    this.inventoryAvailable = false,
    this.catalogueAvailable = false,
    this.additionalNotes,
  });

  final PartnerCapabilitySelection capabilitySelection;
  final String? serviceArea;
  final int? teamSize;
  final int? normalDailyCapacity;
  final int? peakDailyCapacity;
  final String? inventorySummary;
  final int? minimumOrderQuantity;
  final bool inventoryAvailable;
  final bool catalogueAvailable;
  final String? additionalNotes;

  Map<String, dynamic> toMap() => {
    'capabilities': capabilitySelection.toMap(),
    'serviceArea': _text(serviceArea),
    'teamSize': _nonNegative(teamSize),
    'normalDailyCapacity': _nonNegative(normalDailyCapacity),
    'peakDailyCapacity': _nonNegative(peakDailyCapacity),
    'inventorySummary': _text(inventorySummary),
    'minimumOrderQuantity': _nonNegative(minimumOrderQuantity),
    'inventoryAvailable': inventoryAvailable,
    'catalogueAvailable': catalogueAvailable,
    'additionalNotes': _text(additionalNotes),
  };

  factory FabricSupplierPartnerDetails.fromOnboardingData(
    Map<String, dynamic> data,
  ) {
    final extensions = data['extensions'];
    if (extensions is! Map) {
      return const FabricSupplierPartnerDetails();
    }
    final value = extensions['fabricSupplier'];
    if (value is! Map) {
      return const FabricSupplierPartnerDetails();
    }
    return FabricSupplierPartnerDetails.fromMap(
      Map<String, dynamic>.from(value),
    );
  }

  factory FabricSupplierPartnerDetails.fromMap(Map<String, dynamic> data) {
    final capabilityValue = data['capabilities'];
    final capabilities = capabilityValue is Map
        ? Map<String, dynamic>.from(capabilityValue)
        : <String, dynamic>{};
    return FabricSupplierPartnerDetails(
      capabilitySelection: capabilities.isEmpty
          ? const PartnerCapabilitySelection()
          : PartnerCapabilitySelection.fromMap(capabilities),
      serviceArea: _text(data['serviceArea']?.toString()),
      teamSize: _int(data['teamSize']),
      normalDailyCapacity: _int(data['normalDailyCapacity']),
      peakDailyCapacity: _int(data['peakDailyCapacity']),
      inventorySummary: _text(data['inventorySummary']?.toString()),
      minimumOrderQuantity: _int(data['minimumOrderQuantity']),
      inventoryAvailable: data['inventoryAvailable'] == true,
      catalogueAvailable: data['catalogueAvailable'] == true,
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
