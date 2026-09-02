import '../../services/address_metadata_provider.dart';

class IndiaAddressMetadata implements AddressMetadataProvider {
  const IndiaAddressMetadata();

  static const instance = IndiaAddressMetadata();

  static const List<AddressMetadataOption> _stateOptions = [
    AddressMetadataOption(code: 'MH', label: 'Maharashtra'),
    AddressMetadataOption(code: 'GJ', label: 'Gujarat'),
    AddressMetadataOption(code: 'KA', label: 'Karnataka'),
    AddressMetadataOption(code: 'TG', label: 'Telangana'),
    AddressMetadataOption(code: 'GA', label: 'Goa'),
  ];

  static const Map<String, List<AddressMetadataOption>> _cityOptionsByState = {
    'MH': [
      AddressMetadataOption(code: 'PUNE', label: 'Pune'),
      AddressMetadataOption(code: 'MUMBAI', label: 'Mumbai'),
      AddressMetadataOption(code: 'NAGPUR', label: 'Nagpur'),
      AddressMetadataOption(code: 'NASHIK', label: 'Nashik'),
      AddressMetadataOption(code: 'KOLHAPUR', label: 'Kolhapur'),
      AddressMetadataOption(code: 'THANE', label: 'Thane'),
      AddressMetadataOption(
        code: 'CHHATRAPATI_SAMBHAJINAGAR',
        label: 'Chhatrapati Sambhajinagar',
      ),
      AddressMetadataOption(code: 'SOLAPUR', label: 'Solapur'),
      AddressMetadataOption(code: 'SATARA', label: 'Satara'),
      AddressMetadataOption(code: 'SANGLI', label: 'Sangli'),
    ],
    'GJ': [
      AddressMetadataOption(code: 'AHMEDABAD', label: 'Ahmedabad'),
      AddressMetadataOption(code: 'SURAT', label: 'Surat'),
      AddressMetadataOption(code: 'VADODARA', label: 'Vadodara'),
      AddressMetadataOption(code: 'RAJKOT', label: 'Rajkot'),
    ],
    'KA': [
      AddressMetadataOption(code: 'BENGALURU', label: 'Bengaluru'),
      AddressMetadataOption(code: 'MYSURU', label: 'Mysuru'),
      AddressMetadataOption(code: 'HUBBALLI', label: 'Hubballi'),
      AddressMetadataOption(code: 'MANGALURU', label: 'Mangaluru'),
    ],
    'TG': [
      AddressMetadataOption(code: 'HYDERABAD', label: 'Hyderabad'),
      AddressMetadataOption(code: 'WARANGAL', label: 'Warangal'),
      AddressMetadataOption(code: 'NIZAMABAD', label: 'Nizamabad'),
    ],
    'GA': [
      AddressMetadataOption(code: 'PANAJI', label: 'Panaji'),
      AddressMetadataOption(code: 'MARGAO', label: 'Margao'),
      AddressMetadataOption(code: 'VASCO_DA_GAMA', label: 'Vasco da Gama'),
    ],
  };

  @override
  List<AddressMetadataOption> get states {
    return List.unmodifiable(_stateOptions);
  }

  @override
  List<AddressMetadataOption> citiesForState(String stateCode) {
    final normalizedCode = stateCode.trim().toUpperCase();

    return List.unmodifiable(
      _cityOptionsByState[normalizedCode] ?? const <AddressMetadataOption>[],
    );
  }

  @override
  AddressMetadataOption? stateForCode(String? stateCode) {
    final normalizedCode = stateCode?.trim().toUpperCase() ?? '';

    if (normalizedCode.isEmpty) {
      return null;
    }

    for (final state in _stateOptions) {
      if (state.code == normalizedCode) {
        return state;
      }
    }

    return null;
  }

  @override
  AddressMetadataOption? cityForCode({
    required String? stateCode,
    required String? cityCode,
  }) {
    final normalizedStateCode = stateCode?.trim().toUpperCase() ?? '';

    final normalizedCityCode = cityCode?.trim().toUpperCase() ?? '';

    if (normalizedStateCode.isEmpty || normalizedCityCode.isEmpty) {
      return null;
    }

    for (final city in citiesForState(normalizedStateCode)) {
      if (city.code == normalizedCityCode) {
        return city;
      }
    }

    return null;
  }

  @override
  String? stateCodeForLabel(String? stateLabel) {
    final normalizedLabel = stateLabel?.trim().toLowerCase() ?? '';

    if (normalizedLabel.isEmpty) {
      return null;
    }

    for (final state in _stateOptions) {
      if (state.label.toLowerCase() == normalizedLabel) {
        return state.code;
      }
    }

    return null;
  }

  @override
  String? cityCodeForLabel({
    required String? stateCode,
    required String? cityLabel,
  }) {
    final normalizedLabel = cityLabel?.trim().toLowerCase() ?? '';

    if (stateCode == null ||
        stateCode.trim().isEmpty ||
        normalizedLabel.isEmpty) {
      return null;
    }

    for (final city in citiesForState(stateCode)) {
      if (city.label.toLowerCase() == normalizedLabel) {
        return city.code;
      }
    }

    return null;
  }
}
