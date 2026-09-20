class PartnerWorkspaceDataFormatter {
  PartnerWorkspaceDataFormatter._();

  static const Set<String> _hiddenKeys = {
    'createdAt',
    'updatedAt',
    'approvedByUid',
    'reviewedByUid',
    'createdByUid',
    'onboardingUpdatedByUid',
  };

  static String labelFor(String key) {
    final normalized = key
        .replaceAllMapped(
          RegExp(r'([a-z0-9])([A-Z])'),
          (match) => '${match.group(1)} ${match.group(2)}',
        )
        .replaceAll('_', ' ')
        .replaceAll('.', ' ')
        .trim();
    if (normalized.isEmpty) return 'Details';
    return normalized
        .split(RegExp(r'\s+'))
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }

  static String valueFor(Object? value) {
    if (value == null) return 'Not available';
    if (value is bool) return value ? 'Yes' : 'No';
    if (value is num) return value.toString();
    if (value is List) {
      if (value.isEmpty) return 'Not available';
      return value.map(valueFor).join(', ');
    }
    final text = value.toString().trim();
    return text.isEmpty ? 'Not available' : text;
  }

  static List<PartnerWorkspaceDataField> flatten(
    Map<String, dynamic> data, {
    String path = '',
    bool includeAddressFields = true,
  }) {
    final result = <PartnerWorkspaceDataField>[];
    final keys = data.keys.toList()..sort();
    for (final key in keys) {
      if (_hiddenKeys.contains(key)) continue;
      final value = data[key];
      final currentPath = path.isEmpty ? key : '$path.$key';
      if (!includeAddressFields && _isAddressPath(currentPath)) continue;
      if (value is Map) {
        result.addAll(
          flatten(
            Map<String, dynamic>.from(value),
            path: currentPath,
            includeAddressFields: includeAddressFields,
          ),
        );
      } else if (value is List && value.any((item) => item is Map)) {
        for (var index = 0; index < value.length; index++) {
          final item = value[index];
          if (item is Map) {
            result.addAll(
              flatten(
                Map<String, dynamic>.from(item),
                path: '$currentPath.${index + 1}',
                includeAddressFields: includeAddressFields,
              ),
            );
          }
        }
      } else {
        result.add(
          PartnerWorkspaceDataField(
            path: currentPath,
            label: labelFor(key),
            section: _sectionFor(currentPath),
            value: valueFor(value),
          ),
        );
      }
    }
    return result;
  }

  static List<PartnerWorkspaceDataField> addressFields(
    Map<String, dynamic> data,
  ) {
    return flatten(data).where((field) => _isAddressPath(field.path)).toList();
  }

  static bool _isAddressPath(String path) {
    final value = path.toLowerCase();
    return value.contains('address') ||
        value.contains('locality') ||
        value.contains('landmark') ||
        value.contains('pincode') ||
        value.contains('postal') ||
        value.contains('city') ||
        value.contains('state') ||
        value.contains('servicearea') ||
        value.contains('service_area') ||
        value.contains('pickup') ||
        value.contains('workshopdetails');
  }

  static String _sectionFor(String path) {
    final parts = path.split('.');
    if (parts.length <= 1) return 'Approved Business Details';
    return labelFor(parts[parts.length - 2]);
  }
}

class PartnerWorkspaceDataField {
  const PartnerWorkspaceDataField({
    required this.path,
    required this.label,
    required this.section,
    required this.value,
  });

  final String path;
  final String label;
  final String section;
  final String value;
}
