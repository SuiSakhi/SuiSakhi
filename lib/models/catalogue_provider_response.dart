import 'catalogue_source_view.dart';

enum CatalogueProviderResponseStatus {
  accepted,
  rejected,
  insufficientEvidence,
  manualReviewRequired,
  providerFailure,
}

enum CatalogueProviderFailureCode {
  invalidRequest,
  restrictedOperation,
  unsupportedTarget,
  providerUnavailable,
  unknownFailure,
}

/// Provider-neutral response. C1.4C-2 contains metadata only, never images.
class CatalogueProviderResponse {
  CatalogueProviderResponse({
    required this.providerRequestId,
    required this.status,
    required Set<CatalogueCanonicalView> acceptedTargets,
    required Set<CatalogueCanonicalView> rejectedTargets,
    this.failureCode,
    this.messageCode,
  }) : acceptedTargets = Set.unmodifiable(acceptedTargets),
       rejectedTargets = Set.unmodifiable(rejectedTargets);

  final String providerRequestId;
  final CatalogueProviderResponseStatus status;
  final Set<CatalogueCanonicalView> acceptedTargets;
  final Set<CatalogueCanonicalView> rejectedTargets;
  final CatalogueProviderFailureCode? failureCode;
  final String? messageCode;

  bool get containsGeneratedAssets => false;
  bool get customerVisible => false;
}
