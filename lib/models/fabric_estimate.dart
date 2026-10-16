class FabricEstimate {
  const FabricEstimate({
    required this.dressType,
    required this.fabricName,
    required this.estimatedMeters,
    required this.formulaVersion,
    required this.confidence,
    required this.notes,
    this.fabricWidthCm,
    this.allowancePercent = 18,
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
  final double? fabricWidthCm;
  final int allowancePercent;

  Map<String, dynamic> toMap() => {
    'dressType': dressType,
    'fabricName': fabricName,
    'estimatedMeters': estimatedMeters,
    'formulaVersion': formulaVersion,
    'confidence': confidence,
    'notes': notes,
    if (fabricWidthCm != null) 'fabricWidthCm': fabricWidthCm,
    'allowancePercent': allowancePercent,
  };
}
