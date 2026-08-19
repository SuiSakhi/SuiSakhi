enum DesignSilhouette {
  straight,
  aLine,
  anarkali,
  fitAndFlare,
  gathered,
  layered,
  umbrella,
  princessCut,
  other,
}

enum DesignLengthType {
  short,
  kneeLength,
  calfLength,
  ankleLength,
  floorLength,
  other,
}

enum DesignSleeveType {
  sleeveless,
  cap,
  half,
  threeQuarter,
  full,
  puff,
  other,
}

enum DesignNeckType {
  round,
  vNeck,
  boat,
  square,
  keyhole,
  collar,
  other,
}

enum DesignComplexity {
  low,
  medium,
  high,
}

class DesignMetadata {
  const DesignMetadata({
    required this.dressType,
    required this.silhouette,
    required this.lengthType,
    required this.sleeveType,
    required this.neckType,
    required this.liningRequired,
    required this.complexity,
    this.recommendedFabrics = const [],
  });

  final String dressType;

  final DesignSilhouette silhouette;
  final DesignLengthType lengthType;
  final DesignSleeveType sleeveType;
  final DesignNeckType neckType;

  final bool liningRequired;

  final DesignComplexity complexity;

  final List<String> recommendedFabrics;
}
