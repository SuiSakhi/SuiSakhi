/// Governed visual semantics for Designer Catalogue garments.
///
/// These values describe visual design characteristics only. They do not
/// contain body, order, tailoring, or physical measurement information.
enum CatalogueGarmentType {
  blouse,
  shirt,
  kurti,
  kurta,
  dress,
  gown,
  skirt,
  trousers,
  jacket,
  unknown,
}

enum CatalogueCollarType {
  none,
  shirtCollar,
  mandarinCollar,
  peterPanCollar,
  standCollar,
  unknown,
}

enum CatalogueSleeveType {
  sleeveless,
  capSleeve,
  shortSleeve,
  elbowSleeve,
  threeQuarterSleeve,
  fullSleeve,
  puffSleeve,
  bishopSleeve,
  bellSleeve,
  raglanSleeve,
  unknown,
}

enum CatalogueCuffType {
  none,
  plainCuff,
  buttonCuff,
  elasticCuff,
  foldedCuff,
  unknown,
}

enum CatalogueClosureType {
  none,
  fullButtonPlacket,
  halfButtonPlacket,
  hiddenButtonPlacket,
  frontZip,
  backZip,
  sideZip,
  hookAndEye,
  tieClosure,
  pullover,
  unknown,
}

enum CatalogueHemType {
  straightHem,
  curvedHem,
  asymmetricHem,
  highLowHem,
  scallopedHem,
  unknown,
}

enum CatalogueSilhouetteType {
  regularFit,
  relaxedFit,
  fitted,
  straight,
  aLine,
  fitAndFlare,
  flared,
  unknown,
}

enum CatalogueConstructionFeature {
  shoulderSeam,
  frontPlacket,
  backYoke,
  centerBackSeam,
  sideSeam,
  dart,
  pleat,
  gather,
  panel,
  pocket,
  border,
  unknown,
}

enum CatalogueSemanticSource {
  designerDeclared,
  adminDeclared,
  fixtureGroundTruth,
  systemSuggested,
  manuallyCorrected,
}

enum CatalogueSemanticReviewStatus {
  reviewRequired,
  approved,
  rejected,
  changesRequested,
}

/// Versioned visual semantics independent of reconstruction providers.
class CatalogueGarmentSemantics {
  CatalogueGarmentSemantics({
    required this.semanticProfileVersion,
    required this.garmentType,
    required this.collarType,
    required this.sleeveType,
    required this.cuffType,
    required this.closureType,
    required this.hemType,
    required this.silhouetteType,
    required Set<CatalogueConstructionFeature> constructionFeatures,
    required this.source,
    required this.reviewStatus,
  }) : constructionFeatures = Set.unmodifiable(constructionFeatures);

  final String semanticProfileVersion;
  final CatalogueGarmentType garmentType;
  final CatalogueCollarType collarType;
  final CatalogueSleeveType sleeveType;
  final CatalogueCuffType cuffType;
  final CatalogueClosureType closureType;
  final CatalogueHemType hemType;
  final CatalogueSilhouetteType silhouetteType;
  final Set<CatalogueConstructionFeature> constructionFeatures;
  final CatalogueSemanticSource source;
  final CatalogueSemanticReviewStatus reviewStatus;

  bool get usesMeasurements => false;
  bool get customerSpecific => false;
  bool get providerSpecific => false;

  Map<String, dynamic> toMap() => {
    'semanticProfileVersion': semanticProfileVersion,
    'garmentType': garmentType.name,
    'collarType': collarType.name,
    'sleeveType': sleeveType.name,
    'cuffType': cuffType.name,
    'closureType': closureType.name,
    'hemType': hemType.name,
    'silhouetteType': silhouetteType.name,
    'constructionFeatures':
        constructionFeatures.map((item) => item.name).toList()..sort(),
    'source': source.name,
    'reviewStatus': reviewStatus.name,
  };
}
