import '../models/catalogue_design_evidence.dart';
import '../models/catalogue_source_view.dart';
import '../models/catalogue_source_view_classification.dart';
import 'catalogue_source_view_registry.dart';

/// Pure-Dart evidence and reconstruction-readiness decision engine.
///
/// The analyzer consumes classified planning metadata only. It does not access
/// Firebase, generate images, use measurements, or publish customer assets.
class CatalogueDesignEvidenceAnalyzer {
  const CatalogueDesignEvidenceAnalyzer._();

  static const Set<CatalogueCanonicalView> _allCanonicalViews = {
    CatalogueCanonicalView.front,
    CatalogueCanonicalView.back,
    CatalogueCanonicalView.leftSide,
    CatalogueCanonicalView.rightSide,
  };

  static const Set<CatalogueVisualConsistencyDimension> _baseChecks = {
    CatalogueVisualConsistencyDimension.silhouette,
    CatalogueVisualConsistencyDimension.visualProportion,
    CatalogueVisualConsistencyDimension.garmentPieces,
  };

  static CatalogueDesignEvidenceSummary analyze(
    Iterable<CatalogueClassifiedSourceEvidence> evidence,
  ) {
    final values = evidence.toList(growable: false);
    final descriptors = values.map((item) => item.descriptor).toList();
    final inventory = CatalogueSourceViewRegistry.build(descriptors);
    final details = _detailCoverage(values);
    final readiness = _readiness(inventory);
    final strength = _strength(
      readiness: readiness,
      canonicalCount: inventory.observedCanonicalViews.length,
      detailCount: details.length,
      hasGenericSide: inventory.hasGenericSideEvidence,
    );
    final warnings = _warnings(inventory, readiness);
    final checks = _consistencyChecks(details: details, readiness: readiness);

    return CatalogueDesignEvidenceSummary(
      readiness: readiness,
      strength: strength,
      reviewLevel: _reviewLevel(readiness),
      nextAction: _nextAction(readiness),
      observedCanonicalViews: inventory.observedCanonicalViews,
      proposedMissingViews: inventory.proposedMissingViews,
      detailCoverage: details,
      requiredConsistencyChecks: checks,
      warnings: warnings,
      sourceCount: values.length,
      canonicalSourceCount: inventory.observedCanonicalViews.length,
      detailSourceCount: values
          .where((item) => item.descriptor.isDetail)
          .length,
      hasGenericSideEvidence: inventory.hasGenericSideEvidence,
    );
  }

  static CatalogueReconstructionReadiness _readiness(
    CatalogueCanonicalViewInventory inventory,
  ) {
    switch (inventory.readiness) {
      case CatalogueSourceViewReadiness.classificationRequired:
        return CatalogueReconstructionReadiness.classificationRequired;
      case CatalogueSourceViewReadiness.extractionRequired:
        return CatalogueReconstructionReadiness.extractionRequired;
      case CatalogueSourceViewReadiness.insufficientCanonicalEvidence:
        return CatalogueReconstructionReadiness.insufficientEvidence;
      case CatalogueSourceViewReadiness.readyForMissingViewPlanning:
        break;
    }

    final observed = inventory.observedCanonicalViews;
    if (observed.containsAll(_allCanonicalViews)) {
      return CatalogueReconstructionReadiness.fullCanonicalViewSetAvailable;
    }

    if (inventory.hasGenericSideEvidence) {
      final hasFrontAndBack =
          observed.contains(CatalogueCanonicalView.front) &&
          observed.contains(CatalogueCanonicalView.back);
      if (hasFrontAndBack) {
        return CatalogueReconstructionReadiness.enhancedCanonicalViewProposal;
      }
      return CatalogueReconstructionReadiness.classificationRequired;
    }

    final count = observed.length;
    if (count <= 1) {
      return CatalogueReconstructionReadiness.limitedViewProposal;
    }
    if (count == 2) {
      return CatalogueReconstructionReadiness.canonicalViewProposal;
    }
    return CatalogueReconstructionReadiness.enhancedCanonicalViewProposal;
  }

  static CatalogueEvidenceStrength _strength({
    required CatalogueReconstructionReadiness readiness,
    required int canonicalCount,
    required int detailCount,
    required bool hasGenericSide,
  }) {
    switch (readiness) {
      case CatalogueReconstructionReadiness.insufficientEvidence:
      case CatalogueReconstructionReadiness.classificationRequired:
      case CatalogueReconstructionReadiness.extractionRequired:
        return CatalogueEvidenceStrength.insufficient;
      case CatalogueReconstructionReadiness.fullCanonicalViewSetAvailable:
        return CatalogueEvidenceStrength.comprehensive;
      case CatalogueReconstructionReadiness.enhancedCanonicalViewProposal:
        return CatalogueEvidenceStrength.strong;
      case CatalogueReconstructionReadiness.canonicalViewProposal:
        return detailCount >= 2
            ? CatalogueEvidenceStrength.strong
            : CatalogueEvidenceStrength.moderate;
      case CatalogueReconstructionReadiness.limitedViewProposal:
        if (canonicalCount == 1 && detailCount >= 3 && !hasGenericSide) {
          return CatalogueEvidenceStrength.moderate;
        }
        return CatalogueEvidenceStrength.limited;
    }
  }

  static CatalogueEvidenceReviewLevel _reviewLevel(
    CatalogueReconstructionReadiness readiness,
  ) {
    switch (readiness) {
      case CatalogueReconstructionReadiness.insufficientEvidence:
      case CatalogueReconstructionReadiness.classificationRequired:
      case CatalogueReconstructionReadiness.extractionRequired:
        return CatalogueEvidenceReviewLevel.sourceCorrectionRequired;
      case CatalogueReconstructionReadiness.limitedViewProposal:
        return CatalogueEvidenceReviewLevel.enhancedReview;
      case CatalogueReconstructionReadiness.canonicalViewProposal:
        return CatalogueEvidenceReviewLevel.standardReview;
      case CatalogueReconstructionReadiness.enhancedCanonicalViewProposal:
      case CatalogueReconstructionReadiness.fullCanonicalViewSetAvailable:
        return CatalogueEvidenceReviewLevel.focusedReview;
    }
  }

  static CatalogueEvidenceNextAction _nextAction(
    CatalogueReconstructionReadiness readiness,
  ) {
    switch (readiness) {
      case CatalogueReconstructionReadiness.insufficientEvidence:
        return CatalogueEvidenceNextAction.requestCanonicalSource;
      case CatalogueReconstructionReadiness.classificationRequired:
        return CatalogueEvidenceNextAction.classifySingleView;
      case CatalogueReconstructionReadiness.extractionRequired:
        return CatalogueEvidenceNextAction.extractCombinedViews;
      case CatalogueReconstructionReadiness.limitedViewProposal:
      case CatalogueReconstructionReadiness.canonicalViewProposal:
      case CatalogueReconstructionReadiness.enhancedCanonicalViewProposal:
        return CatalogueEvidenceNextAction.proposeMissingCanonicalViews;
      case CatalogueReconstructionReadiness.fullCanonicalViewSetAvailable:
        return CatalogueEvidenceNextAction.prepareCanonicalPreview;
    }
  }

  static Set<CatalogueDetailClassification> _detailCoverage(
    List<CatalogueClassifiedSourceEvidence> values,
  ) {
    final result = <CatalogueDetailClassification>{};
    for (final item in values) {
      final detail = item.detailClassification;
      if (detail != null &&
          detail != CatalogueDetailClassification.genericDetail) {
        result.add(detail);
      }
    }
    return result;
  }

  static Set<CatalogueDesignEvidenceWarning> _warnings(
    CatalogueCanonicalViewInventory inventory,
    CatalogueReconstructionReadiness readiness,
  ) {
    final result = <CatalogueDesignEvidenceWarning>{};
    if (inventory.warnings.contains(
      CatalogueSourceViewWarning.sideDirectionUnspecified,
    )) {
      result.add(CatalogueDesignEvidenceWarning.sideDirectionUnspecified);
    }
    if (inventory.warnings.contains(
      CatalogueSourceViewWarning.duplicateCanonicalView,
    )) {
      result.add(CatalogueDesignEvidenceWarning.duplicateCanonicalView);
    }
    if (inventory.warnings.contains(
      CatalogueSourceViewWarning.primaryViewMissing,
    )) {
      result.add(CatalogueDesignEvidenceWarning.primaryViewMissing);
    }
    if (inventory.warnings.contains(
      CatalogueSourceViewWarning.multiplePrimaryViews,
    )) {
      result.add(CatalogueDesignEvidenceWarning.multiplePrimaryViews);
    }
    switch (readiness) {
      case CatalogueReconstructionReadiness.insufficientEvidence:
        result.add(CatalogueDesignEvidenceWarning.noCanonicalEvidence);
      case CatalogueReconstructionReadiness.classificationRequired:
        result.add(CatalogueDesignEvidenceWarning.classificationPending);
      case CatalogueReconstructionReadiness.extractionRequired:
        result.add(CatalogueDesignEvidenceWarning.extractionPending);
      case CatalogueReconstructionReadiness.limitedViewProposal:
        result
          ..add(CatalogueDesignEvidenceWarning.onlyOneCanonicalView)
          ..add(
            CatalogueDesignEvidenceWarning.inferredHiddenDetailsRequireReview,
          );
      case CatalogueReconstructionReadiness.canonicalViewProposal:
      case CatalogueReconstructionReadiness.enhancedCanonicalViewProposal:
        result.add(
          CatalogueDesignEvidenceWarning.inferredHiddenDetailsRequireReview,
        );
      case CatalogueReconstructionReadiness.fullCanonicalViewSetAvailable:
        break;
    }
    return result;
  }

  static Set<CatalogueVisualConsistencyDimension> _consistencyChecks({
    required Set<CatalogueDetailClassification> details,
    required CatalogueReconstructionReadiness readiness,
  }) {
    final result = <CatalogueVisualConsistencyDimension>{..._baseChecks};
    if (details.contains(CatalogueDetailClassification.neckDetail)) {
      result.add(CatalogueVisualConsistencyDimension.neckline);
    }
    if (details.contains(CatalogueDetailClassification.sleeveDetail)) {
      result.add(CatalogueVisualConsistencyDimension.sleeveType);
    }
    if (details.contains(CatalogueDetailClassification.borderDetail)) {
      result.add(CatalogueVisualConsistencyDimension.majorBorder);
    }
    if (details.contains(CatalogueDetailClassification.embellishmentDetail)) {
      result.add(CatalogueVisualConsistencyDimension.majorEmbellishment);
    }
    if (details.contains(CatalogueDetailClassification.closureDetail)) {
      result.add(CatalogueVisualConsistencyDimension.closure);
    }
    if (details.contains(CatalogueDetailClassification.constructionDetail)) {
      result.add(CatalogueVisualConsistencyDimension.panelOrYokeContinuity);
    }
    if (readiness != CatalogueReconstructionReadiness.insufficientEvidence) {
      result.add(CatalogueVisualConsistencyDimension.materialRegionContinuity);
    }
    return result;
  }
}
