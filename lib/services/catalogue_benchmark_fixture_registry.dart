import '../models/catalogue_benchmark_fixture.dart';
import '../models/catalogue_source_view.dart';

class CatalogueBenchmarkFixtureRegistry {
  const CatalogueBenchmarkFixtureRegistry._();

  static CatalogueBenchmarkFixtureManifest fixture001({
    CatalogueFixtureOwnershipStatus ownershipStatus =
        CatalogueFixtureOwnershipStatus.suisakhiOwned,
  }) {
    return CatalogueBenchmarkFixtureManifest(
      schemaVersion: '1.0',
      fixtureId: 'fixture-001',
      fixtureVersion: '1.0',
      garmentProfileCode: 'shirtV1',
      semanticProfileVersion: '1.0',
      ownershipStatus: ownershipStatus,
      usagePermissions: const {
        CatalogueFixtureUsagePermission.localEvaluation,
        CatalogueFixtureUsagePermission.automatedTesting,
      },
      frontAsset: const CatalogueFixtureAsset(
        assetId: 'fixture-001-front',
        relativePath:
            'test/fixtures/catalogue_reconstruction/fixture_001/front.png',
        role: CatalogueFixtureAssetRole.observedSource,
        canonicalView: CatalogueCanonicalView.front,
        mimeType: 'image/png',
        width: 668,
        height: 658,
        sha256:
            '56dc098a749f92ae2f205ee60ba41651f02985c9d243058a2e47cf6815d503a1',
      ),
      expectedBackAsset: const CatalogueFixtureAsset(
        assetId: 'fixture-001-expected-back',
        relativePath:
            'test/fixtures/catalogue_reconstruction/fixture_001/expected_back.png',
        role: CatalogueFixtureAssetRole.expectedReference,
        canonicalView: CatalogueCanonicalView.back,
        mimeType: 'image/png',
        width: 668,
        height: 658,
        sha256:
            'f3c608c656ae83c0125bdd2069350a03e4f26208e4d0701df306a47df9b814f4',
      ),
      localOnly: true,
      immutableBenchmark: true,
    );
  }
}
