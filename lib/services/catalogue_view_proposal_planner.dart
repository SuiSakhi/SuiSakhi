import '../models/catalogue_design_evidence.dart';
import '../models/catalogue_view_proposal.dart';

/// Builds deterministic, provider-independent missing-view proposal requests.
///
/// This planner never generates an image, persists data, calls a network,
/// uses measurements, or marks an output customer-ready.
class CatalogueViewProposalPlanner {
  const CatalogueViewProposalPlanner._();

  static const Set<CatalogueViewProposalRestriction> _restrictions = {
    CatalogueViewProposalRestriction.noMeasurements,
    CatalogueViewProposalRestriction.noBodyAssumptions,
    CatalogueViewProposalRestriction.noCustomerSpecificInference,
    CatalogueViewProposalRestriction.noHiddenDetailClaims,
    CatalogueViewProposalRestriction.preserveObservedSilhouette,
    CatalogueViewProposalRestriction.preserveObservedVisualProportion,
    CatalogueViewProposalRestriction.preserveObservedDesignDetails,
    CatalogueViewProposalRestriction.preserveGarmentPieceComposition,
    CatalogueViewProposalRestriction.noAutomaticApproval,
    CatalogueViewProposalRestriction.noCustomerPublication,
  };

  static CatalogueViewProposalRequest build({
    required String designId,
    required String versionId,
    required Iterable<String> sourceViewIds,
    required CatalogueDesignEvidenceSummary evidence,
  }) {
    final normalizedDesignId = designId.trim();
    final normalizedVersionId = versionId.trim();
    if (normalizedDesignId.isEmpty) {
      throw ArgumentError.value(designId, 'designId', 'is required');
    }
    if (normalizedVersionId.isEmpty) {
      throw ArgumentError.value(versionId, 'versionId', 'is required');
    }

    final normalizedSources =
        sourceViewIds
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    final blockReason = _blockReason(evidence);
    final targets = blockReason == null
        ? _targets(evidence)
        : <CatalogueViewProposalTarget>[];
    final status = targets.isEmpty
        ? CatalogueViewProposalStatus.blocked
        : CatalogueViewProposalStatus.planned;
    final effectiveBlockReason = status == CatalogueViewProposalStatus.blocked
        ? blockReason ??
              CatalogueViewProposalBlockReason.noMissingCanonicalViews
        : null;

    return CatalogueViewProposalRequest(
      requestId: _requestId(
        designId: normalizedDesignId,
        versionId: normalizedVersionId,
        sourceViewIds: normalizedSources,
        evidence: evidence,
      ),
      designId: normalizedDesignId,
      versionId: normalizedVersionId,
      sourceViewIds: normalizedSources,
      targets: targets,
      restrictions: _restrictions,
      reviewPolicy: _reviewPolicy(evidence.reviewLevel),
      status: status,
      blockReason: effectiveBlockReason,
    );
  }

  static CatalogueViewProposalBlockReason? _blockReason(
    CatalogueDesignEvidenceSummary evidence,
  ) {
    switch (evidence.readiness) {
      case CatalogueReconstructionReadiness.insufficientEvidence:
        return CatalogueViewProposalBlockReason.insufficientEvidence;
      case CatalogueReconstructionReadiness.classificationRequired:
        return CatalogueViewProposalBlockReason.classificationRequired;
      case CatalogueReconstructionReadiness.extractionRequired:
        return CatalogueViewProposalBlockReason.extractionRequired;
      case CatalogueReconstructionReadiness.fullCanonicalViewSetAvailable:
        return CatalogueViewProposalBlockReason.noMissingCanonicalViews;
      case CatalogueReconstructionReadiness.limitedViewProposal:
      case CatalogueReconstructionReadiness.canonicalViewProposal:
      case CatalogueReconstructionReadiness.enhancedCanonicalViewProposal:
        return null;
    }
  }

  static List<CatalogueViewProposalTarget> _targets(
    CatalogueDesignEvidenceSummary evidence,
  ) {
    final ordered = evidence.proposedMissingViews.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    return ordered
        .map(
          (target) => CatalogueViewProposalTarget(
            targetView: target,
            evidenceClass: _evidenceClass(evidence),
            observedSourceViews: evidence.observedCanonicalViews,
            consistencyChecks: evidence.requiredConsistencyChecks,
          ),
        )
        .toList(growable: false);
  }

  static CatalogueViewProposalEvidenceClass _evidenceClass(
    CatalogueDesignEvidenceSummary evidence,
  ) {
    return evidence.canonicalSourceCount >= 2
        ? CatalogueViewProposalEvidenceClass.partiallyObserved
        : CatalogueViewProposalEvidenceClass.inferred;
  }

  static CatalogueViewProposalReviewPolicy _reviewPolicy(
    CatalogueEvidenceReviewLevel level,
  ) {
    switch (level) {
      case CatalogueEvidenceReviewLevel.sourceCorrectionRequired:
      case CatalogueEvidenceReviewLevel.enhancedReview:
        return CatalogueViewProposalReviewPolicy.enhancedReview;
      case CatalogueEvidenceReviewLevel.standardReview:
        return CatalogueViewProposalReviewPolicy.standardReview;
      case CatalogueEvidenceReviewLevel.focusedReview:
        return CatalogueViewProposalReviewPolicy.focusedReview;
    }
  }

  static String _requestId({
    required String designId,
    required String versionId,
    required List<String> sourceViewIds,
    required CatalogueDesignEvidenceSummary evidence,
  }) {
    final sourcePart = sourceViewIds.join(',');
    final observed =
        evidence.observedCanonicalViews.map((item) => item.name).toList()
          ..sort();
    final missing =
        evidence.proposedMissingViews.map((item) => item.name).toList()..sort();
    return [
      'view-proposal-v1',
      designId,
      versionId,
      sourcePart,
      observed.join(','),
      missing.join(','),
      evidence.readiness.name,
    ].join('|');
  }
}
