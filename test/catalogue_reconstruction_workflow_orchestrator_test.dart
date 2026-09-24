import 'package:suisakhi/models/catalogue_design_evidence.dart';
import 'package:suisakhi/models/catalogue_design_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suisakhi/models/catalogue_provider_request.dart';
import 'package:suisakhi/models/catalogue_provider_response.dart';
import 'package:suisakhi/models/catalogue_reconstruction_workflow.dart';
import 'package:suisakhi/models/catalogue_source_view.dart';
import 'package:suisakhi/models/catalogue_source_view_classification.dart';
import 'package:suisakhi/services/catalogue_mock_provider.dart';
import 'package:suisakhi/services/catalogue_provider_adapter.dart';
import 'package:suisakhi/services/catalogue_reconstruction_workflow_orchestrator.dart';

void main() {
  group('CatalogueReconstructionWorkflowOrchestrator', () {
    test('front-only flow reaches manual review', () async {
      final result = await _run(
        sources: [_source('front', canonical: CatalogueCanonicalView.front)],
      );
      expect(
        result.status,
        CatalogueReconstructionWorkflowStatus.manualReviewRequired,
      );
      expect(result.providerCalled, isTrue);
      expect(result.acceptedTargets, {
        CatalogueCanonicalView.back,
        CatalogueCanonicalView.leftSide,
        CatalogueCanonicalView.rightSide,
      });
    });

    test('front and back flow is accepted by mock provider', () async {
      final result = await _run(
        sources: [
          _source('front', canonical: CatalogueCanonicalView.front),
          _source('back', canonical: CatalogueCanonicalView.back, order: 2),
        ],
      );
      expect(
        result.status,
        CatalogueReconstructionWorkflowStatus.providerAccepted,
      );
      expect(result.acceptedTargets, {
        CatalogueCanonicalView.leftSide,
        CatalogueCanonicalView.rightSide,
      });
    });

    test('front back left-side flow proposes right side only', () async {
      final result = await _run(
        sources: [
          _source('front', canonical: CatalogueCanonicalView.front),
          _source('back', canonical: CatalogueCanonicalView.back, order: 2),
          _source('left', canonical: CatalogueCanonicalView.leftSide, order: 3),
        ],
      );
      expect(result.acceptedTargets, {CatalogueCanonicalView.rightSide});
    });

    test('complete canonical set skips provider', () async {
      final result = await _run(
        sources: [
          _source('front', canonical: CatalogueCanonicalView.front),
          _source('back', canonical: CatalogueCanonicalView.back, order: 2),
          _source('left', canonical: CatalogueCanonicalView.leftSide, order: 3),
          _source(
            'right',
            canonical: CatalogueCanonicalView.rightSide,
            order: 4,
          ),
        ],
      );
      expect(
        result.status,
        CatalogueReconstructionWorkflowStatus.noProposalRequired,
      );
      expect(result.providerCalled, isFalse);
    });

    test('detail-only flow is blocked', () async {
      final result = await _run(sources: [_source('detail', detail: true)]);
      expect(result.status, CatalogueReconstructionWorkflowStatus.blocked);
      expect(result.providerCalled, isFalse);
    });

    test('unclassified single view is blocked', () async {
      final result = await _run(sources: [_source('single')]);
      expect(result.status, CatalogueReconstructionWorkflowStatus.blocked);
    });

    test('combined view is blocked pending extraction', () async {
      final result = await _run(sources: [_source('combined', combined: true)]);
      expect(result.status, CatalogueReconstructionWorkflowStatus.blocked);
    });

    test('provider failure maps workflow failure', () async {
      final result = await _run(
        adapter: const CatalogueMockProviderAdapter(forceFailure: true),
        sources: [_source('front', canonical: CatalogueCanonicalView.front)],
      );
      expect(
        result.status,
        CatalogueReconstructionWorkflowStatus.providerFailed,
      );
    });

    test('provider rejection maps workflow rejection', () async {
      final result = await _run(
        adapter: const _RejectingAdapter(),
        sources: [_source('front', canonical: CatalogueCanonicalView.front)],
      );
      expect(
        result.status,
        CatalogueReconstructionWorkflowStatus.providerRejected,
      );
    });

    test('audit sequence is ordered and starts at one', () async {
      final result = await _run(
        sources: [_source('front', canonical: CatalogueCanonicalView.front)],
      );
      expect(
        result.auditEvents.map((item) => item.sequence).toList(),
        List.generate(result.auditEvents.length, (index) => index + 1),
      );
      expect(
        result.auditEvents.first.type,
        CatalogueReconstructionAuditEventType.workflowStarted,
      );
      expect(
        result.auditEvents.last.type,
        CatalogueReconstructionAuditEventType.workflowCompleted,
      );
    });

    test('actionable audit includes proposal and provider events', () async {
      final result = await _run(
        sources: [_source('front', canonical: CatalogueCanonicalView.front)],
      );
      final types = result.auditEvents.map((item) => item.type).toSet();
      expect(
        types,
        containsAll({
          CatalogueReconstructionAuditEventType.proposalCreated,
          CatalogueReconstructionAuditEventType.providerRequestCreated,
          CatalogueReconstructionAuditEventType.providerSubmitted,
          CatalogueReconstructionAuditEventType.manualReviewRequired,
        }),
      );
    });

    test('blocked audit contains no provider submission', () async {
      final result = await _run(sources: const []);
      final types = result.auditEvents.map((item) => item.type).toSet();
      expect(
        types,
        contains(CatalogueReconstructionAuditEventType.workflowBlocked),
      );
      expect(
        types,
        isNot(
          contains(CatalogueReconstructionAuditEventType.providerSubmitted),
        ),
      );
    });

    test('workflow identity is deterministic across source order', () async {
      final first = await _run(
        sources: [
          _source('front', canonical: CatalogueCanonicalView.front),
          _source('back', canonical: CatalogueCanonicalView.back, order: 2),
        ],
      );
      final second = await _run(
        sources: [
          _source('back', canonical: CatalogueCanonicalView.back, order: 2),
          _source('front', canonical: CatalogueCanonicalView.front),
        ],
      );
      expect(first.workflowId, second.workflowId);
    });

    test('source IDs are normalized and sorted', () async {
      final result = await _run(
        sources: [
          _source(' z ', canonical: CatalogueCanonicalView.front),
          _source('a', canonical: CatalogueCanonicalView.back, order: 2),
        ],
      );
      expect(result.sourceViewIds, ['a', 'z']);
    });

    test('empty design ID is rejected', () {
      expect(
        () => _orchestrator().run(
          designId: ' ',
          versionId: 'version-1',
          sources: const [],
        ),
        throwsArgumentError,
      );
    });

    test('empty version ID is rejected', () {
      expect(
        () => _orchestrator().run(
          designId: 'design-1',
          versionId: '',
          sources: const [],
        ),
        throwsArgumentError,
      );
    });

    test('workflow result enforces safety boundaries', () async {
      final result = await _run(
        sources: [_source('front', canonical: CatalogueCanonicalView.front)],
      );
      expect(result.createsGeneratedAssets, isFalse);
      expect(result.writesFirebase, isFalse);
      expect(result.usesMeasurements, isFalse);
      expect(result.customerVisible, isFalse);
    });
  });
}

CatalogueReconstructionWorkflowOrchestrator _orchestrator({
  CatalogueProviderAdapter adapter = const CatalogueMockProviderAdapter(),
}) => CatalogueReconstructionWorkflowOrchestrator(adapter: adapter);

Future<CatalogueReconstructionWorkflowResult> _run({
  required List<CatalogueClassifiedSourceEvidence> sources,
  CatalogueProviderAdapter adapter = const CatalogueMockProviderAdapter(),
}) => _orchestrator(
  adapter: adapter,
).run(designId: 'design-1', versionId: 'version-1', sources: sources);

CatalogueClassifiedSourceEvidence _source(
  String id, {
  CatalogueCanonicalView? canonical,
  bool detail = false,
  bool combined = false,
  int order = 1,
}) {
  return CatalogueClassifiedSourceEvidence(
    descriptor: CatalogueSourceViewDescriptor(
      viewId: id,
      persistedViewType: detail
          ? CatalogueDesignViewType.detail
          : combined
          ? CatalogueDesignViewType.combinedFrontBack
          : canonical == CatalogueCanonicalView.front
          ? CatalogueDesignViewType.front
          : canonical == CatalogueCanonicalView.back
          ? CatalogueDesignViewType.back
          : canonical == CatalogueCanonicalView.leftSide ||
                canonical == CatalogueCanonicalView.rightSide
          ? CatalogueDesignViewType.side
          : CatalogueDesignViewType.singleView,
      canonicalView: canonical,
      origin: CatalogueSourceViewOrigin.designerUploaded,
      evidenceClass: CatalogueViewEvidenceClass.observed,
      displayOrder: order,
      isPrimary: order == 1,
    ),
    classification: detail
        ? const CatalogueSourceViewClassification(
            persistedViewType: CatalogueDesignViewType.detail,
            source: CatalogueClassificationSource.designerDeclared,
            detail: CatalogueDetailClassification.neckDetail,
          )
        : null,
  );
}

class _RejectingAdapter implements CatalogueProviderAdapter {
  const _RejectingAdapter();

  @override
  String get adapterId => 'rejecting-adapter';

  @override
  String get contractVersion => '1.0';

  @override
  Future<CatalogueProviderResponse> submit(
    CatalogueProviderRequest request,
  ) async => CatalogueProviderResponse(
    providerRequestId: request.providerRequestId,
    status: CatalogueProviderResponseStatus.rejected,
    acceptedTargets: const {},
    rejectedTargets: request.manifest.targetViews.toSet(),
    failureCode: CatalogueProviderFailureCode.unsupportedTarget,
  );
}
