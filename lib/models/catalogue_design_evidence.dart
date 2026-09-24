import 'catalogue_source_view.dart';
import 'catalogue_source_view_classification.dart';

/// Actionable readiness for the next Architecture Engine operation.
enum CatalogueReconstructionReadiness {
  insufficientEvidence,
  classificationRequired,
  extractionRequired,
  limitedViewProposal,
  canonicalViewProposal,
  enhancedCanonicalViewProposal,
  fullCanonicalViewSetAvailable,
}

/// Internal evidence band. This is not customer-facing terminology.
enum CatalogueEvidenceStrength {
  insufficient,
  limited,
  moderate,
  strong,
  comprehensive,
}

/// Review intensity required before a proposed view can become customer-ready.
enum CatalogueEvidenceReviewLevel {
  sourceCorrectionRequired,
  enhancedReview,
  standardReview,
  focusedReview,
}

/// Recommended next Architecture Engine operation.
enum CatalogueEvidenceNextAction {
  requestCanonicalSource,
  classifySingleView,
  extractCombinedViews,
  proposeMissingCanonicalViews,
  prepareCanonicalPreview,
}

/// Visual-design checks required for future generated-view review.
enum CatalogueVisualConsistencyDimension {
  neckline,
  sleeveType,
  silhouette,
  visualProportion,
  garmentPieces,
  closure,
  majorBorder,
  majorEmbellishment,
  panelOrYokeContinuity,
  materialRegionContinuity,
}

/// Evidence warnings retained for Admin and engineering review.
enum CatalogueDesignEvidenceWarning {
  noCanonicalEvidence,
  classificationPending,
  extractionPending,
  sideDirectionUnspecified,
  duplicateCanonicalView,
  primaryViewMissing,
  multiplePrimaryViews,
  onlyOneCanonicalView,
  inferredHiddenDetailsRequireReview,
}

extension CatalogueDesignEvidenceWarningX on CatalogueDesignEvidenceWarning {
  String get code {
    switch (this) {
      case CatalogueDesignEvidenceWarning.noCanonicalEvidence:
        return 'EVIDENCE_NO_CANONICAL_VIEW';
      case CatalogueDesignEvidenceWarning.classificationPending:
        return 'EVIDENCE_CLASSIFICATION_PENDING';
      case CatalogueDesignEvidenceWarning.extractionPending:
        return 'EVIDENCE_EXTRACTION_PENDING';
      case CatalogueDesignEvidenceWarning.sideDirectionUnspecified:
        return 'EVIDENCE_SIDE_DIRECTION_UNSPECIFIED';
      case CatalogueDesignEvidenceWarning.duplicateCanonicalView:
        return 'EVIDENCE_DUPLICATE_CANONICAL_VIEW';
      case CatalogueDesignEvidenceWarning.primaryViewMissing:
        return 'EVIDENCE_PRIMARY_VIEW_MISSING';
      case CatalogueDesignEvidenceWarning.multiplePrimaryViews:
        return 'EVIDENCE_MULTIPLE_PRIMARY_VIEWS';
      case CatalogueDesignEvidenceWarning.onlyOneCanonicalView:
        return 'EVIDENCE_ONLY_ONE_CANONICAL_VIEW';
      case CatalogueDesignEvidenceWarning.inferredHiddenDetailsRequireReview:
        return 'EVIDENCE_HIDDEN_DETAILS_REVIEW_REQUIRED';
    }
  }
}

/// Classified source paired with optional C1.4B-2 metadata.
class CatalogueClassifiedSourceEvidence {
  const CatalogueClassifiedSourceEvidence({
    required this.descriptor,
    this.classification,
  });

  final CatalogueSourceViewDescriptor descriptor;
  final CatalogueSourceViewClassification? classification;

  CatalogueDetailClassification? get detailClassification =>
      classification?.detail;
}

/// Immutable output from the C1.4B-3 evidence analyzer.
class CatalogueDesignEvidenceSummary {
  CatalogueDesignEvidenceSummary({
    required this.readiness,
    required this.strength,
    required this.reviewLevel,
    required this.nextAction,
    required Set<CatalogueCanonicalView> observedCanonicalViews,
    required Set<CatalogueCanonicalView> proposedMissingViews,
    required Set<CatalogueDetailClassification> detailCoverage,
    required Set<CatalogueVisualConsistencyDimension> requiredConsistencyChecks,
    required Set<CatalogueDesignEvidenceWarning> warnings,
    required this.sourceCount,
    required this.canonicalSourceCount,
    required this.detailSourceCount,
    required this.hasGenericSideEvidence,
  }) : observedCanonicalViews = Set.unmodifiable(observedCanonicalViews),
       proposedMissingViews = Set.unmodifiable(proposedMissingViews),
       detailCoverage = Set.unmodifiable(detailCoverage),
       requiredConsistencyChecks = Set.unmodifiable(requiredConsistencyChecks),
       warnings = Set.unmodifiable(warnings);

  final CatalogueReconstructionReadiness readiness;
  final CatalogueEvidenceStrength strength;
  final CatalogueEvidenceReviewLevel reviewLevel;
  final CatalogueEvidenceNextAction nextAction;
  final Set<CatalogueCanonicalView> observedCanonicalViews;
  final Set<CatalogueCanonicalView> proposedMissingViews;
  final Set<CatalogueDetailClassification> detailCoverage;
  final Set<CatalogueVisualConsistencyDimension> requiredConsistencyChecks;
  final Set<CatalogueDesignEvidenceWarning> warnings;
  final int sourceCount;
  final int canonicalSourceCount;
  final int detailSourceCount;
  final bool hasGenericSideEvidence;

  bool get canProposeMissingViews =>
      readiness == CatalogueReconstructionReadiness.limitedViewProposal ||
      readiness == CatalogueReconstructionReadiness.canonicalViewProposal ||
      readiness ==
          CatalogueReconstructionReadiness.enhancedCanonicalViewProposal;

  bool get hasCompleteCanonicalSet =>
      readiness ==
      CatalogueReconstructionReadiness.fullCanonicalViewSetAvailable;

  bool get customerPreviewReady => false;

  bool get usesMeasurements => false;

  bool get createsGeneratedAssets => false;
}
