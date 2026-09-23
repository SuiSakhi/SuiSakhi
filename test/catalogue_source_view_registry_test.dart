import 'package:flutter_test/flutter_test.dart';
import 'package:suisakhi/models/catalogue_design_view.dart';
import 'package:suisakhi/models/catalogue_source_view.dart';
import 'package:suisakhi/services/catalogue_source_view_registry.dart';

void main() {
  group('CatalogueSourceViewRegistry', () {
    test('front only proposes back, left side and right side', () {
      final inventory = CatalogueSourceViewRegistry.build([
        _source('front-1', type: CatalogueDesignViewType.front, primary: true),
      ]);

      expect(inventory.observedCanonicalViews, {CatalogueCanonicalView.front});
      expect(inventory.proposedMissingViews, {
        CatalogueCanonicalView.back,
        CatalogueCanonicalView.leftSide,
        CatalogueCanonicalView.rightSide,
      });
      expect(
        inventory.readiness,
        CatalogueSourceViewReadiness.readyForMissingViewPlanning,
      );
      expect(inventory.createsGeneratedViews, isFalse);
    });

    test('back only proposes front and both sides', () {
      final inventory = CatalogueSourceViewRegistry.build([
        _source('back-1', type: CatalogueDesignViewType.back, primary: true),
      ]);

      expect(inventory.proposedMissingViews, {
        CatalogueCanonicalView.front,
        CatalogueCanonicalView.leftSide,
        CatalogueCanonicalView.rightSide,
      });
    });

    test('front and back propose both directional sides', () {
      final inventory = CatalogueSourceViewRegistry.build([
        _source('front-1', type: CatalogueDesignViewType.front, primary: true),
        _source('back-1', type: CatalogueDesignViewType.back, order: 2),
      ]);

      expect(inventory.observedCanonicalViews, {
        CatalogueCanonicalView.front,
        CatalogueCanonicalView.back,
      });
      expect(inventory.proposedMissingViews, {
        CatalogueCanonicalView.leftSide,
        CatalogueCanonicalView.rightSide,
      });
    });

    test('front plus generic side proposes only back', () {
      final inventory = CatalogueSourceViewRegistry.build([
        _source('front-1', type: CatalogueDesignViewType.front, primary: true),
        _source('side-1', type: CatalogueDesignViewType.side, order: 2),
      ]);

      expect(inventory.proposedMissingViews, {CatalogueCanonicalView.back});
      expect(inventory.hasGenericSideEvidence, isTrue);
      expect(
        inventory.warnings,
        contains(CatalogueSourceViewWarning.sideDirectionUnspecified),
      );
    });

    test('front, back and generic side do not guess opposite side', () {
      final inventory = CatalogueSourceViewRegistry.build([
        _source('front-1', type: CatalogueDesignViewType.front, primary: true),
        _source('back-1', type: CatalogueDesignViewType.back, order: 2),
        _source('side-1', type: CatalogueDesignViewType.side, order: 3),
      ]);

      expect(inventory.proposedMissingViews, isEmpty);
      expect(
        inventory.warnings,
        contains(CatalogueSourceViewWarning.sideDirectionUnspecified),
      );
    });

    test('directional side hint supports safe opposite-side planning', () {
      final inventory = CatalogueSourceViewRegistry.build([
        _source('front-1', type: CatalogueDesignViewType.front, primary: true),
        _source(
          'side-left',
          type: CatalogueDesignViewType.side,
          order: 2,
          canonical: CatalogueCanonicalView.leftSide,
        ),
      ]);

      expect(inventory.observedCanonicalViews, {
        CatalogueCanonicalView.front,
        CatalogueCanonicalView.leftSide,
      });
      expect(inventory.proposedMissingViews, {
        CatalogueCanonicalView.back,
        CatalogueCanonicalView.rightSide,
      });
      expect(inventory.hasGenericSideEvidence, isFalse);
    });

    test('combined front back requires extraction', () {
      final inventory = CatalogueSourceViewRegistry.build([
        _source(
          'combined-1',
          type: CatalogueDesignViewType.combinedFrontBack,
          primary: true,
        ),
      ]);

      expect(
        inventory.readiness,
        CatalogueSourceViewReadiness.extractionRequired,
      );
      expect(inventory.proposedMissingViews, isEmpty);
      expect(
        inventory.warnings,
        contains(CatalogueSourceViewWarning.combinedViewExtractionRequired),
      );
    });

    test('single view requires classification', () {
      final inventory = CatalogueSourceViewRegistry.build([
        _source(
          'single-1',
          type: CatalogueDesignViewType.singleView,
          primary: true,
        ),
      ]);

      expect(
        inventory.readiness,
        CatalogueSourceViewReadiness.classificationRequired,
      );
      expect(inventory.proposedMissingViews, isEmpty);
      expect(inventory.unclassifiedSources, hasLength(1));
    });

    test('detail only is supporting evidence, not canonical evidence', () {
      final inventory = CatalogueSourceViewRegistry.build([
        _source(
          'detail-1',
          type: CatalogueDesignViewType.detail,
          primary: false,
        ),
      ]);

      expect(
        inventory.readiness,
        CatalogueSourceViewReadiness.insufficientCanonicalEvidence,
      );
      expect(inventory.supportingDetailViews, hasLength(1));
      expect(inventory.proposedMissingViews, isEmpty);
    });

    test('duplicate canonical view emits warning', () {
      final inventory = CatalogueSourceViewRegistry.build([
        _source(
          'front-2',
          type: CatalogueDesignViewType.front,
          primary: true,
          order: 2,
        ),
        _source('front-1', type: CatalogueDesignViewType.front, order: 1),
      ]);

      expect(
        inventory.warnings,
        contains(CatalogueSourceViewWarning.duplicateCanonicalView),
      );
      expect(inventory.observedCanonicalViews, {CatalogueCanonicalView.front});
    });

    test('sources are sorted by display order then view id', () {
      final inventory = CatalogueSourceViewRegistry.build([
        _source('back-2', type: CatalogueDesignViewType.back, order: 2),
        _source('front-2', type: CatalogueDesignViewType.front, order: 1),
        _source(
          'front-1',
          type: CatalogueDesignViewType.front,
          order: 1,
          primary: true,
        ),
      ]);

      expect(inventory.orderedSources.map((item) => item.viewId).toList(), [
        'front-1',
        'front-2',
        'back-2',
      ]);
    });

    test('empty input has insufficient evidence and no generated data', () {
      final inventory = CatalogueSourceViewRegistry.build(const []);

      expect(
        inventory.readiness,
        CatalogueSourceViewReadiness.insufficientCanonicalEvidence,
      );
      expect(inventory.observedCanonicalViews, isEmpty);
      expect(inventory.proposedMissingViews, isEmpty);
      expect(inventory.createsGeneratedViews, isFalse);
    });

    test('missing primary source emits warning', () {
      final inventory = CatalogueSourceViewRegistry.build([
        _source('front-1', type: CatalogueDesignViewType.front),
      ]);

      expect(
        inventory.warnings,
        contains(CatalogueSourceViewWarning.primaryViewMissing),
      );
    });

    test('multiple primary sources emit warning', () {
      final inventory = CatalogueSourceViewRegistry.build([
        _source('front-1', type: CatalogueDesignViewType.front, primary: true),
        _source(
          'back-1',
          type: CatalogueDesignViewType.back,
          primary: true,
          order: 2,
        ),
      ]);

      expect(
        inventory.warnings,
        contains(CatalogueSourceViewWarning.multiplePrimaryViews),
      );
    });

    test('details remain preserved alongside canonical evidence', () {
      final inventory = CatalogueSourceViewRegistry.build([
        _source('front-1', type: CatalogueDesignViewType.front, primary: true),
        _source('detail-neck', type: CatalogueDesignViewType.detail, order: 2),
        _source(
          'detail-border',
          type: CatalogueDesignViewType.detail,
          order: 3,
        ),
      ]);

      expect(inventory.supportingDetailViews, hasLength(2));
      expect(inventory.proposedMissingViews, {
        CatalogueCanonicalView.back,
        CatalogueCanonicalView.leftSide,
        CatalogueCanonicalView.rightSide,
      });
    });
  });
}

CatalogueSourceViewDescriptor _source(
  String id, {
  required CatalogueDesignViewType type,
  CatalogueCanonicalView? canonical,
  int order = 1,
  bool primary = false,
}) {
  return CatalogueSourceViewDescriptor(
    viewId: id,
    persistedViewType: type,
    canonicalView: canonical ?? _defaultCanonical(type),
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
