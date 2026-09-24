import 'catalogue_design_evidence.dart';
import 'catalogue_provider_response.dart';
import 'catalogue_source_view.dart';
import 'catalogue_view_proposal.dart';

enum CatalogueReconstructionWorkflowStatus {
  blocked,
  providerAccepted,
  manualReviewRequired,
  providerRejected,
  providerFailed,
  noProposalRequired,
}

enum CatalogueReconstructionAuditEventType {
  workflowStarted,
  evidenceAnalyzed,
  workflowBlocked,
  proposalCreated,
  providerRequestCreated,
  providerSubmitted,
  providerAccepted,
  providerRejected,
  manualReviewRequired,
  providerFailed,
  noProposalRequired,
  workflowCompleted,
}

class CatalogueReconstructionAuditEvent {
  const CatalogueReconstructionAuditEvent({
    required this.sequence,
    required this.type,
    required this.code,
  });

  final int sequence;
  final CatalogueReconstructionAuditEventType type;
  final String code;
}

/// Metadata-only result from the local reconstruction workflow.
class CatalogueReconstructionWorkflowResult {
  CatalogueReconstructionWorkflowResult({
    required this.workflowId,
    required this.designId,
    required this.versionId,
    required this.status,
    required this.evidence,
    required List<String> sourceViewIds,
    required Set<CatalogueCanonicalView> acceptedTargets,
    required Set<CatalogueCanonicalView> rejectedTargets,
    required List<CatalogueReconstructionAuditEvent> auditEvents,
    this.proposal,
    this.providerResponse,
  }) : sourceViewIds = List.unmodifiable(sourceViewIds),
       acceptedTargets = Set.unmodifiable(acceptedTargets),
       rejectedTargets = Set.unmodifiable(rejectedTargets),
       auditEvents = List.unmodifiable(auditEvents);

  final String workflowId;
  final String designId;
  final String versionId;
  final CatalogueReconstructionWorkflowStatus status;
  final CatalogueDesignEvidenceSummary evidence;
  final List<String> sourceViewIds;
  final CatalogueViewProposalRequest? proposal;
  final CatalogueProviderResponse? providerResponse;
  final Set<CatalogueCanonicalView> acceptedTargets;
  final Set<CatalogueCanonicalView> rejectedTargets;
  final List<CatalogueReconstructionAuditEvent> auditEvents;

  bool get providerCalled => providerResponse != null;
  bool get requiresReview =>
      status == CatalogueReconstructionWorkflowStatus.manualReviewRequired;
  bool get createsGeneratedAssets => false;
  bool get writesFirebase => false;
  bool get usesMeasurements => false;
  bool get customerVisible => false;
}
