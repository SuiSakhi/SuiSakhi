class PriceEstimate {
  const PriceEstimate({
    required this.dressType,
    required this.currencyCode,
    required this.minimumAmount,
    required this.maximumAmount,
    required this.formulaVersion,
    required this.confidence,
    required this.notes,
    this.baseStitchingAmount,
    this.customizationAmount = 0,
  });

  final String dressType;

  /// ISO-style currency code used by the estimate.
  /// Phase-1 default: INR.
  final String currencyCode;

  /// Lower end of the estimated stitching price range.
  final double minimumAmount;

  /// Upper end of the estimated stitching price range.
  final double maximumAmount;

  /// Baseline stitching amount before metadata adjustments.
  final double? baseStitchingAmount;

  /// Reserved for future Dress Customization V2 adjustments.
  ///
  /// Examples:
  /// neck style
  /// sleeve style
  /// back design
  /// lining / astar
  /// alteration margin
  /// pockets
  /// padding
  /// embroidery
  final double customizationAmount;

  /// Price formula version used for calculation.
  final String formulaVersion;

  /// Expected values:
  /// low
  /// medium
  /// high
  final String confidence;

  /// Customer-friendly explanation of the estimate.
  final List<String> notes;
}
