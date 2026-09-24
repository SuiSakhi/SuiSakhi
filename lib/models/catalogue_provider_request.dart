import 'catalogue_provider_manifest.dart';

/// Provider-independent request envelope.
class CatalogueProviderRequest {
  const CatalogueProviderRequest({
    required this.adapterContractVersion,
    required this.providerRequestId,
    required this.manifest,
  });

  final String adapterContractVersion;
  final String providerRequestId;
  final CatalogueProviderManifest manifest;

  bool get networkAllowed => false;
  bool get firebaseAllowed => false;
  bool get measurementsAllowed => false;
  bool get customerPublicationAllowed => false;
}
