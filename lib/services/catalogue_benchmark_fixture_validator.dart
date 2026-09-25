import '../models/catalogue_benchmark_fixture.dart';

enum CatalogueFixtureValidationCode {
  valid,
  identityRequired,
  versionRequired,
  ownershipReviewRequired,
  invalidAssetRole,
  invalidCanonicalView,
  unsupportedFormat,
  invalidDimensions,
  dimensionMismatch,
  invalidChecksum,
  unsafeUsagePermission,
  localOnlyRequired,
  immutableBenchmarkRequired,
}

class CatalogueFixtureValidationResult {
  CatalogueFixtureValidationResult({
    required this.valid,
    required Set<CatalogueFixtureValidationCode> codes,
  }) : codes = Set.unmodifiable(codes);

  final bool valid;
  final Set<CatalogueFixtureValidationCode> codes;
}

class CatalogueBenchmarkFixtureValidator {
  const CatalogueBenchmarkFixtureValidator._();

  static final RegExp _sha256 = RegExp(r'^[a-f0-9]{64}$');

  static CatalogueFixtureValidationResult validate(
    CatalogueBenchmarkFixtureManifest fixture,
  ) {
    final codes = <CatalogueFixtureValidationCode>{};
    if (fixture.fixtureId.trim().isEmpty) {
      codes.add(CatalogueFixtureValidationCode.identityRequired);
    }
    if (fixture.fixtureVersion.trim().isEmpty) {
      codes.add(CatalogueFixtureValidationCode.versionRequired);
    }
    if (fixture.ownershipStatus ==
        CatalogueFixtureOwnershipStatus.ownershipReviewRequired) {
      codes.add(CatalogueFixtureValidationCode.ownershipReviewRequired);
    }
    if (fixture.frontAsset.role != CatalogueFixtureAssetRole.observedSource ||
        fixture.expectedBackAsset.role !=
            CatalogueFixtureAssetRole.expectedReference) {
      codes.add(CatalogueFixtureValidationCode.invalidAssetRole);
    }
    if (fixture.frontAsset.canonicalView.name != 'front' ||
        fixture.expectedBackAsset.canonicalView.name != 'back') {
      codes.add(CatalogueFixtureValidationCode.invalidCanonicalView);
    }
    for (final asset in [fixture.frontAsset, fixture.expectedBackAsset]) {
      if (!asset.isLosslessPng) {
        codes.add(CatalogueFixtureValidationCode.unsupportedFormat);
      }
      if (asset.width < 1 || asset.height < 1) {
        codes.add(CatalogueFixtureValidationCode.invalidDimensions);
      }
      if (!_sha256.hasMatch(asset.sha256)) {
        codes.add(CatalogueFixtureValidationCode.invalidChecksum);
      }
    }
    if (fixture.frontAsset.width != fixture.expectedBackAsset.width ||
        fixture.frontAsset.height != fixture.expectedBackAsset.height) {
      codes.add(CatalogueFixtureValidationCode.dimensionMismatch);
    }
    if (fixture.trainingAllowed || fixture.customerPublicationAllowed) {
      codes.add(CatalogueFixtureValidationCode.unsafeUsagePermission);
    }
    if (!fixture.localOnly) {
      codes.add(CatalogueFixtureValidationCode.localOnlyRequired);
    }
    if (!fixture.immutableBenchmark) {
      codes.add(CatalogueFixtureValidationCode.immutableBenchmarkRequired);
    }
    if (codes.isEmpty) {
      codes.add(CatalogueFixtureValidationCode.valid);
    }
    return CatalogueFixtureValidationResult(
      valid:
          codes.length == 1 &&
          codes.contains(CatalogueFixtureValidationCode.valid),
      codes: codes,
    );
  }
}
