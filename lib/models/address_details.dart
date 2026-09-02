class AddressDetails {
  const AddressDetails({
    this.addressLine1,
    this.addressLine2,
    this.locality,
    this.landmark,
    this.cityCode,
    this.cityName,
    this.stateCode,
    this.stateName,
    this.pincode,
    this.countryCode = 'IN',
    this.formattedAddressValue,
    this.placeId,
    this.latitude,
    this.longitude,
    this.geoHash,
  });

  final String? addressLine1;
  final String? addressLine2;
  final String? locality;
  final String? landmark;

  final String? cityCode;
  final String? cityName;

  final String? stateCode;
  final String? stateName;

  final String? pincode;
  final String countryCode;

  final String? formattedAddressValue;

  final String? placeId;
  final double? latitude;
  final double? longitude;
  final String? geoHash;

  bool get hasMinimumRequiredData {
    return _hasText(addressLine1) &&
        _hasText(cityName) &&
        _hasText(stateName) &&
        isValidIndianPincode(pincode);
  }

  bool get hasCoordinates {
    return latitude != null && longitude != null;
  }

  String get formattedAddress {
    final explicitAddress = formattedAddressValue?.trim() ?? '';

    if (explicitAddress.isNotEmpty) {
      return explicitAddress;
    }

    final lines = <String>[
      _joinNonEmpty([addressLine1, addressLine2]),
      _joinNonEmpty([
        locality,
        if (_hasText(landmark)) 'Landmark: ${landmark!.trim()}',
      ]),
      _joinNonEmpty([cityName, stateName, pincode]),
    ].where((line) => line.isNotEmpty).toList(growable: false);

    return lines.join('\n');
  }

  AddressDetails copyWith({
    String? addressLine1,
    String? addressLine2,
    String? locality,
    String? landmark,
    String? cityCode,
    String? cityName,
    String? stateCode,
    String? stateName,
    String? pincode,
    String? countryCode,
    String? formattedAddressValue,
    String? placeId,
    double? latitude,
    double? longitude,
    String? geoHash,
  }) {
    return AddressDetails(
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      locality: locality ?? this.locality,
      landmark: landmark ?? this.landmark,
      cityCode: cityCode ?? this.cityCode,
      cityName: cityName ?? this.cityName,
      stateCode: stateCode ?? this.stateCode,
      stateName: stateName ?? this.stateName,
      pincode: pincode ?? this.pincode,
      countryCode: countryCode ?? this.countryCode,
      formattedAddressValue:
          formattedAddressValue ?? this.formattedAddressValue,
      placeId: placeId ?? this.placeId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      geoHash: geoHash ?? this.geoHash,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'addressLine1': _normalizedOrNull(addressLine1),
      'addressLine2': _normalizedOrNull(addressLine2),
      'locality': _normalizedOrNull(locality),
      'landmark': _normalizedOrNull(landmark),
      'cityCode': _normalizedOrNull(cityCode),
      'cityName': _normalizedOrNull(cityName),

      // Legacy-compatible display field.
      'city': _normalizedOrNull(cityName),

      'stateCode': _normalizedOrNull(stateCode),
      'stateName': _normalizedOrNull(stateName),

      // Legacy-compatible display field.
      'state': _normalizedOrNull(stateName),

      'pincode': _normalizedOrNull(pincode),
      'countryCode': countryCode.trim().isEmpty
          ? 'IN'
          : countryCode.trim().toUpperCase(),
      'formattedAddress': formattedAddress,
      'placeId': _normalizedOrNull(placeId),
      'latitude': latitude,
      'longitude': longitude,
      'geoHash': _normalizedOrNull(geoHash),
    };
  }

  factory AddressDetails.fromMap(Map<String, dynamic> data) {
    final storedCityName =
        data['cityName']?.toString() ?? data['city']?.toString();

    final storedStateName =
        data['stateName']?.toString() ?? data['state']?.toString();

    return AddressDetails(
      addressLine1: data['addressLine1']?.toString(),
      addressLine2: data['addressLine2']?.toString(),
      locality: data['locality']?.toString(),
      landmark: data['landmark']?.toString(),
      cityCode: data['cityCode']?.toString(),
      cityName: storedCityName,
      stateCode: data['stateCode']?.toString(),
      stateName: storedStateName,
      pincode: data['pincode']?.toString() ?? data['postalCode']?.toString(),
      countryCode: data['countryCode']?.toString() ?? 'IN',
      formattedAddressValue: data['formattedAddress']?.toString(),
      placeId: data['placeId']?.toString(),
      latitude: _doubleFromValue(data['latitude']),
      longitude: _doubleFromValue(data['longitude']),
      geoHash: data['geoHash']?.toString(),
    );
  }

  static bool isValidIndianPincode(String? value) {
    final normalizedValue = value?.trim() ?? '';

    return RegExp(r'^[1-9][0-9]{5}$').hasMatch(normalizedValue);
  }

  static bool _hasText(String? value) {
    return value?.trim().isNotEmpty == true;
  }

  static String _joinNonEmpty(Iterable<String?> values) {
    return values
        .map((value) => value?.trim() ?? '')
        .where((value) => value.isNotEmpty)
        .join(', ');
  }

  static String? _normalizedOrNull(String? value) {
    final normalizedValue = value?.trim() ?? '';

    return normalizedValue.isEmpty ? null : normalizedValue;
  }

  static double? _doubleFromValue(Object? value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '');
  }
}
