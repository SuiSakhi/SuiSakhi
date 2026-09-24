import '../models/catalogue_design_evidence.dart';
import '../models/catalogue_provider_response.dart';
import '../models/catalogue_reconstruction_workflow.dart';
import '../models/catalogue_view_proposal.dart';
import 'catalogue_design_evidence_analyzer.dart';
import 'catalogue_provider_adapter.dart';
import 'catalogue_provider_request_factory.dart';
import 'catalogue_view_proposal_planner.dart';

/// Runs the complete metadata-only local reconstruction workflow.
class CatalogueReconstructionWorkflowOrchestrator {
  const CatalogueReconstructionWorkflowOrchestrator({required this.adapter});

  final CatalogueProviderAdapter adapter;

  Future<CatalogueReconstructionWorkflowResult> run({
    required String designId,
    required String versionId,
    required Iterable<CatalogueClassifiedSourceEvidence> sources,
  }) async {
    final normalizedDesignId = designId.trim();
    final normalizedVersionId = versionId.trim();
    if (normalizedDesignId.isEmpty) {
      throw ArgumentError.value(designId, 'designId', 'is required');
    }
    if (normalizedVersionId.isEmpty) {
      throw ArgumentError.value(versionId, 'versionId', 'is required');
    }

    final sourceList = sources.toList(growable: false);
    final sourceIds =
        sourceList
            .map((item) => item.descriptor.viewId.trim())
            .where((item) => item.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final workflowId = _workflowId(
      designId: normalizedDesignId,
      versionId: normalizedVersionId,
      sourceViewIds: sourceIds,
      adapterId: adapter.adapterId,
      contractVersion: adapter.contractVersion,
    );
    final audit = <CatalogueReconstructionAuditEvent>[];
    void add(CatalogueReconstructionAuditEventType type, String code) {
      audit.add(
        CatalogueReconstructionAuditEvent(
          sequence: audit.length + 1,
          type: type,
          code: code,
        ),
      );
    }

    add(
      CatalogueReconstructionAuditEventType.workflowStarted,
      'WORKFLOW_STARTED',
    );
    final evidence = CatalogueDesignEvidenceAnalyzer.analyze(sourceList);
    add(
      CatalogueReconstructionAuditEventType.evidenceAnalyzed,
      'EVIDENCE_ANALYZED',
    );

    final proposal = CatalogueViewProposalPlanner.build(
      designId: normalizedDesignId,
      versionId: normalizedVersionId,
      sourceViewIds: sourceIds,
      evidence: evidence,
    );

    if (!proposal.isActionable) {
      final noProposalRequired =
          proposal.blockReason ==
          CatalogueViewProposalBlockReason.noMissingCanonicalViews;
      add(
        noProposalRequired
            ? CatalogueReconstructionAuditEventType.noProposalRequired
            : CatalogueReconstructionAuditEventType.workflowBlocked,
        noProposalRequired ? 'NO_PROPOSAL_REQUIRED' : 'WORKFLOW_BLOCKED',
      );
      add(
        CatalogueReconstructionAuditEventType.workflowCompleted,
        'WORKFLOW_COMPLETED',
      );
      return CatalogueReconstructionWorkflowResult(
        workflowId: workflowId,
        designId: normalizedDesignId,
        versionId: normalizedVersionId,
        status: noProposalRequired
            ? CatalogueReconstructionWorkflowStatus.noProposalRequired
            : CatalogueReconstructionWorkflowStatus.blocked,
        evidence: evidence,
        sourceViewIds: sourceIds,
        proposal: proposal,
        acceptedTargets: const {},
        rejectedTargets: const {},
        auditEvents: audit,
      );
    }

    add(
      CatalogueReconstructionAuditEventType.proposalCreated,
      'PROPOSAL_CREATED',
    );
    final request = CatalogueProviderRequestFactory.fromProposal(proposal);
    add(
      CatalogueReconstructionAuditEventType.providerRequestCreated,
      'PROVIDER_REQUEST_CREATED',
    );
    add(
      CatalogueReconstructionAuditEventType.providerSubmitted,
      'PROVIDER_SUBMITTED',
    );
    final response = await adapter.submit(request);
    final status = _status(response.status);
    add(
      _responseAuditType(response.status),
      _responseAuditCode(response.status),
    );
    add(
      CatalogueReconstructionAuditEventType.workflowCompleted,
      'WORKFLOW_COMPLETED',
    );

    return CatalogueReconstructionWorkflowResult(
      workflowId: workflowId,
      designId: normalizedDesignId,
      versionId: normalizedVersionId,
      status: status,
      evidence: evidence,
      sourceViewIds: sourceIds,
      proposal: proposal,
      providerResponse: response,
      acceptedTargets: response.acceptedTargets,
      rejectedTargets: response.rejectedTargets,
      auditEvents: audit,
    );
  }

  static CatalogueReconstructionWorkflowStatus _status(
    CatalogueProviderResponseStatus status,
  ) {
    switch (status) {
      case CatalogueProviderResponseStatus.accepted:
        return CatalogueReconstructionWorkflowStatus.providerAccepted;
      case CatalogueProviderResponseStatus.manualReviewRequired:
        return CatalogueReconstructionWorkflowStatus.manualReviewRequired;
      case CatalogueProviderResponseStatus.rejected:
      case CatalogueProviderResponseStatus.insufficientEvidence:
        return CatalogueReconstructionWorkflowStatus.providerRejected;
      case CatalogueProviderResponseStatus.providerFailure:
        return CatalogueReconstructionWorkflowStatus.providerFailed;
    }
  }

  static CatalogueReconstructionAuditEventType _responseAuditType(
    CatalogueProviderResponseStatus status,
  ) {
    switch (status) {
      case CatalogueProviderResponseStatus.accepted:
        return CatalogueReconstructionAuditEventType.providerAccepted;
      case CatalogueProviderResponseStatus.manualReviewRequired:
        return CatalogueReconstructionAuditEventType.manualReviewRequired;
      case CatalogueProviderResponseStatus.rejected:
      case CatalogueProviderResponseStatus.insufficientEvidence:
        return CatalogueReconstructionAuditEventType.providerRejected;
      case CatalogueProviderResponseStatus.providerFailure:
        return CatalogueReconstructionAuditEventType.providerFailed;
    }
  }

  static String _responseAuditCode(CatalogueProviderResponseStatus status) {
    switch (status) {
      case CatalogueProviderResponseStatus.accepted:
        return 'PROVIDER_ACCEPTED';
      case CatalogueProviderResponseStatus.manualReviewRequired:
        return 'PROVIDER_MANUAL_REVIEW_REQUIRED';
      case CatalogueProviderResponseStatus.rejected:
        return 'PROVIDER_REJECTED';
      case CatalogueProviderResponseStatus.insufficientEvidence:
        return 'PROVIDER_INSUFFICIENT_EVIDENCE';
      case CatalogueProviderResponseStatus.providerFailure:
        return 'PROVIDER_FAILED';
    }
  }

  static String _workflowId({
    required String designId,
    required String versionId,
    required List<String> sourceViewIds,
    required String adapterId,
    required String contractVersion,
  }) => [
    'reconstruction-workflow-v1',
    designId,
    versionId,
    sourceViewIds.join(','),
    adapterId,
    contractVersion,
  ].join('|');
}
