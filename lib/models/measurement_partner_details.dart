import 'address_details.dart';
import 'operating_schedule.dart';
import 'partner_capability_selection.dart';

// ============================================================================
// MEASUREMENT PARTNER EXTENSION: OPERATIONAL DETAILS
// ============================================================================
//
// Stores Measurement Partner-specific operational information under:
//
// onboardingData.extensions.measurementPartner
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
// MEASUREMENT AUTHORITY:
//
// A Measurement Partner may collect and record measurement inputs.
// Only the assigned Tailor confirms the final measurement before stitching.
// ============================================================================

class MeasurementPartnerDetails {
  const MeasurementPartnerDetails({
    this.serviceAddress = const AddressDetails(),
    this.serviceAreaPincodes = const <String>[],
    this.maximumTravelDistanceKm,
    this.operatingSchedule = const OperatingSchedule(),
    this.capabilitySelection = const PartnerCapabilitySelection(),
    this.measurementsPerDay,
    this.homeVisitsPerDay,
    this.videoSessionsPerDay,
    this.serviceNotes,
  });

  // ==========================================================================
  // COMMON PARTNER FOUNDATION
  // ==========================================================================

  final AddressDetails serviceAddress;

  final List<String> serviceAreaPincodes;

  final double? maximumTravelDistanceKm;

  final OperatingSchedule operatingSchedule;

  // ==========================================================================
  // MEASUREMENT PARTNER EXTENSION
  // ==========================================================================

  final PartnerCapabilitySelection capabilitySelection;

  final int? measurementsPerDay;

  final int? homeVisitsPerDay;

  final int? videoSessionsPerDay;

  final String? serviceNotes;

  bool get hasOperationalInformation {
    return _hasAddressInformation(serviceAddress) ||
        normalizedServiceAreaPincodes.isNotEmpty ||
        maximumTravelDistanceKm != null ||
        operatingSchedule.hasOperatingDays ||
        operatingSchedule.hasOpeningTime ||
        operatingSchedule.hasClosingTime ||
        capabilitySelection.normalizedCapabilityCodes.isNotEmpty ||
        capabilitySelection.normalizedAdditionalDescriptions.isNotEmpty ||
        measurementsPerDay != null ||
        homeVisitsPerDay != null ||
        videoSessionsPerDay != null ||
        _normalizedOptionalText(serviceNotes) != null;
  }

  List<String> get normalizedServiceAreaPincodes {
    final values = <String>{};

    for (final pincode in serviceAreaPincodes) {
      final normalizedValue = pincode.trim();

      if (normalizedValue.isNotEmpty) {
        values.add(normalizedValue);
      }
    }

    return values.toList(growable: false)..sort();
  }

  Map<String, dynamic> toMap() {
    return {
      // COMMON PARTNER FOUNDATION
      'serviceLocation': {
        'address': serviceAddress.toMap(),
        'serviceAreaPincodes': normalizedServiceAreaPincodes,
        'maximumTravelDistanceKm': maximumTravelDistanceKm,
      },
      'operatingSchedule': operatingSchedule.toMap(),

      // MEASUREMENT PARTNER EXTENSION
      'capabilities': capabilitySelection.toMap(),
      'capacity': {
        'measurementsPerDay': measurementsPerDay,
        'homeVisitsPerDay': homeVisitsPerDay,
        'videoSessionsPerDay': videoSessionsPerDay,
      },
      'serviceNotes': _normalizedOptionalText(serviceNotes),
    };
  }

  factory MeasurementPartnerDetails.fromOnboardingData(
    Map<String, dynamic> onboardingData,
  ) {
    final extensionsValue = onboardingData['extensions'];

    if (extensionsValue is! Map) {
      return const MeasurementPartnerDetails();
    }

    final extensions = Map<String, dynamic>.from(extensionsValue);
    final measurementPartnerValue = extensions['measurementPartner'];

    if (measurementPartnerValue is! Map) {
      return const MeasurementPartnerDetails();
    }

    return MeasurementPartnerDetails.fromMap(
      Map<String, dynamic>.from(measurementPartnerValue),
    );
  }

  factory MeasurementPartnerDetails.fromMap(Map<String, dynamic> data) {
    final serviceLocation = _mapFromValue(data['serviceLocation']);
    final address = _mapFromValue(serviceLocation['address']);
    final operatingSchedule = _mapFromValue(data['operatingSchedule']);
    final capabilities = _mapFromValue(data['capabilities']);
    final capacity = _mapFromValue(data['capacity']);

    return MeasurementPartnerDetails(
      serviceAddress: address.isEmpty
          ? const AddressDetails()
          : AddressDetails.fromMap(address),
      serviceAreaPincodes: _stringListFromValue(
        serviceLocation['serviceAreaPincodes'],
      ),
      maximumTravelDistanceKm: _doubleFromValue(
        serviceLocation['maximumTravelDistanceKm'],
      ),
      operatingSchedule: operatingSchedule.isEmpty
          ? const OperatingSchedule()
          : OperatingSchedule.fromMap(operatingSchedule),
      capabilitySelection: capabilities.isEmpty
          ? const PartnerCapabilitySelection()
          : PartnerCapabilitySelection.fromMap(capabilities),
      measurementsPerDay: _nonNegativeIntFromValue(
        capacity['measurementsPerDay'],
      ),
      homeVisitsPerDay: _nonNegativeIntFromValue(capacity['homeVisitsPerDay']),
      videoSessionsPerDay: _nonNegativeIntFromValue(
        capacity['videoSessionsPerDay'],
      ),
      serviceNotes: _normalizedOptionalText(data['serviceNotes']?.toString()),
    );
  }

  static Map<String, dynamic> _mapFromValue(Object? value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return <String, dynamic>{};
  }

  static List<String> _stringListFromValue(Object? value) {
    if (value is! Iterable) {
      return const <String>[];
    }

    final normalizedValues = <String>{};

    for (final item in value) {
      final normalizedValue = item.toString().trim();

      if (normalizedValue.isNotEmpty) {
        normalizedValues.add(normalizedValue);
      }
    }

    return normalizedValues.toList(growable: false)..sort();
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

  static double? _doubleFromValue(Object? value) {
    final parsedValue = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '');

    if (parsedValue == null || parsedValue <= 0) {
      return null;
    }

    return parsedValue;
  }

  static bool _hasAddressInformation(AddressDetails address) {
    return _normalizedOptionalText(address.addressLine1) != null ||
        _normalizedOptionalText(address.addressLine2) != null ||
        _normalizedOptionalText(address.locality) != null ||
        _normalizedOptionalText(address.landmark) != null ||
        _normalizedOptionalText(address.cityName) != null ||
        _normalizedOptionalText(address.stateName) != null ||
        _normalizedOptionalText(address.pincode) != null;
  }

  static String? _normalizedOptionalText(String? value) {
    final normalizedValue = value?.trim() ?? '';

    return normalizedValue.isEmpty ? null : normalizedValue;
  }
}
