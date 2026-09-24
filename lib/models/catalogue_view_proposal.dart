import 'catalogue_design_evidence.dart';
import 'catalogue_source_view.dart';

/// Lifecycle of a local proposal request.
enum CatalogueViewProposalStatus { planned, blocked }

/// Why a proposal plan is blocked.
enum CatalogueViewProposalBlockReason {
  insufficientEvidence,
  classificationRequired,
  extractionRequired,
  noMissingCanonicalViews,
}

/// Restrictions that every future reconstruction provider must obey.
enum CatalogueViewProposalRestriction {
  noMeasurements,
  noBodyAssumptions,
  noCustomerSpecificInference,
  noHiddenDetailClaims,
  preserveObservedSilhouette,
  preserveObservedVisualProportion,
  preserveObservedDesignDetails,
  preserveGarmentPieceComposition,
  noAutomaticApproval,
  noCustomerPublication,
}

/// Provenance attached to a proposal target.
enum CatalogueViewProposalEvidenceClass { inferred, partiallyObserved }

/// Review policy derived from the evidence summary.
enum CatalogueViewProposalReviewPolicy {
  enhancedReview,
  standardReview,
  focusedReview,
}

/// A single missing canonical view requested by the Architecture Engine.
class CatalogueViewProposalTarget {
  CatalogueViewProposalTarget({
    required this.targetView,
    required this.evidenceClass,
    required Set<CatalogueCanonicalView> observedSourceViews,
    required Set<CatalogueVisualConsistencyDimension> consistencyChecks,
  }) : observedSourceViews = Set.unmodifiable(observedSourceViews),
       consistencyChecks = Set.unmodifiable(consistencyChecks);

  final CatalogueCanonicalView targetView;
  final CatalogueViewProposalEvidenceClass evidenceClass;
  final Set<CatalogueCanonicalView> observedSourceViews;
  final Set<CatalogueVisualConsistencyDimension> consistencyChecks;
}

/// Provider-independent request for future missing-view reconstruction.
class CatalogueViewProposalRequest {
  CatalogueViewProposalRequest({
    required this.requestId,
    required this.designId,
    required this.versionId,
    required List<String> sourceViewIds,
    required List<CatalogueViewProposalTarget> targets,
    required Set<CatalogueViewProposalRestriction> restrictions,
    required this.reviewPolicy,
    required this.status,
    this.blockReason,
  }) : sourceViewIds = List.unmodifiable(sourceViewIds),
       targets = List.unmodifiable(targets),
       restrictions = Set.unmodifiable(restrictions);

  final String requestId;
  final String designId;
  final String versionId;
  final List<String> sourceViewIds;
  final List<CatalogueViewProposalTarget> targets;
  final Set<CatalogueViewProposalRestriction> restrictions;
  final CatalogueViewProposalReviewPolicy reviewPolicy;
  final CatalogueViewProposalStatus status;
  final CatalogueViewProposalBlockReason? blockReason;

  bool get isActionable =>
      status == CatalogueViewProposalStatus.planned && targets.isNotEmpty;

  bool get createsGeneratedAssets => false;
  bool get writesFirebase => false;
  bool get usesMeasurements => false;
  bool get customerVisible => false;
}
