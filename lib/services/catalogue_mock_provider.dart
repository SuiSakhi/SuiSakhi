import '../models/catalogue_provider_request.dart';
import '../models/catalogue_provider_response.dart';
import '../models/catalogue_view_proposal.dart';
import 'catalogue_provider_adapter.dart';

/// Deterministic local adapter used only for contract validation.
class CatalogueMockProviderAdapter implements CatalogueProviderAdapter {
  const CatalogueMockProviderAdapter({
    this.forceManualReview = false,
    this.forceFailure = false,
  });

  final bool forceManualReview;
  final bool forceFailure;

  @override
  String get adapterId => 'suisakhi-mock-provider';

  @override
  String get contractVersion => '1.0';

  @override
  Future<CatalogueProviderResponse> submit(
    CatalogueProviderRequest request,
  ) async {
    if (request.adapterContractVersion != contractVersion ||
        request.providerRequestId.trim().isEmpty ||
        request.manifest.requestId.trim().isEmpty ||
        request.manifest.targetViews.isEmpty) {
      return CatalogueProviderResponse(
        providerRequestId: request.providerRequestId,
        status: CatalogueProviderResponseStatus.rejected,
        acceptedTargets: const {},
        rejectedTargets: request.manifest.targetViews.toSet(),
        failureCode: CatalogueProviderFailureCode.invalidRequest,
        messageCode: 'PROVIDER_REQUEST_INVALID',
      );
    }

    final required = CatalogueViewProposalRestriction.values.toSet();
    if (!request.manifest.restrictions.containsAll(required)) {
      return CatalogueProviderResponse(
        providerRequestId: request.providerRequestId,
        status: CatalogueProviderResponseStatus.rejected,
        acceptedTargets: const {},
        rejectedTargets: request.manifest.targetViews.toSet(),
        failureCode: CatalogueProviderFailureCode.restrictedOperation,
        messageCode: 'PROVIDER_RESTRICTIONS_INCOMPLETE',
      );
    }

    if (forceFailure) {
      return CatalogueProviderResponse(
        providerRequestId: request.providerRequestId,
        status: CatalogueProviderResponseStatus.providerFailure,
        acceptedTargets: const {},
        rejectedTargets: request.manifest.targetViews.toSet(),
        failureCode: CatalogueProviderFailureCode.providerUnavailable,
        messageCode: 'PROVIDER_MOCK_FAILURE',
      );
    }

    if (forceManualReview ||
        request.manifest.reviewPolicy ==
            CatalogueViewProposalReviewPolicy.enhancedReview) {
      return CatalogueProviderResponse(
        providerRequestId: request.providerRequestId,
        status: CatalogueProviderResponseStatus.manualReviewRequired,
        acceptedTargets: request.manifest.targetViews.toSet(),
        rejectedTargets: const {},
        messageCode: 'PROVIDER_MANUAL_REVIEW_REQUIRED',
      );
    }

    return CatalogueProviderResponse(
      providerRequestId: request.providerRequestId,
      status: CatalogueProviderResponseStatus.accepted,
      acceptedTargets: request.manifest.targetViews.toSet(),
      rejectedTargets: const {},
      messageCode: 'PROVIDER_REQUEST_ACCEPTED',
    );
  }
}
