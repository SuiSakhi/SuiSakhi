enum FabricBehavior {
  breathable,
  flowy,
  structured,
  heavy,
  stretch,
  sheer,
  delicate,
  other,
}

enum ShrinkageRisk {
  none,
  low,
  medium,
  high,
}

enum FabricWeight {
  light,
  medium,
  heavy,
}

class FabricMetadata {
  const FabricMetadata({
    required this.fabricName,
    required this.behavior,
    required this.weight,
    required this.shrinkageRisk,
    required this.stretchable,
    required this.liningRecommended,
    required this.preWashRecommended,
    required this.easeMultiplier,
    required this.fabricAllowanceMultiplier,
    required this.complexityMultiplier,
    required this.notes,
  });

  final String fabricName;

  /// Overall fabric behavior:
  /// breathable, flowy, structured, heavy, stretch, sheer, delicate, etc.
  final FabricBehavior behavior;

  /// Light / medium / heavy fabric classification.
  final FabricWeight weight;

  /// Shrinkage possibility after wash or finishing.
  final ShrinkageRisk shrinkageRisk;

  /// Whether fabric has stretch behavior.
  final bool stretchable;

  /// Whether lining / astar is generally recommended.
  final bool liningRecommended;

  /// Whether pre-wash is recommended before cutting/stitching.
  final bool preWashRecommended;

  /// Adjusts garment ease based on fabric behavior.
  ///
  /// Example:
  /// Cotton = 1.03
  /// Stretch fabric = 0.95
  /// Heavy fabric = 1.05
  final double easeMultiplier;

  /// Adjusts future fabric estimation.
  ///
  /// Example:
  /// Net / Tulle / heavy bridal fabric may need more allowance.
  final double fabricAllowanceMultiplier;

  /// Adjusts future price/effort estimation.
  final double complexityMultiplier;

  /// Customer/tailor friendly guidance notes.
  final List<String> notes;
}
