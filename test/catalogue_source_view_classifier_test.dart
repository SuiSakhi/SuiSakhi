import 'package:flutter_test/flutter_test.dart';
import 'package:suisakhi/models/catalogue_design_view.dart';
import 'package:suisakhi/models/catalogue_source_view.dart';
import 'package:suisakhi/models/catalogue_source_view_classification.dart';
import 'package:suisakhi/services/catalogue_source_view_classifier.dart';
import 'package:suisakhi/services/catalogue_source_view_registry.dart';

void main() {
  group('CatalogueSourceViewClassifier defaults', () {
    test('generic side is the safe default for persisted side', () {
      final value = CatalogueSourceViewClassifier.defaultFor(
        CatalogueDesignViewType.side,
      );
      expect(value.side, CatalogueSideClassification.genericSide);
      expect(value.requiresClassification, isTrue);
    });

    test('generic detail is the safe default for persisted detail', () {
      final value = CatalogueSourceViewClassifier.defaultFor(
        CatalogueDesignViewType.detail,
      );
      expect(value.detail, CatalogueDetailClassification.genericDetail);
      expect(value.requiresClassification, isTrue);
    });

    test('combined front back defaults to front-back composite', () {
      final value = CatalogueSourceViewClassifier.defaultFor(
        CatalogueDesignViewType.combinedFrontBack,
      );
      expect(
        value.combined,
        CatalogueCombinedClassification.frontBackComposite,
      );
      expect(value.requiresClassification, isFalse);
    });

    test('single view defaults to unclassified', () {
      final value = CatalogueSourceViewClassifier.defaultFor(
        CatalogueDesignViewType.singleView,
      );
      expect(
        value.singleView,
        CatalogueSingleViewClassification.unclassifiedSingleView,
      );
      expect(value.requiresClassification, isTrue);
    });
  });

  group('CatalogueSourceViewClassifier side metadata', () {
    test('left side maps to canonical left side', () {
      final result = _classify(
        type: CatalogueDesignViewType.side,
        classification: const CatalogueSourceViewClassification(
          persistedViewType: CatalogueDesignViewType.side,
          source: CatalogueClassificationSource.designerDeclared,
          side: CatalogueSideClassification.leftSide,
        ),
      );
      expect(result.accepted, isTrue);
      expect(
        result.classifiedDescriptor.canonicalView,
        CatalogueCanonicalView.leftSide,
      );
      expect(result.warnings, isEmpty);
    });

    test('right side maps to canonical right side', () {
      final result = _classify(
        type: CatalogueDesignViewType.side,
        classification: const CatalogueSourceViewClassification(
          persistedViewType: CatalogueDesignViewType.side,
          source: CatalogueClassificationSource.adminDeclared,
          side: CatalogueSideClassification.rightSide,
        ),
      );
      expect(
        result.classifiedDescriptor.canonicalView,
        CatalogueCanonicalView.rightSide,
      );
    });

    test('generic side remains non-directional and needs classification', () {
      final result = _classify(
        type: CatalogueDesignViewType.side,
        classification: const CatalogueSourceViewClassification(
          persistedViewType: CatalogueDesignViewType.side,
          source: CatalogueClassificationSource.systemRule,
          side: CatalogueSideClassification.genericSide,
        ),
      );
      expect(result.accepted, isTrue);
      expect(result.classifiedDescriptor.canonicalView, isNull);
      expect(
        result.warnings,
        contains(CatalogueClassificationWarning.classificationRequired),
      );
    });
  });

  group('CatalogueSourceViewClassifier detail metadata', () {
    for (final detail in [
      CatalogueDetailClassification.neckDetail,
      CatalogueDetailClassification.sleeveDetail,
      CatalogueDetailClassification.borderDetail,
      CatalogueDetailClassification.embellishmentDetail,
      CatalogueDetailClassification.closureDetail,
      CatalogueDetailClassification.constructionDetail,
    ]) {
      test('${detail.name} is accepted for persisted detail', () {
        final result = _classify(
          type: CatalogueDesignViewType.detail,
          classification: CatalogueSourceViewClassification(
            persistedViewType: CatalogueDesignViewType.detail,
            source: CatalogueClassificationSource.designerDeclared,
            detail: detail,
          ),
        );
        expect(result.accepted, isTrue);
        expect(result.classification.isSpecificDetail, isTrue);
        expect(result.classifiedDescriptor.canonicalView, isNull);
      });
    }

    test('generic detail remains supporting evidence', () {
      final result = _classify(
        type: CatalogueDesignViewType.detail,
        classification: const CatalogueSourceViewClassification(
          persistedViewType: CatalogueDesignViewType.detail,
          source: CatalogueClassificationSource.systemRule,
          detail: CatalogueDetailClassification.genericDetail,
        ),
      );
      expect(result.accepted, isTrue);
      expect(
        result.warnings,
        contains(CatalogueClassificationWarning.classificationRequired),
      );
    });
  });

  group('CatalogueSourceViewClassifier single and combined metadata', () {
    test('likely front maps single view to canonical front', () {
      final result = _classify(
        type: CatalogueDesignViewType.singleView,
        classification: const CatalogueSourceViewClassification(
          persistedViewType: CatalogueDesignViewType.singleView,
          source: CatalogueClassificationSource.manuallyCorrected,
          singleView: CatalogueSingleViewClassification.likelyFront,
        ),
      );
      expect(
        result.classifiedDescriptor.canonicalView,
        CatalogueCanonicalView.front,
      );
    });

    test('likely back maps single view to canonical back', () {
      final result = _classify(
        type: CatalogueDesignViewType.singleView,
        classification: const CatalogueSourceViewClassification(
          persistedViewType: CatalogueDesignViewType.singleView,
          source: CatalogueClassificationSource.manuallyCorrected,
          singleView: CatalogueSingleViewClassification.likelyBack,
        ),
      );
      expect(
        result.classifiedDescriptor.canonicalView,
        CatalogueCanonicalView.back,
      );
    });

    test('multi-view composite is accepted as combined metadata', () {
      final result = _classify(
        type: CatalogueDesignViewType.combinedFrontBack,
        classification: const CatalogueSourceViewClassification(
          persistedViewType: CatalogueDesignViewType.combinedFrontBack,
          source: CatalogueClassificationSource.adminDeclared,
          combined: CatalogueCombinedClassification.multiViewComposite,
        ),
      );
      expect(result.accepted, isTrue);
      expect(
        result.classification.combined,
        CatalogueCombinedClassification.multiViewComposite,
      );
    });
  });

  group('CatalogueSourceViewClassifier validation', () {
    test('persisted type mismatch is rejected', () {
      final result = _classify(
        type: CatalogueDesignViewType.side,
        classification: const CatalogueSourceViewClassification(
          persistedViewType: CatalogueDesignViewType.detail,
          source: CatalogueClassificationSource.adminDeclared,
          detail: CatalogueDetailClassification.neckDetail,
        ),
      );
      expect(result.accepted, isFalse);
      expect(
        result.warnings,
        contains(CatalogueClassificationWarning.persistedTypeMismatch),
      );
    });

    test('detail metadata on a side view is rejected', () {
      final result = _classify(
        type: CatalogueDesignViewType.side,
        classification: const CatalogueSourceViewClassification(
          persistedViewType: CatalogueDesignViewType.side,
          source: CatalogueClassificationSource.adminDeclared,
          detail: CatalogueDetailClassification.neckDetail,
        ),
      );
      expect(result.accepted, isFalse);
      expect(
        result.warnings,
        contains(CatalogueClassificationWarning.classificationNotApplicable),
      );
    });

    test('more than one subtype is rejected', () {
      final result = _classify(
        type: CatalogueDesignViewType.detail,
        classification: const CatalogueSourceViewClassification(
          persistedViewType: CatalogueDesignViewType.detail,
          source: CatalogueClassificationSource.adminDeclared,
          detail: CatalogueDetailClassification.neckDetail,
          side: CatalogueSideClassification.leftSide,
        ),
      );
      expect(result.accepted, isFalse);
    });
  });

  group('CatalogueSourceViewClassification serialization', () {
    test('round trips classification metadata', () {
      const original = CatalogueSourceViewClassification(
        persistedViewType: CatalogueDesignViewType.detail,
        source: CatalogueClassificationSource.designerDeclared,
        detail: CatalogueDetailClassification.embellishmentDetail,
        notes: '  Hand-work close-up  ',
      );
      final restored = CatalogueSourceViewClassification.fromMap(
        original.toMap(),
      );
      expect(restored.persistedViewType, original.persistedViewType);
      expect(restored.source, original.source);
      expect(restored.detail, original.detail);
      expect(restored.notes, 'Hand-work close-up');
    });

    test('unknown optional enum values safely become null', () {
      final restored = CatalogueSourceViewClassification.fromMap({
        'persistedViewType': 'detail',
        'source': 'systemRule',
        'detail': 'futureUnknownDetail',
      });
      expect(restored.persistedViewType, CatalogueDesignViewType.detail);
      expect(restored.detail, isNull);
      expect(restored.requiresClassification, isTrue);
    });
  });

  test('classified directional side improves B-1 registry planning', () {
    const classifierInput = CatalogueSourceViewClassification(
      persistedViewType: CatalogueDesignViewType.side,
      source: CatalogueClassificationSource.designerDeclared,
      side: CatalogueSideClassification.leftSide,
    );
    final sideResult = _classify(
      id: 'side-left',
      type: CatalogueDesignViewType.side,
      classification: classifierInput,
      order: 2,
    );
    final inventory = CatalogueSourceViewRegistry.build([
      _descriptor(
        id: 'front-1',
        type: CatalogueDesignViewType.front,
        primary: true,
      ),
      sideResult.classifiedDescriptor,
    ]);
    expect(inventory.observedCanonicalViews, {
      CatalogueCanonicalView.front,
      CatalogueCanonicalView.leftSide,
    });
    expect(inventory.proposedMissingViews, {
      CatalogueCanonicalView.back,
      CatalogueCanonicalView.rightSide,
    });
  });
}

CatalogueClassificationResult _classify({
  String id = 'view-1',
  required CatalogueDesignViewType type,
  required CatalogueSourceViewClassification classification,
  int order = 1,
}) {
  return CatalogueSourceViewClassifier.classify(
    sourceView: _descriptor(id: id, type: type, order: order),
    classification: classification,
  );
}

CatalogueSourceViewDescriptor _descriptor({
  required String id,
  required CatalogueDesignViewType type,
  int order = 1,
  bool primary = false,
}) {
  return CatalogueSourceViewDescriptor(
    viewId: id,
    persistedViewType: type,
    canonicalView: _defaultCanonical(type),
    origin: CatalogueSourceViewOrigin.designerUploaded,
    evidenceClass: CatalogueViewEvidenceClass.observed,
    displayOrder: order,
    isPrimary: primary,
  );
}

CatalogueCanonicalView? _defaultCanonical(CatalogueDesignViewType type) {
  switch (type) {
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
