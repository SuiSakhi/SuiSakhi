class DressCustomizationEstimate {
  const DressCustomizationEstimate({
    required this.additionalFabricMeters,
    required this.additionalStitchingAmount,
    required this.notes,
  });

  /// Additional material required because of sleeve style,
  /// alteration margin, lining / astar, or other customization.
  final double additionalFabricMeters;

  /// Additional stitching/service amount caused by structured customization.
  final double additionalStitchingAmount;

  /// Customer-friendly explanation of customization impact.
  final List<String> notes;
}
