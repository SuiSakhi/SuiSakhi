class CapabilityDefinition {
  const CapabilityDefinition({
    required this.code,
    required this.label,
    required this.partnerCategoryCode,
    required this.groupCode,
    this.description,
    this.displayOrder = 0,
    this.active = true,
    this.requiresVerification = false,
    this.requiresCertification = false,
  });

  final String code;
  final String label;

  /// Examples: tailor, designer, measurement, laundry.
  final String partnerCategoryCode;

  /// Groups capabilities for clear UI presentation.
  final String groupCode;

  final String? description;
  final int displayOrder;
  final bool active;

  /// Some capabilities can be declared by the Partner but must be
  /// verified by Admin before becoming assignment-eligible.
  final bool requiresVerification;

  /// Premium or high-risk capabilities may also require certification.
  final bool requiresCertification;
}

class CapabilityGroupDefinition {
  const CapabilityGroupDefinition({
    required this.code,
    required this.label,
    required this.partnerCategoryCode,
    this.description,
    this.displayOrder = 0,
    this.active = true,
  });

  final String code;
  final String label;
  final String partnerCategoryCode;
  final String? description;
  final int displayOrder;
  final bool active;
}
