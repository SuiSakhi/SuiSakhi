import '../models/catalogue_garment_semantics.dart';

/// Governed semantic ground truth for local benchmark fixtures.
class CatalogueFixtureSemanticsRegistry {
  const CatalogueFixtureSemanticsRegistry._();

  static CatalogueGarmentSemantics fixture001Front() {
    return CatalogueGarmentSemantics(
      semanticProfileVersion: '1.0',
      garmentType: CatalogueGarmentType.shirt,
      collarType: CatalogueCollarType.shirtCollar,
      sleeveType: CatalogueSleeveType.bishopSleeve,
      cuffType: CatalogueCuffType.buttonCuff,
      closureType: CatalogueClosureType.fullButtonPlacket,
      hemType: CatalogueHemType.curvedHem,
      silhouetteType: CatalogueSilhouetteType.regularFit,
      constructionFeatures: const {
        CatalogueConstructionFeature.shoulderSeam,
        CatalogueConstructionFeature.frontPlacket,
        CatalogueConstructionFeature.sideSeam,
        CatalogueConstructionFeature.gather,
      },
      source: CatalogueSemanticSource.fixtureGroundTruth,
      reviewStatus: CatalogueSemanticReviewStatus.approved,
    );
  }

  static CatalogueGarmentSemantics fixture001ExpectedBack() {
    return CatalogueGarmentSemantics(
      semanticProfileVersion: '1.0',
      garmentType: CatalogueGarmentType.shirt,
      collarType: CatalogueCollarType.shirtCollar,
      sleeveType: CatalogueSleeveType.bishopSleeve,
      cuffType: CatalogueCuffType.buttonCuff,
      closureType: CatalogueClosureType.none,
      hemType: CatalogueHemType.curvedHem,
      silhouetteType: CatalogueSilhouetteType.regularFit,
      constructionFeatures: const {
        CatalogueConstructionFeature.shoulderSeam,
        CatalogueConstructionFeature.backYoke,
        CatalogueConstructionFeature.sideSeam,
        CatalogueConstructionFeature.gather,
      },
      source: CatalogueSemanticSource.fixtureGroundTruth,
      reviewStatus: CatalogueSemanticReviewStatus.approved,
    );
  }
}
