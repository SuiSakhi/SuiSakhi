import 'catalogue_source_view.dart';

enum CatalogueFixtureAssetRole { observedSource, expectedReference }

enum CatalogueFixtureOwnershipStatus {
  suisakhiOwned,
  explicitlyLicensed,
  ownershipReviewRequired,
}

enum CatalogueFixtureUsagePermission {
  localEvaluation,
  automatedTesting,
  modelTraining,
  customerPublication,
}

class CatalogueFixtureAsset {
  const CatalogueFixtureAsset({
    required this.assetId,
    required this.relativePath,
    required this.role,
    required this.canonicalView,
    required this.mimeType,
    required this.width,
    required this.height,
    required this.sha256,
  });

  final String assetId;
  final String relativePath;
  final CatalogueFixtureAssetRole role;
  final CatalogueCanonicalView canonicalView;
  final String mimeType;
  final int width;
  final int height;
  final String sha256;

  bool get isLosslessPng => mimeType == 'image/png';
}

class CatalogueBenchmarkFixtureManifest {
  CatalogueBenchmarkFixtureManifest({
    required this.schemaVersion,
    required this.fixtureId,
    required this.fixtureVersion,
    required this.garmentProfileCode,
    required this.semanticProfileVersion,
    required this.ownershipStatus,
    required Set<CatalogueFixtureUsagePermission> usagePermissions,
    required this.frontAsset,
    required this.expectedBackAsset,
    required this.localOnly,
    required this.immutableBenchmark,
  }) : usagePermissions = Set.unmodifiable(usagePermissions);

  final String schemaVersion;
  final String fixtureId;
  final String fixtureVersion;
  final String garmentProfileCode;
  final String semanticProfileVersion;
  final CatalogueFixtureOwnershipStatus ownershipStatus;
  final Set<CatalogueFixtureUsagePermission> usagePermissions;
  final CatalogueFixtureAsset frontAsset;
  final CatalogueFixtureAsset expectedBackAsset;
  final bool localOnly;
  final bool immutableBenchmark;

  bool get trainingAllowed =>
      usagePermissions.contains(CatalogueFixtureUsagePermission.modelTraining);

  bool get customerPublicationAllowed => usagePermissions.contains(
    CatalogueFixtureUsagePermission.customerPublication,
  );

  Map<String, dynamic> toMap() => {
    'schemaVersion': schemaVersion,
    'fixtureId': fixtureId,
    'fixtureVersion': fixtureVersion,
    'garmentProfileCode': garmentProfileCode,
    'semanticProfileVersion': semanticProfileVersion,
    'ownershipStatus': ownershipStatus.name,
    'usagePermissions': usagePermissions.map((item) => item.name).toList()
      ..sort(),
    'frontAsset': _assetMap(frontAsset),
    'expectedBackAsset': _assetMap(expectedBackAsset),
    'localOnly': localOnly,
    'immutableBenchmark': immutableBenchmark,
  };

  static Map<String, dynamic> _assetMap(CatalogueFixtureAsset asset) => {
    'assetId': asset.assetId,
    'relativePath': asset.relativePath,
    'role': asset.role.name,
    'canonicalView': asset.canonicalView.name,
    'mimeType': asset.mimeType,
    'width': asset.width,
    'height': asset.height,
    'sha256': asset.sha256,
  };
}
