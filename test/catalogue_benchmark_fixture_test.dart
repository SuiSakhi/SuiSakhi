import 'package:flutter_test/flutter_test.dart';
import 'package:suisakhi/models/catalogue_benchmark_fixture.dart';
import 'package:suisakhi/services/catalogue_benchmark_fixture_registry.dart';
import 'package:suisakhi/services/catalogue_benchmark_fixture_validator.dart';

void main() {
  group('Fixture-001 benchmark manifest', () {
    test('records frozen fixture identity and profiles', () {
      final value = CatalogueBenchmarkFixtureRegistry.fixture001();
      expect(value.fixtureId, 'fixture-001');
      expect(value.fixtureVersion, '1.0');
      expect(value.garmentProfileCode, 'shirtV1');
      expect(value.semanticProfileVersion, '1.0');
    });

    test('records verified dimensions for both assets', () {
      final value = CatalogueBenchmarkFixtureRegistry.fixture001();
      expect(value.frontAsset.width, 668);
      expect(value.frontAsset.height, 658);
      expect(value.expectedBackAsset.width, 668);
      expect(value.expectedBackAsset.height, 658);
    });

    test('records verified SHA-256 checksums', () {
      final value = CatalogueBenchmarkFixtureRegistry.fixture001();
      expect(
        value.frontAsset.sha256,
        '56dc098a749f92ae2f205ee60ba41651f02985c9d243058a2e47cf6815d503a1',
      );
      expect(
        value.expectedBackAsset.sha256,
        'f3c608c656ae83c0125bdd2069350a03e4f26208e4d0701df306a47df9b814f4',
      );
    });

    test('uses lossless PNG assets', () {
      final value = CatalogueBenchmarkFixtureRegistry.fixture001();
      expect(value.frontAsset.isLosslessPng, isTrue);
      expect(value.expectedBackAsset.isLosslessPng, isTrue);
    });

    test('source and reference roles are distinct', () {
      final value = CatalogueBenchmarkFixtureRegistry.fixture001();
      expect(value.frontAsset.role, CatalogueFixtureAssetRole.observedSource);
      expect(
        value.expectedBackAsset.role,
        CatalogueFixtureAssetRole.expectedReference,
      );
    });

    test('fixture is local and immutable', () {
      final value = CatalogueBenchmarkFixtureRegistry.fixture001();
      expect(value.localOnly, isTrue);
      expect(value.immutableBenchmark, isTrue);
    });

    test('training and customer publication are disabled', () {
      final value = CatalogueBenchmarkFixtureRegistry.fixture001();
      expect(value.trainingAllowed, isFalse);
      expect(value.customerPublicationAllowed, isFalse);
    });

    test('serialization is deterministic', () {
      final first = CatalogueBenchmarkFixtureRegistry.fixture001().toMap();
      final second = CatalogueBenchmarkFixtureRegistry.fixture001().toMap();
      expect(first, second);
    });
  });

  group('Fixture-001 validation', () {
    test('ownership review is intentionally required initially', () {
      final result = CatalogueBenchmarkFixtureValidator.validate(
        CatalogueBenchmarkFixtureRegistry.fixture001(),
      );
      expect(result.valid, isFalse);
      expect(
        result.codes,
        contains(CatalogueFixtureValidationCode.ownershipReviewRequired),
      );
    });

    test('SuiSakhi-owned fixture passes validation', () {
      final result = CatalogueBenchmarkFixtureValidator.validate(
        CatalogueBenchmarkFixtureRegistry.fixture001(
          ownershipStatus: CatalogueFixtureOwnershipStatus.suisakhiOwned,
        ),
      );
      expect(result.valid, isTrue);
      expect(result.codes, {CatalogueFixtureValidationCode.valid});
    });

    test('explicitly licensed fixture passes validation', () {
      final result = CatalogueBenchmarkFixtureValidator.validate(
        CatalogueBenchmarkFixtureRegistry.fixture001(
          ownershipStatus: CatalogueFixtureOwnershipStatus.explicitlyLicensed,
        ),
      );
      expect(result.valid, isTrue);
    });

    test('manifest permissions remain immutable', () {
      final permissions = <CatalogueFixtureUsagePermission>{
        CatalogueFixtureUsagePermission.localEvaluation,
      };
      final value = _copy(usagePermissions: permissions);
      permissions.add(CatalogueFixtureUsagePermission.customerPublication);
      expect(value.customerPublicationAllowed, isFalse);
    });

    test('training permission is rejected for initial benchmark', () {
      final result = CatalogueBenchmarkFixtureValidator.validate(
        _copy(
          usagePermissions: const {
            CatalogueFixtureUsagePermission.localEvaluation,
            CatalogueFixtureUsagePermission.modelTraining,
          },
        ),
      );
      expect(
        result.codes,
        contains(CatalogueFixtureValidationCode.unsafeUsagePermission),
      );
    });

    test('customer publication permission is rejected', () {
      final result = CatalogueBenchmarkFixtureValidator.validate(
        _copy(
          usagePermissions: const {
            CatalogueFixtureUsagePermission.localEvaluation,
            CatalogueFixtureUsagePermission.customerPublication,
          },
        ),
      );
      expect(
        result.codes,
        contains(CatalogueFixtureValidationCode.unsafeUsagePermission),
      );
    });

    test('dimension mismatch is rejected', () {
      final source = CatalogueBenchmarkFixtureRegistry.fixture001(
        ownershipStatus: CatalogueFixtureOwnershipStatus.suisakhiOwned,
      );
      final result = CatalogueBenchmarkFixtureValidator.validate(
        _copy(
          frontAsset: CatalogueFixtureAsset(
            assetId: source.frontAsset.assetId,
            relativePath: source.frontAsset.relativePath,
            role: source.frontAsset.role,
            canonicalView: source.frontAsset.canonicalView,
            mimeType: source.frontAsset.mimeType,
            width: 667,
            height: source.frontAsset.height,
            sha256: source.frontAsset.sha256,
          ),
        ),
      );
      expect(
        result.codes,
        contains(CatalogueFixtureValidationCode.dimensionMismatch),
      );
    });

    test('invalid checksum is rejected', () {
      final source = CatalogueBenchmarkFixtureRegistry.fixture001(
        ownershipStatus: CatalogueFixtureOwnershipStatus.suisakhiOwned,
      );
      final result = CatalogueBenchmarkFixtureValidator.validate(
        _copy(
          frontAsset: CatalogueFixtureAsset(
            assetId: source.frontAsset.assetId,
            relativePath: source.frontAsset.relativePath,
            role: source.frontAsset.role,
            canonicalView: source.frontAsset.canonicalView,
            mimeType: source.frontAsset.mimeType,
            width: source.frontAsset.width,
            height: source.frontAsset.height,
            sha256: 'invalid',
          ),
        ),
      );
      expect(
        result.codes,
        contains(CatalogueFixtureValidationCode.invalidChecksum),
      );
    });
  });
}

CatalogueBenchmarkFixtureManifest _copy({
  CatalogueFixtureAsset? frontAsset,
  Set<CatalogueFixtureUsagePermission>? usagePermissions,
}) {
  final source = CatalogueBenchmarkFixtureRegistry.fixture001(
    ownershipStatus: CatalogueFixtureOwnershipStatus.suisakhiOwned,
  );
  return CatalogueBenchmarkFixtureManifest(
    schemaVersion: source.schemaVersion,
    fixtureId: source.fixtureId,
    fixtureVersion: source.fixtureVersion,
    garmentProfileCode: source.garmentProfileCode,
    semanticProfileVersion: source.semanticProfileVersion,
    ownershipStatus: source.ownershipStatus,
    usagePermissions: usagePermissions ?? source.usagePermissions,
    frontAsset: frontAsset ?? source.frontAsset,
    expectedBackAsset: source.expectedBackAsset,
    localOnly: source.localOnly,
    immutableBenchmark: source.immutableBenchmark,
  );
}
