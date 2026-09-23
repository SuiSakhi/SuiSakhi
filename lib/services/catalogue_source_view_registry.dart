import '../models/catalogue_source_view.dart';

/// Pure-Dart source-view inventory and missing-view planning foundation.
///
/// The registry does not access Firebase, upload assets, create generated
/// views, or alter persisted Catalogue records.
class CatalogueSourceViewRegistry {
  const CatalogueSourceViewRegistry._();

  static const Set<CatalogueCanonicalView> _allCanonicalViews = {
    CatalogueCanonicalView.front,
    CatalogueCanonicalView.back,
    CatalogueCanonicalView.leftSide,
    CatalogueCanonicalView.rightSide,
  };

  static CatalogueCanonicalViewInventory build(
    Iterable<CatalogueSourceViewDescriptor> sources,
  ) {
    final ordered = sources.toList(growable: false)
      ..sort((a, b) {
        final order = a.displayOrder.compareTo(b.displayOrder);
        if (order != 0) return order;
        return a.viewId.compareTo(b.viewId);
      });

    final observed = <CatalogueCanonicalView>{};
    final details = <CatalogueSourceViewDescriptor>[];
    final combined = <CatalogueSourceViewDescriptor>[];
    final unclassified = <CatalogueSourceViewDescriptor>[];
    final warnings = <CatalogueSourceViewWarning>{};
    var hasGenericSide = false;

    for (final source in ordered) {
      final canonical = source.canonicalView;
      if (canonical != null) {
        if (!observed.add(canonical)) {
          warnings.add(CatalogueSourceViewWarning.duplicateCanonicalView);
        }
      }

      if (source.isDetail) details.add(source);

      if (source.isCombined) {
        combined.add(source);
        warnings.add(CatalogueSourceViewWarning.combinedViewExtractionRequired);
      }

      if (source.isGenericSide) {
        hasGenericSide = true;
        warnings.add(CatalogueSourceViewWarning.sideDirectionUnspecified);
      }

      if (source.requiresClassification) {
        unclassified.add(source);
        warnings.add(
          CatalogueSourceViewWarning.singleViewClassificationRequired,
        );
      }
    }

    final primaryCount = ordered.where((item) => item.isPrimary).length;
    if (ordered.isNotEmpty && primaryCount == 0) {
      warnings.add(CatalogueSourceViewWarning.primaryViewMissing);
    }
    if (primaryCount > 1) {
      warnings.add(CatalogueSourceViewWarning.multiplePrimaryViews);
    }

    final readiness = _readiness(
      ordered: ordered,
      observed: observed,
      combined: combined,
      unclassified: unclassified,
    );

    final proposed = _proposedMissingViews(
      readiness: readiness,
      observed: observed,
      hasGenericSide: hasGenericSide,
    );

    if (readiness ==
        CatalogueSourceViewReadiness.insufficientCanonicalEvidence) {
      warnings.add(CatalogueSourceViewWarning.insufficientCanonicalEvidence);
    }

    return CatalogueCanonicalViewInventory(
      orderedSources: ordered,
      observedCanonicalViews: observed,
      supportingDetailViews: details,
      combinedViewSources: combined,
      unclassifiedSources: unclassified,
      proposedMissingViews: proposed,
      warnings: warnings,
      readiness: readiness,
      hasGenericSideEvidence: hasGenericSide,
    );
  }

  static CatalogueSourceViewReadiness _readiness({
    required List<CatalogueSourceViewDescriptor> ordered,
    required Set<CatalogueCanonicalView> observed,
    required List<CatalogueSourceViewDescriptor> combined,
    required List<CatalogueSourceViewDescriptor> unclassified,
  }) {
    if (combined.isNotEmpty && observed.isEmpty) {
      return CatalogueSourceViewReadiness.extractionRequired;
    }
    if (unclassified.isNotEmpty && observed.isEmpty) {
      return CatalogueSourceViewReadiness.classificationRequired;
    }
    if (observed.isEmpty) {
      return CatalogueSourceViewReadiness.insufficientCanonicalEvidence;
    }
    return CatalogueSourceViewReadiness.readyForMissingViewPlanning;
  }

  static Set<CatalogueCanonicalView> _proposedMissingViews({
    required CatalogueSourceViewReadiness readiness,
    required Set<CatalogueCanonicalView> observed,
    required bool hasGenericSide,
  }) {
    if (readiness != CatalogueSourceViewReadiness.readyForMissingViewPlanning) {
      return const {};
    }

    final proposed = _allCanonicalViews.difference(observed);

    // A persisted generic `side` proves that one side view exists, but it does
    // not prove whether that view is left or right. Do not falsely propose
    // both sides or guess which opposite side is missing.
    if (hasGenericSide) {
      proposed
        ..remove(CatalogueCanonicalView.leftSide)
        ..remove(CatalogueCanonicalView.rightSide);
    }

    return proposed;
  }
}
