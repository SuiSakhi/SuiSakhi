import 'catalogue_design_view.dart';
import 'catalogue_source_view.dart';

/// Optional classification layered above the persisted C1.3
/// [CatalogueDesignViewType] value.
///
/// This metadata does not rename or replace existing Firestore enum values.
enum CatalogueSideClassification { genericSide, leftSide, rightSide }

enum CatalogueDetailClassification {
  genericDetail,
  neckDetail,
  sleeveDetail,
  borderDetail,
  embellishmentDetail,
  closureDetail,
  constructionDetail,
}

enum CatalogueCombinedClassification { frontBackComposite, multiViewComposite }

enum CatalogueSingleViewClassification {
  unclassifiedSingleView,
  likelyFront,
  likelyBack,
}

enum CatalogueClassificationSource {
  designerDeclared,
  adminDeclared,
  systemRule,
  manuallyCorrected,
}

enum CatalogueClassificationWarning {
  classificationNotApplicable,
  classificationRequired,
  persistedTypeMismatch,
}

extension CatalogueClassificationWarningX on CatalogueClassificationWarning {
  String get code {
    switch (this) {
      case CatalogueClassificationWarning.classificationNotApplicable:
        return 'CLASSIFICATION_NOT_APPLICABLE';
      case CatalogueClassificationWarning.classificationRequired:
        return 'CLASSIFICATION_REQUIRED';
      case CatalogueClassificationWarning.persistedTypeMismatch:
        return 'PERSISTED_TYPE_MISMATCH';
    }
  }
}

/// Backward-compatible source-view classification metadata.
class CatalogueSourceViewClassification {
  const CatalogueSourceViewClassification({
    required this.persistedViewType,
    required this.source,
    this.side,
    this.detail,
    this.combined,
    this.singleView,
    this.notes,
  });

  final CatalogueDesignViewType persistedViewType;
  final CatalogueClassificationSource source;
  final CatalogueSideClassification? side;
  final CatalogueDetailClassification? detail;
  final CatalogueCombinedClassification? combined;
  final CatalogueSingleViewClassification? singleView;
  final String? notes;

  CatalogueCanonicalView? get canonicalView {
    switch (persistedViewType) {
      case CatalogueDesignViewType.front:
        return CatalogueCanonicalView.front;
      case CatalogueDesignViewType.back:
        return CatalogueCanonicalView.back;
      case CatalogueDesignViewType.side:
        switch (side) {
          case CatalogueSideClassification.leftSide:
            return CatalogueCanonicalView.leftSide;
          case CatalogueSideClassification.rightSide:
            return CatalogueCanonicalView.rightSide;
          case CatalogueSideClassification.genericSide:
          case null:
            return null;
        }
      case CatalogueDesignViewType.singleView:
        switch (singleView) {
          case CatalogueSingleViewClassification.likelyFront:
            return CatalogueCanonicalView.front;
          case CatalogueSingleViewClassification.likelyBack:
            return CatalogueCanonicalView.back;
          case CatalogueSingleViewClassification.unclassifiedSingleView:
          case null:
            return null;
        }
      case CatalogueDesignViewType.detail:
      case CatalogueDesignViewType.combinedFrontBack:
        return null;
    }
  }

  bool get isSpecificSide =>
      side == CatalogueSideClassification.leftSide ||
      side == CatalogueSideClassification.rightSide;

  bool get isSpecificDetail =>
      detail != null && detail != CatalogueDetailClassification.genericDetail;

  bool get requiresClassification {
    switch (persistedViewType) {
      case CatalogueDesignViewType.side:
        return side == null || side == CatalogueSideClassification.genericSide;
      case CatalogueDesignViewType.detail:
        return detail == null ||
            detail == CatalogueDetailClassification.genericDetail;
      case CatalogueDesignViewType.singleView:
        return singleView == null ||
            singleView ==
                CatalogueSingleViewClassification.unclassifiedSingleView;
      case CatalogueDesignViewType.front:
      case CatalogueDesignViewType.back:
      case CatalogueDesignViewType.combinedFrontBack:
        return false;
    }
  }

  Map<String, dynamic> toMap() => {
    'persistedViewType': persistedViewType.name,
    'source': source.name,
    'side': side?.name,
    'detail': detail?.name,
    'combined': combined?.name,
    'singleView': singleView?.name,
    'notes': _text(notes),
  };

  factory CatalogueSourceViewClassification.fromMap(Map<String, dynamic> data) {
    return CatalogueSourceViewClassification(
      persistedViewType: _enumValue(
        CatalogueDesignViewType.values,
        data['persistedViewType'],
        CatalogueDesignViewType.singleView,
      ),
      source: _enumValue(
        CatalogueClassificationSource.values,
        data['source'],
        CatalogueClassificationSource.systemRule,
      ),
      side: _nullableEnum(CatalogueSideClassification.values, data['side']),
      detail: _nullableEnum(
        CatalogueDetailClassification.values,
        data['detail'],
      ),
      combined: _nullableEnum(
        CatalogueCombinedClassification.values,
        data['combined'],
      ),
      singleView: _nullableEnum(
        CatalogueSingleViewClassification.values,
        data['singleView'],
      ),
      notes: _text(data['notes']?.toString()),
    );
  }

  static T _enumValue<T extends Enum>(
    List<T> values,
    Object? value,
    T fallback,
  ) {
    final name = value?.toString();
    for (final item in values) {
      if (item.name == name) return item;
    }
    return fallback;
  }

  static T? _nullableEnum<T extends Enum>(List<T> values, Object? value) {
    final name = value?.toString();
    for (final item in values) {
      if (item.name == name) return item;
    }
    return null;
  }

  static String? _text(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }
}

class CatalogueClassificationResult {
  CatalogueClassificationResult({
    required this.sourceView,
    required this.classification,
    required Set<CatalogueClassificationWarning> warnings,
    required this.accepted,
  }) : warnings = Set.unmodifiable(warnings);

  final CatalogueSourceViewDescriptor sourceView;
  final CatalogueSourceViewClassification classification;
  final Set<CatalogueClassificationWarning> warnings;
  final bool accepted;

  CatalogueSourceViewDescriptor get classifiedDescriptor =>
      CatalogueSourceViewDescriptor(
        viewId: sourceView.viewId,
        persistedViewType: sourceView.persistedViewType,
        canonicalView: accepted
            ? classification.canonicalView ?? sourceView.canonicalView
            : sourceView.canonicalView,
        origin: sourceView.origin,
        evidenceClass: sourceView.evidenceClass,
        displayOrder: sourceView.displayOrder,
        isPrimary: sourceView.isPrimary,
        title: sourceView.title,
      );
}
