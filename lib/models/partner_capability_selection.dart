class PartnerCapabilitySelection {
  const PartnerCapabilitySelection({
    this.declaredCapabilityCodes = const <String>[],
    this.additionalCapabilityDescriptions = const <String>[],
  });

  final List<String> declaredCapabilityCodes;
  final List<String> additionalCapabilityDescriptions;

  bool get hasDeclaredCapabilities {
    return normalizedCapabilityCodes.isNotEmpty;
  }

  bool get hasAdditionalCapabilities {
    return normalizedAdditionalDescriptions.isNotEmpty;
  }

  List<String> get normalizedCapabilityCodes {
    final values = declaredCapabilityCodes
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);

    values.sort();

    return values;
  }

  List<String> get normalizedAdditionalDescriptions {
    final seenValues = <String>{};
    final normalizedValues = <String>[];

    for (final value in additionalCapabilityDescriptions) {
      final normalizedValue = value.trim();

      if (normalizedValue.isEmpty) {
        continue;
      }

      final comparisonValue = normalizedValue.toLowerCase();

      if (seenValues.add(comparisonValue)) {
        normalizedValues.add(normalizedValue);
      }
    }

    return normalizedValues;
  }

  PartnerCapabilitySelection copyWith({
    List<String>? declaredCapabilityCodes,
    List<String>? additionalCapabilityDescriptions,
  }) {
    return PartnerCapabilitySelection(
      declaredCapabilityCodes:
          declaredCapabilityCodes ?? this.declaredCapabilityCodes,
      additionalCapabilityDescriptions:
          additionalCapabilityDescriptions ??
          this.additionalCapabilityDescriptions,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'declaredCapabilityCodes': normalizedCapabilityCodes,
      'additionalCapabilityDescriptions': normalizedAdditionalDescriptions,
    };
  }

  factory PartnerCapabilitySelection.fromMap(Map<String, dynamic> data) {
    return PartnerCapabilitySelection(
      declaredCapabilityCodes: _stringListFromValue(
        data['declaredCapabilityCodes'],
      ),
      additionalCapabilityDescriptions: _stringListFromValue(
        data['additionalCapabilityDescriptions'],
      ),
    );
  }

  static List<String> _stringListFromValue(Object? value) {
    if (value is! Iterable) {
      return const <String>[];
    }

    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
}
