class FabricEstimate {
  const FabricEstimate({
    required this.dressType,
    required this.fabricName,
    required this.estimatedMeters,
    required this.formulaVersion,
    required this.confidence,
    required this.notes,
  });

  final String dressType;
  final String fabricName;

  /// Estimated fabric requirement in meters.
  final double estimatedMeters;

  /// Formula version used for fabric calculation.
  final String formulaVersion;

  /// Example values:
  /// low
  /// medium
  /// high
  final String confidence;

  /// Customer/tailor friendly notes explaining the estimate.
  final List<String> notes;
}
