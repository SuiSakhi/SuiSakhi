import 'package:flutter_test/flutter_test.dart';
import 'package:suisakhi/models/catalogue_design_evidence.dart';
import 'package:suisakhi/models/catalogue_provider_manifest.dart';
import 'package:suisakhi/models/catalogue_provider_request.dart';
import 'package:suisakhi/models/catalogue_provider_response.dart';
import 'package:suisakhi/models/catalogue_source_view.dart';
import 'package:suisakhi/models/catalogue_view_proposal.dart';
import 'package:suisakhi/services/catalogue_mock_provider.dart';
import 'package:suisakhi/services/catalogue_provider_request_factory.dart';

void main() {
  group('CatalogueProviderRequestFactory', () {
    test('maps an actionable proposal to a provider manifest', () {
      final request = CatalogueProviderRequestFactory.fromProposal(_proposal());
      expect(request.manifest.schemaVersion, '1.0');
      expect(request.manifest.designId, 'design-1');
      expect(request.manifest.versionId, 'version-1');
      expect(request.manifest.targetViews, [CatalogueCanonicalView.back]);
      expect(
        request.manifest.restrictions,
        CatalogueViewProposalRestriction.values.toSet(),
      );
    });

    test('preserves consistency checks', () {
      final request = CatalogueProviderRequestFactory.fromProposal(_proposal());
      expect(
        request.manifest.consistencyChecks,
        containsAll({
          CatalogueVisualConsistencyDimension.silhouette,
          CatalogueVisualConsistencyDimension.visualProportion,
        }),
      );
    });

    test('rejects a blocked proposal', () {
      expect(
        () => CatalogueProviderRequestFactory.fromProposal(_blockedProposal()),
        throwsStateError,
      );
    });

    test('provider request remains local-only', () {
      final request = CatalogueProviderRequestFactory.fromProposal(_proposal());
      expect(request.networkAllowed, isFalse);
      expect(request.firebaseAllowed, isFalse);
      expect(request.measurementsAllowed, isFalse);
      expect(request.customerPublicationAllowed, isFalse);
    });

    test('manifest serialization is deterministic', () {
      final first = CatalogueProviderRequestFactory.fromProposal(_proposal());
      final second = CatalogueProviderRequestFactory.fromProposal(_proposal());
      expect(first.manifest.toMap(), second.manifest.toMap());
    });
  });

  group('CatalogueMockProviderAdapter', () {
    test('accepts standard review request', () async {
      final response = await const CatalogueMockProviderAdapter().submit(
        CatalogueProviderRequestFactory.fromProposal(
          _proposal(review: CatalogueViewProposalReviewPolicy.standardReview),
        ),
      );
      expect(response.status, CatalogueProviderResponseStatus.accepted);
      expect(response.acceptedTargets, {CatalogueCanonicalView.back});
    });

    test('enhanced review request requires manual review', () async {
      final response = await const CatalogueMockProviderAdapter().submit(
        CatalogueProviderRequestFactory.fromProposal(_proposal()),
      );
      expect(
        response.status,
        CatalogueProviderResponseStatus.manualReviewRequired,
      );
    });

    test('forced manual review is deterministic', () async {
      final response =
          await const CatalogueMockProviderAdapter(
            forceManualReview: true,
          ).submit(
            CatalogueProviderRequestFactory.fromProposal(
              _proposal(
                review: CatalogueViewProposalReviewPolicy.focusedReview,
              ),
            ),
          );
      expect(
        response.status,
        CatalogueProviderResponseStatus.manualReviewRequired,
      );
    });

    test('forced provider failure maps failure code', () async {
      final response = await const CatalogueMockProviderAdapter(
        forceFailure: true,
      ).submit(CatalogueProviderRequestFactory.fromProposal(_proposal()));
      expect(response.status, CatalogueProviderResponseStatus.providerFailure);
      expect(
        response.failureCode,
        CatalogueProviderFailureCode.providerUnavailable,
      );
    });

    test('invalid contract version is rejected', () async {
      final valid = CatalogueProviderRequestFactory.fromProposal(_proposal());
      final invalid = CatalogueProviderRequest(
        adapterContractVersion: '9.9',
        providerRequestId: valid.providerRequestId,
        manifest: valid.manifest,
      );
      final response = await const CatalogueMockProviderAdapter().submit(
        invalid,
      );
      expect(response.status, CatalogueProviderResponseStatus.rejected);
      expect(response.failureCode, CatalogueProviderFailureCode.invalidRequest);
    });

    test('empty target list is rejected', () async {
      final request = _requestWith(
        targetViews: const [],
        restrictions: CatalogueViewProposalRestriction.values.toSet(),
      );
      final response = await const CatalogueMockProviderAdapter().submit(
        request,
      );
      expect(response.status, CatalogueProviderResponseStatus.rejected);
    });

    test('incomplete restrictions are rejected', () async {
      final request = _requestWith(
        targetViews: const [CatalogueCanonicalView.back],
        restrictions: const {CatalogueViewProposalRestriction.noMeasurements},
      );
      final response = await const CatalogueMockProviderAdapter().submit(
        request,
      );
      expect(
        response.failureCode,
        CatalogueProviderFailureCode.restrictedOperation,
      );
    });

    test('response never contains generated assets', () async {
      final response = await const CatalogueMockProviderAdapter().submit(
        CatalogueProviderRequestFactory.fromProposal(_proposal()),
      );
      expect(response.containsGeneratedAssets, isFalse);
      expect(response.customerVisible, isFalse);
    });

    test('adapter identity and contract are stable', () {
      const adapter = CatalogueMockProviderAdapter();
      expect(adapter.adapterId, 'suisakhi-mock-provider');
      expect(adapter.contractVersion, '1.0');
    });
  });

  group('provider response contract', () {
    test('accepted and rejected targets are immutable', () {
      final accepted = <CatalogueCanonicalView>{CatalogueCanonicalView.back};
      final response = CatalogueProviderResponse(
        providerRequestId: 'request-1',
        status: CatalogueProviderResponseStatus.accepted,
        acceptedTargets: accepted,
        rejectedTargets: const {},
      );
      accepted.add(CatalogueCanonicalView.leftSide);
      expect(response.acceptedTargets, {CatalogueCanonicalView.back});
    });

    test('all response statuses are representable', () {
      expect(CatalogueProviderResponseStatus.values, hasLength(5));
    });

    test('all failure codes are representable', () {
      expect(CatalogueProviderFailureCode.values, hasLength(5));
    });
  });
}

CatalogueViewProposalRequest _proposal({
  CatalogueViewProposalReviewPolicy review =
      CatalogueViewProposalReviewPolicy.enhancedReview,
}) {
  return CatalogueViewProposalRequest(
    requestId: 'view-proposal-v1|design-1|version-1|front',
    designId: 'design-1',
    versionId: 'version-1',
    sourceViewIds: const ['front'],
    targets: [
      CatalogueViewProposalTarget(
        targetView: CatalogueCanonicalView.back,
        evidenceClass: CatalogueViewProposalEvidenceClass.inferred,
        observedSourceViews: const {CatalogueCanonicalView.front},
        consistencyChecks: const {
          CatalogueVisualConsistencyDimension.silhouette,
          CatalogueVisualConsistencyDimension.visualProportion,
        },
      ),
    ],
    restrictions: CatalogueViewProposalRestriction.values.toSet(),
    reviewPolicy: review,
    status: CatalogueViewProposalStatus.planned,
  );
}

CatalogueViewProposalRequest _blockedProposal() {
  return CatalogueViewProposalRequest(
    requestId: 'blocked',
    designId: 'design-1',
    versionId: 'version-1',
    sourceViewIds: const [],
    targets: const [],
    restrictions: CatalogueViewProposalRestriction.values.toSet(),
    reviewPolicy: CatalogueViewProposalReviewPolicy.enhancedReview,
    status: CatalogueViewProposalStatus.blocked,
    blockReason: CatalogueViewProposalBlockReason.insufficientEvidence,
  );
}

CatalogueProviderRequest _requestWith({
  required List<CatalogueCanonicalView> targetViews,
  required Set<CatalogueViewProposalRestriction> restrictions,
}) {
  return CatalogueProviderRequest(
    adapterContractVersion: '1.0',
    providerRequestId: 'provider-request-1',
    manifest: CatalogueProviderManifest(
      schemaVersion: '1.0',
      requestId: 'proposal-1',
      designId: 'design-1',
      versionId: 'version-1',
      sourceViewIds: const ['front'],
      targetViews: targetViews,
      restrictions: restrictions,
      consistencyChecks: const {CatalogueVisualConsistencyDimension.silhouette},
      reviewPolicy: CatalogueViewProposalReviewPolicy.standardReview,
    ),
  );
}
