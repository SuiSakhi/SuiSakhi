import 'package:flutter/material.dart';

import '../../models/capability_definition.dart';
import '../../models/partner_capability_selection.dart';
import '../../services/capability_metadata_provider.dart';

class CapabilityMultiSelector extends StatefulWidget {
  const CapabilityMultiSelector({
    required this.metadataProvider,
    required this.partnerCategoryCode,
    required this.onChanged,
    this.initialValue = const PartnerCapabilitySelection(),
    this.enabled = true,
    this.minimumSelectionCount = 1,
    this.sectionTitle = 'Skills & Expertise',
    this.sectionDescription,
    this.showOtherExpertise = true,
    this.otherExpertiseLabel = 'Other Expertise',
    this.otherExpertiseHint = 'Describe expertise not listed above',
    this.spacing = 12,
    super.key,
  });

  final CapabilityMetadataProvider metadataProvider;
  final String partnerCategoryCode;

  final PartnerCapabilitySelection initialValue;
  final ValueChanged<PartnerCapabilitySelection> onChanged;

  final bool enabled;
  final int minimumSelectionCount;

  final String sectionTitle;
  final String? sectionDescription;

  final bool showOtherExpertise;
  final String otherExpertiseLabel;
  final String otherExpertiseHint;

  final double spacing;

  @override
  State<CapabilityMultiSelector> createState() {
    return _CapabilityMultiSelectorState();
  }
}

class _CapabilityMultiSelectorState extends State<CapabilityMultiSelector> {
  final Set<String> _selectedCapabilityCodes = {};

  late final TextEditingController _additionalExpertiseController;

  bool _otherExpertiseSelected = false;

  @override
  void initState() {
    super.initState();

    _additionalExpertiseController = TextEditingController();

    _loadInitialValue(widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant CapabilityMultiSelector oldWidget) {
    super.didUpdateWidget(oldWidget);

    final valueChanged = !_sameSelection(
      oldWidget.initialValue,
      widget.initialValue,
    );

    final categoryChanged =
        oldWidget.partnerCategoryCode != widget.partnerCategoryCode;

    final providerChanged =
        oldWidget.metadataProvider != widget.metadataProvider;

    if (valueChanged || categoryChanged || providerChanged) {
      _loadInitialValue(widget.initialValue);
    }
  }

  @override
  void dispose() {
    _additionalExpertiseController.dispose();
    super.dispose();
  }

  void _loadInitialValue(PartnerCapabilitySelection selection) {
    final validCapabilityCodes = widget.metadataProvider
        .capabilitiesForPartnerCategory(widget.partnerCategoryCode)
        .map((capability) => capability.code)
        .toSet();

    _selectedCapabilityCodes
      ..clear()
      ..addAll(
        selection.normalizedCapabilityCodes.where(
          validCapabilityCodes.contains,
        ),
      );

    final additionalDescriptions = selection.normalizedAdditionalDescriptions;

    _otherExpertiseSelected = additionalDescriptions.isNotEmpty;

    _additionalExpertiseController.text = additionalDescriptions.join('\n');
  }

  PartnerCapabilitySelection get _currentSelection {
    return PartnerCapabilitySelection(
      declaredCapabilityCodes: _selectedCapabilityCodes.toList(growable: false),
      additionalCapabilityDescriptions: _otherExpertiseSelected
          ? _additionalDescriptionsFromText(_additionalExpertiseController.text)
          : const <String>[],
    );
  }

  void _toggleCapability({
    required String capabilityCode,
    required bool selected,
    required FormFieldState<Set<String>> fieldState,
  }) {
    if (!widget.enabled) {
      return;
    }

    setState(() {
      if (selected) {
        _selectedCapabilityCodes.add(capabilityCode);
      } else {
        _selectedCapabilityCodes.remove(capabilityCode);
      }
    });

    fieldState.didChange(Set<String>.from(_selectedCapabilityCodes));

    _emitSelection();
  }

  void _toggleOtherExpertise(bool selected) {
    if (!widget.enabled) {
      return;
    }

    setState(() {
      _otherExpertiseSelected = selected;

      if (!selected) {
        _additionalExpertiseController.clear();
      }
    });

    _emitSelection();
  }

  void _emitSelection() {
    widget.onChanged(_currentSelection);
  }

  List<String> _additionalDescriptionsFromText(String rawValue) {
    final seenValues = <String>{};
    final descriptions = <String>[];

    for (final rawLine in rawValue.split('\n')) {
      for (final value in rawLine.split(',')) {
        final normalizedValue = value.trim();

        if (normalizedValue.isEmpty) {
          continue;
        }

        final comparisonValue = normalizedValue.toLowerCase();

        if (seenValues.add(comparisonValue)) {
          descriptions.add(normalizedValue);
        }
      }
    }

    return descriptions;
  }

  String? _capabilityValidator(Set<String>? selectedValues) {
    if (widget.minimumSelectionCount <= 0) {
      return null;
    }

    final selectedCount = selectedValues?.length ?? 0;

    if (selectedCount < widget.minimumSelectionCount) {
      if (widget.minimumSelectionCount == 1) {
        return 'Select at least one capability';
      }

      return 'Select at least '
          '${widget.minimumSelectionCount} capabilities';
    }

    return null;
  }

  String? _additionalExpertiseValidator(String? value) {
    if (!_otherExpertiseSelected) {
      return null;
    }

    final normalizedValue = value?.trim() ?? '';

    if (normalizedValue.isEmpty) {
      return 'Describe the additional expertise';
    }

    if (normalizedValue.length < 3) {
      return 'Provide a clearer expertise description';
    }

    return null;
  }

  bool _sameSelection(
    PartnerCapabilitySelection first,
    PartnerCapabilitySelection second,
  ) {
    return first.normalizedCapabilityCodes.join('|') ==
            second.normalizedCapabilityCodes.join('|') &&
        first.normalizedAdditionalDescriptions.join('|').toLowerCase() ==
            second.normalizedAdditionalDescriptions.join('|').toLowerCase();
  }

  Widget _buildCapabilityIndicator(CapabilityDefinition capability) {
    final labels = <Widget>[];

    if (capability.requiresCertification) {
      labels.add(
        const Tooltip(
          message: 'Certification required before eligible assignment',
          child: Icon(
            Icons.workspace_premium_outlined,
            size: 18,
            color: Color(0xFF8E44AD),
          ),
        ),
      );
    } else if (capability.requiresVerification) {
      labels.add(
        const Tooltip(
          message: 'Admin verification required before eligible assignment',
          child: Icon(
            Icons.verified_outlined,
            size: 18,
            color: Color(0xFF1976D2),
          ),
        ),
      );
    }

    if (labels.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(mainAxisSize: MainAxisSize.min, children: labels);
  }

  Widget _buildCapabilityGroup({
    required CapabilityGroupDefinition group,
    required List<CapabilityDefinition> capabilities,
    required FormFieldState<Set<String>> fieldState,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          group.label,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (group.description?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 4),
          Text(
            group.description!.trim(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 8),
        for (final capability in capabilities)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _selectedCapabilityCodes.contains(capability.code),
            onChanged: widget.enabled
                ? (selected) {
                    _toggleCapability(
                      capabilityCode: capability.code,
                      selected: selected == true,
                      fieldState: fieldState,
                    );
                  }
                : null,
            title: Row(
              children: [
                Expanded(child: Text(capability.label)),
                _buildCapabilityIndicator(capability),
              ],
            ),
            subtitle: capability.description?.trim().isNotEmpty == true
                ? Text(capability.description!.trim())
                : null,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final groups = widget.metadataProvider.groupsForPartnerCategory(
      widget.partnerCategoryCode,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.sectionTitle.trim().isNotEmpty)
          Text(
            widget.sectionTitle.trim(),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        if (widget.sectionDescription?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 6),
          Text(
            widget.sectionDescription!.trim(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
        SizedBox(height: widget.spacing),
        FormField<Set<String>>(
          initialValue: Set<String>.from(_selectedCapabilityCodes),
          validator: _capabilityValidator,
          builder: (fieldState) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < groups.length; index++) ...[
                  _buildCapabilityGroup(
                    group: groups[index],
                    capabilities: widget.metadataProvider.capabilitiesForGroup(
                      partnerCategoryCode: widget.partnerCategoryCode,
                      groupCode: groups[index].code,
                    ),
                    fieldState: fieldState,
                  ),
                  if (index < groups.length - 1)
                    Divider(height: widget.spacing * 2),
                ],
                if (fieldState.hasError) ...[
                  SizedBox(height: widget.spacing),
                  Text(
                    fieldState.errorText!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
        if (widget.showOtherExpertise) ...[
          SizedBox(height: widget.spacing),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _otherExpertiseSelected,
            onChanged: widget.enabled
                ? (selected) {
                    _toggleOtherExpertise(selected == true);
                  }
                : null,
            title: Text(widget.otherExpertiseLabel),
            subtitle: const Text(
              'Use this only when the expertise is not listed above.',
            ),
          ),
          if (_otherExpertiseSelected) ...[
            SizedBox(height: widget.spacing),
            TextFormField(
              controller: _additionalExpertiseController,
              enabled: widget.enabled,
              minLines: 2,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: widget.otherExpertiseLabel,
                hintText: widget.otherExpertiseHint,
                prefixIcon: const Icon(Icons.add_circle_outline),
                border: const OutlineInputBorder(),
                helperText:
                    'Separate multiple expertise descriptions '
                    'with commas or new lines.',
                alignLabelWithHint: true,
              ),
              validator: _additionalExpertiseValidator,
              onChanged: (_) {
                _emitSelection();
              },
            ),
          ],
        ],
      ],
    );
  }
}
