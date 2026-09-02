import 'package:flutter/material.dart';

import '../../services/address_metadata_provider.dart';

class StateCitySelection {
  const StateCitySelection({
    required this.stateCode,
    required this.stateName,
    this.cityCode,
    this.cityName,
  });

  final String stateCode;
  final String stateName;

  final String? cityCode;
  final String? cityName;

  bool get isComplete {
    return stateCode.trim().isNotEmpty &&
        stateName.trim().isNotEmpty &&
        cityCode?.trim().isNotEmpty == true &&
        cityName?.trim().isNotEmpty == true;
  }
}

class StateCitySelector extends StatefulWidget {
  const StateCitySelector({
    required this.metadataProvider,
    required this.onChanged,
    this.initialStateCode,
    this.initialStateName,
    this.initialCityCode,
    this.initialCityName,
    this.enabled = true,
    this.stateRequired = true,
    this.cityRequired = true,
    this.stateLabel = 'State',
    this.cityLabel = 'City',
    this.spacing = 12,
    super.key,
  });

  final AddressMetadataProvider metadataProvider;

  final String? initialStateCode;
  final String? initialStateName;

  final String? initialCityCode;
  final String? initialCityName;

  final bool enabled;
  final bool stateRequired;
  final bool cityRequired;

  final String stateLabel;
  final String cityLabel;

  final double spacing;

  final ValueChanged<StateCitySelection> onChanged;

  @override
  State<StateCitySelector> createState() {
    return _StateCitySelectorState();
  }
}

class _StateCitySelectorState extends State<StateCitySelector> {
  String? _selectedStateCode;
  String? _selectedCityCode;

  @override
  void initState() {
    super.initState();
    _loadInitialSelection();
  }

  @override
  void didUpdateWidget(covariant StateCitySelector oldWidget) {
    super.didUpdateWidget(oldWidget);

    final initialSelectionChanged =
        oldWidget.initialStateCode != widget.initialStateCode ||
        oldWidget.initialStateName != widget.initialStateName ||
        oldWidget.initialCityCode != widget.initialCityCode ||
        oldWidget.initialCityName != widget.initialCityName ||
        oldWidget.metadataProvider != widget.metadataProvider;

    if (initialSelectionChanged) {
      _loadInitialSelection();
    }
  }

  void _loadInitialSelection() {
    final stateCode = _resolveStateCode();
    final cityCode = _resolveCityCode(stateCode);

    _selectedStateCode = stateCode;
    _selectedCityCode = cityCode;
  }

  String? _resolveStateCode() {
    final normalizedCode = widget.initialStateCode?.trim().toUpperCase();

    if (normalizedCode?.isNotEmpty == true &&
        widget.metadataProvider.stateForCode(normalizedCode) != null) {
      return normalizedCode;
    }

    return widget.metadataProvider.stateCodeForLabel(widget.initialStateName);
  }

  String? _resolveCityCode(String? stateCode) {
    if (stateCode == null || stateCode.isEmpty) {
      return null;
    }

    final normalizedCode = widget.initialCityCode?.trim().toUpperCase();

    if (normalizedCode?.isNotEmpty == true &&
        widget.metadataProvider.cityForCode(
              stateCode: stateCode,
              cityCode: normalizedCode,
            ) !=
            null) {
      return normalizedCode;
    }

    return widget.metadataProvider.cityCodeForLabel(
      stateCode: stateCode,
      cityLabel: widget.initialCityName,
    );
  }

  List<AddressMetadataOption> get _states {
    return widget.metadataProvider.states;
  }

  List<AddressMetadataOption> get _cities {
    final stateCode = _selectedStateCode;

    if (stateCode == null || stateCode.isEmpty) {
      return const <AddressMetadataOption>[];
    }

    return widget.metadataProvider.citiesForState(stateCode);
  }

  void _selectState(String? stateCode) {
    if (stateCode == null || stateCode.isEmpty) {
      return;
    }

    final state = widget.metadataProvider.stateForCode(stateCode);

    if (state == null) {
      return;
    }

    setState(() {
      _selectedStateCode = state.code;
      _selectedCityCode = null;
    });

    widget.onChanged(
      StateCitySelection(stateCode: state.code, stateName: state.label),
    );
  }

  void _selectCity(String? cityCode) {
    final stateCode = _selectedStateCode;

    if (stateCode == null ||
        stateCode.isEmpty ||
        cityCode == null ||
        cityCode.isEmpty) {
      return;
    }

    final state = widget.metadataProvider.stateForCode(stateCode);

    final city = widget.metadataProvider.cityForCode(
      stateCode: stateCode,
      cityCode: cityCode,
    );

    if (state == null || city == null) {
      return;
    }

    setState(() {
      _selectedCityCode = city.code;
    });

    widget.onChanged(
      StateCitySelection(
        stateCode: state.code,
        stateName: state.label,
        cityCode: city.code,
        cityName: city.label,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final states = _states;
    final cities = _cities;

    return Column(
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey('state-${_selectedStateCode ?? 'none'}'),
          initialValue: _selectedStateCode,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: widget.stateLabel,
            prefixIcon: const Icon(Icons.map_outlined),
            border: const OutlineInputBorder(),
          ),
          items: states
              .map((state) {
                return DropdownMenuItem<String>(
                  value: state.code,
                  child: Text(state.label),
                );
              })
              .toList(growable: false),
          onChanged: widget.enabled ? _selectState : null,
          validator: (value) {
            if (!widget.stateRequired) {
              return null;
            }

            if (value == null || value.trim().isEmpty) {
              return '${widget.stateLabel} is required';
            }

            return null;
          },
        ),
        SizedBox(height: widget.spacing),
        DropdownButtonFormField<String>(
          key: ValueKey(
            'city-'
            '${_selectedStateCode ?? 'none'}-'
            '${_selectedCityCode ?? 'none'}',
          ),
          initialValue: _selectedCityCode,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: widget.cityLabel,
            prefixIcon: const Icon(Icons.location_city_outlined),
            border: const OutlineInputBorder(),
            helperText: _selectedStateCode == null
                ? 'Select a State first'
                : null,
          ),
          items: cities
              .map((city) {
                return DropdownMenuItem<String>(
                  value: city.code,
                  child: Text(city.label),
                );
              })
              .toList(growable: false),
          onChanged: widget.enabled && _selectedStateCode != null
              ? _selectCity
              : null,
          validator: (value) {
            if (!widget.cityRequired) {
              return null;
            }

            if (_selectedStateCode == null) {
              return 'Select ${widget.stateLabel} first';
            }

            if (value == null || value.trim().isEmpty) {
              return '${widget.cityLabel} is required';
            }

            return null;
          },
        ),
      ],
    );
  }
}
