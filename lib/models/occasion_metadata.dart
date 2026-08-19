class OccasionMetadata {
  const OccasionMetadata({
    required this.occasionId,
    required this.displayName,
    required this.easeMultiplier,
    required this.fabricAllowanceMultiplier,
    required this.complexityMultiplier,
    required this.liningRecommended,
    required this.tailorReviewRecommended,
    required this.notes,
  });

  final String occasionId;
  final String displayName;

  /// Multiplies base fit ease.
  ///
  /// Example:
  /// Daily Wear = 1.00
  /// Wedding Guest = 1.08
  /// Bridal / Heavy Occasion = 1.15
  final double easeMultiplier;

  /// Multiplies future fabric estimation.
  ///
  /// Example:
  /// Daily Wear = 1.00
  /// Wedding Guest = 1.10
  /// Bridal / Heavy Occasion = 1.25
  final double fabricAllowanceMultiplier;

  /// Multiplies future price/effort estimation.
  final double complexityMultiplier;

  /// Whether lining / astar is generally recommended.
  final bool liningRecommended;

  /// Whether tailor review should be strongly recommended.
  final bool tailorReviewRecommended;

  /// Customer-friendly explanation.
  final List<String> notes;
}
