import 'package:flutter/material.dart';

import '../../models/address_details.dart';
import '../../services/address_metadata_provider.dart';
import 'state_city_selector.dart';

class AddressFormSection extends StatefulWidget {
  const AddressFormSection({
    required this.metadataProvider,
    required this.onChanged,
    this.initialValue = const AddressDetails(),
    this.enabled = true,
    this.addressLine1Required = true,
    this.addressLine2Required = false,
    this.localityRequired = false,
    this.landmarkRequired = false,
    this.stateRequired = true,
    this.cityRequired = true,
    this.pincodeRequired = true,
    this.showAddressLine2 = true,
    this.showLocality = true,
    this.showLandmark = true,
    this.sectionTitle,
    this.addressLine1Label = 'Address Line 1',
    this.addressLine2Label = 'Address Line 2',
    this.localityLabel = 'Locality or Area',
    this.landmarkLabel = 'Landmark',
    this.stateLabel = 'State',
    this.cityLabel = 'City',
    this.pincodeLabel = 'Pincode',
    this.spacing = 12,
    super.key,
  });

  final AddressMetadataProvider metadataProvider;
  final AddressDetails initialValue;

  final bool enabled;

  final bool addressLine1Required;
  final bool addressLine2Required;
  final bool localityRequired;
  final bool landmarkRequired;
  final bool stateRequired;
  final bool cityRequired;
  final bool pincodeRequired;

  final bool showAddressLine2;
  final bool showLocality;
  final bool showLandmark;

  final String? sectionTitle;

  final String addressLine1Label;
  final String addressLine2Label;
  final String localityLabel;
  final String landmarkLabel;
  final String stateLabel;
  final String cityLabel;
  final String pincodeLabel;

  final double spacing;

  final ValueChanged<AddressDetails> onChanged;

  @override
  State<AddressFormSection> createState() {
    return _AddressFormSectionState();
  }
}

class _AddressFormSectionState extends State<AddressFormSection> {
  late final TextEditingController _addressLine1Controller;
  late final TextEditingController _addressLine2Controller;
  late final TextEditingController _localityController;
  late final TextEditingController _landmarkController;
  late final TextEditingController _pincodeController;

  String? _stateCode;
  String? _stateName;
  String? _cityCode;
  String? _cityName;

  @override
  void initState() {
    super.initState();

    _addressLine1Controller = TextEditingController();
    _addressLine2Controller = TextEditingController();
    _localityController = TextEditingController();
    _landmarkController = TextEditingController();
    _pincodeController = TextEditingController();

    _loadInitialValue(widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant AddressFormSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!_sameAddress(oldWidget.initialValue, widget.initialValue)) {
      _loadInitialValue(widget.initialValue);
    }
  }

  @override
  void dispose() {
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _localityController.dispose();
    _landmarkController.dispose();
    _pincodeController.dispose();

    super.dispose();
  }

  void _loadInitialValue(AddressDetails address) {
    _addressLine1Controller.text = address.addressLine1 ?? '';

    _addressLine2Controller.text = address.addressLine2 ?? '';

    _localityController.text = address.locality ?? '';

    _landmarkController.text = address.landmark ?? '';

    _pincodeController.text = address.pincode ?? '';

    _stateCode = _resolveStateCode(address);
    _stateName = _resolveStateName(address, _stateCode);

    _cityCode = _resolveCityCode(address, _stateCode);

    _cityName = _resolveCityName(
      address,
      stateCode: _stateCode,
      cityCode: _cityCode,
    );
  }

  String? _resolveStateCode(AddressDetails address) {
    final storedCode = address.stateCode?.trim().toUpperCase() ?? '';

    if (storedCode.isNotEmpty &&
        widget.metadataProvider.stateForCode(storedCode) != null) {
      return storedCode;
    }

    return widget.metadataProvider.stateCodeForLabel(address.stateName);
  }

  String? _resolveStateName(AddressDetails address, String? stateCode) {
    final storedName = address.stateName?.trim() ?? '';

    if (storedName.isNotEmpty) {
      return storedName;
    }

    return widget.metadataProvider.stateForCode(stateCode)?.label;
  }

  String? _resolveCityCode(AddressDetails address, String? stateCode) {
    if (stateCode == null || stateCode.isEmpty) {
      return null;
    }

    final storedCode = address.cityCode?.trim().toUpperCase() ?? '';

    if (storedCode.isNotEmpty &&
        widget.metadataProvider.cityForCode(
              stateCode: stateCode,
              cityCode: storedCode,
            ) !=
            null) {
      return storedCode;
    }

    return widget.metadataProvider.cityCodeForLabel(
      stateCode: stateCode,
      cityLabel: address.cityName,
    );
  }

  String? _resolveCityName(
    AddressDetails address, {
    required String? stateCode,
    required String? cityCode,
  }) {
    final storedName = address.cityName?.trim() ?? '';

    if (storedName.isNotEmpty) {
      return storedName;
    }

    return widget.metadataProvider
        .cityForCode(stateCode: stateCode, cityCode: cityCode)
        ?.label;
  }

  void _handleStateCityChanged(StateCitySelection selection) {
    _stateCode = selection.stateCode;
    _stateName = selection.stateName;
    _cityCode = selection.cityCode;
    _cityName = selection.cityName;

    _emitAddress();
  }

  void _emitAddress() {
    widget.onChanged(
      AddressDetails(
        addressLine1: _addressLine1Controller.text.trim(),
        addressLine2: _addressLine2Controller.text.trim(),
        locality: _localityController.text.trim(),
        landmark: _landmarkController.text.trim(),
        stateCode: _stateCode,
        stateName: _stateName,
        cityCode: _cityCode,
        cityName: _cityName,
        pincode: _pincodeController.text.trim(),
        countryCode: widget.initialValue.countryCode,
        formattedAddressValue: widget.initialValue.formattedAddressValue,
        placeId: widget.initialValue.placeId,
        latitude: widget.initialValue.latitude,
        longitude: widget.initialValue.longitude,
        geoHash: widget.initialValue.geoHash,
      ),
    );
  }

  String? _requiredTextValidator({
    required String? value,
    required String fieldLabel,
    required bool required,
  }) {
    if (!required) {
      return null;
    }

    if (value == null || value.trim().isEmpty) {
      return '$fieldLabel is required';
    }

    return null;
  }

  String? _pincodeValidator(String? value) {
    final normalizedValue = value?.trim() ?? '';

    if (normalizedValue.isEmpty) {
      return widget.pincodeRequired
          ? '${widget.pincodeLabel} is required'
          : null;
    }

    if (!AddressDetails.isValidIndianPincode(normalizedValue)) {
      return 'Enter a valid 6-digit pincode';
    }

    return null;
  }

  bool _sameAddress(AddressDetails first, AddressDetails second) {
    return first.addressLine1 == second.addressLine1 &&
        first.addressLine2 == second.addressLine2 &&
        first.locality == second.locality &&
        first.landmark == second.landmark &&
        first.stateCode == second.stateCode &&
        first.stateName == second.stateName &&
        first.cityCode == second.cityCode &&
        first.cityName == second.cityName &&
        first.pincode == second.pincode &&
        first.countryCode == second.countryCode &&
        first.formattedAddressValue == second.formattedAddressValue &&
        first.placeId == second.placeId &&
        first.latitude == second.latitude &&
        first.longitude == second.longitude &&
        first.geoHash == second.geoHash;
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool required,
    TextInputType? keyboardType,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      enabled: widget.enabled,
      keyboardType: keyboardType,
      textInputAction: TextInputAction.next,
      maxLength: maxLength,
      textCapitalization: keyboardType == TextInputType.number
          ? TextCapitalization.none
          : TextCapitalization.words,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
        counterText: maxLength == null ? null : '',
      ),
      validator:
          validator ??
          (value) {
            return _requiredTextValidator(
              value: value,
              fieldLabel: label,
              required: required,
            );
          },
      onChanged: (_) {
        _emitAddress();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.sectionTitle != null &&
            widget.sectionTitle!.trim().isNotEmpty) ...[
          Text(
            widget.sectionTitle!.trim(),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: widget.spacing),
        ],
        _buildTextField(
          controller: _addressLine1Controller,
          label: widget.addressLine1Label,
          icon: Icons.home_outlined,
          required: widget.addressLine1Required,
        ),
        if (widget.showAddressLine2) ...[
          SizedBox(height: widget.spacing),
          _buildTextField(
            controller: _addressLine2Controller,
            label: widget.addressLine2Label,
            icon: Icons.apartment_outlined,
            required: widget.addressLine2Required,
          ),
        ],
        if (widget.showLocality) ...[
          SizedBox(height: widget.spacing),
          _buildTextField(
            controller: _localityController,
            label: widget.localityLabel,
            icon: Icons.near_me_outlined,
            required: widget.localityRequired,
          ),
        ],
        if (widget.showLandmark) ...[
          SizedBox(height: widget.spacing),
          _buildTextField(
            controller: _landmarkController,
            label: widget.landmarkLabel,
            icon: Icons.place_outlined,
            required: widget.landmarkRequired,
          ),
        ],
        SizedBox(height: widget.spacing),
        StateCitySelector(
          key: ValueKey(
            'address-location-'
            '${_stateCode ?? _stateName ?? 'none'}-'
            '${_cityCode ?? _cityName ?? 'none'}',
          ),
          metadataProvider: widget.metadataProvider,
          initialStateCode: _stateCode,
          initialStateName: _stateName,
          initialCityCode: _cityCode,
          initialCityName: _cityName,
          enabled: widget.enabled,
          stateRequired: widget.stateRequired,
          cityRequired: widget.cityRequired,
          stateLabel: widget.stateLabel,
          cityLabel: widget.cityLabel,
          spacing: widget.spacing,
          onChanged: _handleStateCityChanged,
        ),
        SizedBox(height: widget.spacing),
        _buildTextField(
          controller: _pincodeController,
          label: widget.pincodeLabel,
          icon: Icons.pin_drop_outlined,
          required: widget.pincodeRequired,
          keyboardType: TextInputType.number,
          maxLength: 6,
          validator: _pincodeValidator,
        ),
      ],
    );
  }
}
