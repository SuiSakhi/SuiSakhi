import '../models/catalogue_design_view.dart';
import '../models/catalogue_source_view.dart';
import '../models/catalogue_source_view_classification.dart';

/// Validates optional C1.4B-2 metadata against the existing persisted view
/// type and returns a classified planning descriptor.
///
/// This service has no Firebase dependency and performs no persistence.
class CatalogueSourceViewClassifier {
  const CatalogueSourceViewClassifier._();

  static CatalogueClassificationResult classify({
    required CatalogueSourceViewDescriptor sourceView,
    required CatalogueSourceViewClassification classification,
  }) {
    final warnings = <CatalogueClassificationWarning>{};

    if (classification.persistedViewType != sourceView.persistedViewType) {
      warnings.add(CatalogueClassificationWarning.persistedTypeMismatch);
      return CatalogueClassificationResult(
        sourceView: sourceView,
        classification: classification,
        warnings: warnings,
        accepted: false,
      );
    }

    if (!_isApplicable(classification)) {
      warnings.add(CatalogueClassificationWarning.classificationNotApplicable);
      return CatalogueClassificationResult(
        sourceView: sourceView,
        classification: classification,
        warnings: warnings,
        accepted: false,
      );
    }

    if (classification.requiresClassification) {
      warnings.add(CatalogueClassificationWarning.classificationRequired);
    }

    return CatalogueClassificationResult(
      sourceView: sourceView,
      classification: classification,
      warnings: warnings,
      accepted: true,
    );
  }

  static CatalogueSourceViewClassification defaultFor(
    CatalogueDesignViewType persistedViewType, {
    CatalogueClassificationSource source =
        CatalogueClassificationSource.systemRule,
  }) {
    switch (persistedViewType) {
      case CatalogueDesignViewType.front:
      case CatalogueDesignViewType.back:
        return CatalogueSourceViewClassification(
          persistedViewType: persistedViewType,
          source: source,
        );
      case CatalogueDesignViewType.side:
        return CatalogueSourceViewClassification(
          persistedViewType: persistedViewType,
          source: source,
          side: CatalogueSideClassification.genericSide,
        );
      case CatalogueDesignViewType.detail:
        return CatalogueSourceViewClassification(
          persistedViewType: persistedViewType,
          source: source,
          detail: CatalogueDetailClassification.genericDetail,
        );
      case CatalogueDesignViewType.combinedFrontBack:
        return CatalogueSourceViewClassification(
          persistedViewType: persistedViewType,
          source: source,
          combined: CatalogueCombinedClassification.frontBackComposite,
        );
      case CatalogueDesignViewType.singleView:
        return CatalogueSourceViewClassification(
          persistedViewType: persistedViewType,
          source: source,
          singleView: CatalogueSingleViewClassification.unclassifiedSingleView,
        );
    }
  }

  static bool _isApplicable(CatalogueSourceViewClassification value) {
    final populated = <bool>[
      value.side != null,
      value.detail != null,
      value.combined != null,
      value.singleView != null,
    ].where((item) => item).length;

    switch (value.persistedViewType) {
      case CatalogueDesignViewType.front:
      case CatalogueDesignViewType.back:
        return populated == 0;
      case CatalogueDesignViewType.side:
        return value.side != null && populated == 1;
      case CatalogueDesignViewType.detail:
        return value.detail != null && populated == 1;
      case CatalogueDesignViewType.combinedFrontBack:
        return value.combined != null && populated == 1;
      case CatalogueDesignViewType.singleView:
        return value.singleView != null && populated == 1;
    }
  }
}
