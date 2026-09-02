class AddressMetadataOption {
  const AddressMetadataOption({required this.code, required this.label});

  final String code;
  final String label;
}

abstract interface class AddressMetadataProvider {
  List<AddressMetadataOption> get states;

  List<AddressMetadataOption> citiesForState(String stateCode);

  AddressMetadataOption? stateForCode(String? stateCode);

  AddressMetadataOption? cityForCode({
    required String? stateCode,
    required String? cityCode,
  });

  String? stateCodeForLabel(String? stateLabel);

  String? cityCodeForLabel({
    required String? stateCode,
    required String? cityLabel,
  });
}
