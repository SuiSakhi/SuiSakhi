import '../models/catalogue_design_evidence.dart';
import '../models/catalogue_reconstruction_foundation.dart';
import '../models/catalogue_source_view.dart';

/// Local fixture registry for controlled reconstruction experiments.
class CatalogueReconstructionFixtureRegistry {
  const CatalogueReconstructionFixtureRegistry._();

  static CatalogueReconstructionFixture simpleBlouseFrontV1({
    String sourceAssetPath =
        'test/fixtures/catalogue_reconstruction/simple_blouse_front_v1.png',
  }) {
    return CatalogueReconstructionFixture(
      fixtureId: 'simple-blouse-front-v1',
      title: 'Simple Monochrome Blouse Front V1',
      garmentProfileCode: 'blouseV1',
      sourceView: CatalogueCanonicalView.front,
      sourceAssetPath: sourceAssetPath,
      complexity: CatalogueFixtureComplexity.simpleSinglePiece,
      allowedTargets: const {
        CatalogueCanonicalView.back,
        CatalogueCanonicalView.leftSide,
        CatalogueCanonicalView.rightSide,
      },
      evaluationDimensions: const {
        CatalogueVisualConsistencyDimension.neckline,
        CatalogueVisualConsistencyDimension.sleeveType,
        CatalogueVisualConsistencyDimension.silhouette,
        CatalogueVisualConsistencyDimension.visualProportion,
        CatalogueVisualConsistencyDimension.garmentPieces,
        CatalogueVisualConsistencyDimension.majorBorder,
        CatalogueVisualConsistencyDimension.majorEmbellishment,
      },
      monochrome: true,
      localOnly: true,
    );
  }

  static void validate(CatalogueReconstructionFixture fixture) {
    if (fixture.fixtureId.trim().isEmpty) {
      throw ArgumentError('Fixture ID is required.');
    }
    if (fixture.sourceAssetPath.trim().isEmpty) {
      throw ArgumentError('Fixture source asset path is required.');
    }
    if (!fixture.monochrome) {
      throw StateError('C1.4E-1 accepts monochrome fixtures only.');
    }
    if (!fixture.localOnly) {
      throw StateError('C1.4E-1 fixtures must remain local-only.');
    }
    if (fixture.allowedTargets.isEmpty) {
      throw StateError('At least one target view is required.');
    }
    if (fixture.allowedTargets.contains(fixture.sourceView)) {
      throw StateError('Source view cannot also be an output target.');
    }
  }
}
