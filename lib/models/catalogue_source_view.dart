import 'catalogue_design_view.dart';

/// Canonical design views used by the C1.4B-1 planning foundation.
///
/// This enum does not replace [CatalogueDesignViewType]. Persisted C1.3 view
/// values remain unchanged for backward compatibility.
enum CatalogueCanonicalView { front, back, leftSide, rightSide }

/// Origin of a source view supplied to the planning foundation.
enum CatalogueSourceViewOrigin {
  designerUploaded,
  adminUploaded,
  combinedImageExtracted,
  systemNormalized,
  manuallyCorrected,
}

/// Evidence class for a source view.
enum CatalogueViewEvidenceClass { observed, partiallyObserved, unclassified }

/// Readiness of a source-view inventory for future missing-view planning.
enum CatalogueSourceViewReadiness {
  readyForMissingViewPlanning,
  classificationRequired,
  extractionRequired,
  insufficientCanonicalEvidence,
}

/// Warning codes emitted by the source-view registry.
enum CatalogueSourceViewWarning {
  sideDirectionUnspecified,
  combinedViewExtractionRequired,
  singleViewClassificationRequired,
  insufficientCanonicalEvidence,
  duplicateCanonicalView,
  multiplePrimaryViews,
  primaryViewMissing,
}

extension CatalogueCanonicalViewX on CatalogueCanonicalView {
  String get label {
    switch (this) {
      case CatalogueCanonicalView.front:
        return 'Front';
      case CatalogueCanonicalView.back:
        return 'Back';
      case CatalogueCanonicalView.leftSide:
        return 'Left Side';
      case CatalogueCanonicalView.rightSide:
        return 'Right Side';
    }
  }
}

extension CatalogueSourceViewWarningX on CatalogueSourceViewWarning {
  String get code {
    switch (this) {
      case CatalogueSourceViewWarning.sideDirectionUnspecified:
        return 'SIDE_DIRECTION_UNSPECIFIED';
      case CatalogueSourceViewWarning.combinedViewExtractionRequired:
        return 'COMBINED_VIEW_EXTRACTION_REQUIRED';
      case CatalogueSourceViewWarning.singleViewClassificationRequired:
        return 'SINGLE_VIEW_CLASSIFICATION_REQUIRED';
      case CatalogueSourceViewWarning.insufficientCanonicalEvidence:
        return 'INSUFFICIENT_CANONICAL_EVIDENCE';
      case CatalogueSourceViewWarning.duplicateCanonicalView:
        return 'DUPLICATE_CANONICAL_VIEW';
      case CatalogueSourceViewWarning.multiplePrimaryViews:
        return 'MULTIPLE_PRIMARY_VIEWS';
      case CatalogueSourceViewWarning.primaryViewMissing:
        return 'PRIMARY_VIEW_MISSING';
    }
  }
}

/// Pure planning descriptor that wraps an existing persisted Catalogue view.
///
/// No generated view or Firebase document is created by this model.
class CatalogueSourceViewDescriptor {
  const CatalogueSourceViewDescriptor({
    required this.viewId,
    required this.persistedViewType,
    required this.origin,
    required this.evidenceClass,
    required this.displayOrder,
    required this.isPrimary,
    this.canonicalView,
    this.title,
  });

  factory CatalogueSourceViewDescriptor.fromDesignView(
    CatalogueDesignView view, {
    required CatalogueSourceViewOrigin origin,
    CatalogueCanonicalView? canonicalView,
    CatalogueViewEvidenceClass evidenceClass =
        CatalogueViewEvidenceClass.observed,
  }) {
    return CatalogueSourceViewDescriptor(
      viewId: view.viewId,
      persistedViewType: view.viewType,
      canonicalView: canonicalView ?? _canonicalFor(view.viewType),
      origin: origin,
      evidenceClass: evidenceClass,
      displayOrder: view.displayOrder,
      isPrimary: view.isPrimary,
      title: view.title,
    );
  }

  final String viewId;
  final CatalogueDesignViewType persistedViewType;
  final CatalogueCanonicalView? canonicalView;
  final CatalogueSourceViewOrigin origin;
  final CatalogueViewEvidenceClass evidenceClass;
  final int displayOrder;
  final bool isPrimary;
  final String? title;

  bool get isDetail => persistedViewType == CatalogueDesignViewType.detail;

  bool get isCombined =>
      persistedViewType == CatalogueDesignViewType.combinedFrontBack;

  bool get isGenericSide =>
      persistedViewType == CatalogueDesignViewType.side &&
      canonicalView == null;

  bool get requiresClassification =>
      persistedViewType == CatalogueDesignViewType.singleView &&
      canonicalView == null;

  static CatalogueCanonicalView? _canonicalFor(
    CatalogueDesignViewType viewType,
  ) {
    switch (viewType) {
      case CatalogueDesignViewType.front:
        return CatalogueCanonicalView.front;
      case CatalogueDesignViewType.back:
        return CatalogueCanonicalView.back;
      case CatalogueDesignViewType.side:
      case CatalogueDesignViewType.detail:
      case CatalogueDesignViewType.combinedFrontBack:
      case CatalogueDesignViewType.singleView:
        return null;
    }
  }
}

/// Immutable result produced by [CatalogueSourceViewRegistry].
class CatalogueCanonicalViewInventory {
  CatalogueCanonicalViewInventory({
    required List<CatalogueSourceViewDescriptor> orderedSources,
    required Set<CatalogueCanonicalView> observedCanonicalViews,
    required List<CatalogueSourceViewDescriptor> supportingDetailViews,
    required List<CatalogueSourceViewDescriptor> combinedViewSources,
    required List<CatalogueSourceViewDescriptor> unclassifiedSources,
    required Set<CatalogueCanonicalView> proposedMissingViews,
    required Set<CatalogueSourceViewWarning> warnings,
    required this.readiness,
    required this.hasGenericSideEvidence,
  }) : orderedSources = List.unmodifiable(orderedSources),
       observedCanonicalViews = Set.unmodifiable(observedCanonicalViews),
       supportingDetailViews = List.unmodifiable(supportingDetailViews),
       combinedViewSources = List.unmodifiable(combinedViewSources),
       unclassifiedSources = List.unmodifiable(unclassifiedSources),
       proposedMissingViews = Set.unmodifiable(proposedMissingViews),
       warnings = Set.unmodifiable(warnings);

  final List<CatalogueSourceViewDescriptor> orderedSources;
  final Set<CatalogueCanonicalView> observedCanonicalViews;
  final List<CatalogueSourceViewDescriptor> supportingDetailViews;
  final List<CatalogueSourceViewDescriptor> combinedViewSources;
  final List<CatalogueSourceViewDescriptor> unclassifiedSources;
  final Set<CatalogueCanonicalView> proposedMissingViews;
  final Set<CatalogueSourceViewWarning> warnings;
  final CatalogueSourceViewReadiness readiness;
  final bool hasGenericSideEvidence;

  bool get hasPrimarySource => orderedSources.any((item) => item.isPrimary);

  bool get hasCanonicalEvidence => observedCanonicalViews.isNotEmpty;

  bool get createsGeneratedViews => false;
}
