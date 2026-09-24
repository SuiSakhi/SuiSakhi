import 'package:flutter_test/flutter_test.dart';
import 'package:suisakhi/models/catalogue_design_evidence.dart';
import 'package:suisakhi/models/catalogue_design_view.dart';
import 'package:suisakhi/models/catalogue_source_view.dart';
import 'package:suisakhi/models/catalogue_source_view_classification.dart';
import 'package:suisakhi/services/catalogue_design_evidence_analyzer.dart';

void main() {
  group('CatalogueDesignEvidenceAnalyzer readiness', () {
    test('empty input is insufficient', () {
      final summary = CatalogueDesignEvidenceAnalyzer.analyze(const []);
      expect(
        summary.readiness,
        CatalogueReconstructionReadiness.insufficientEvidence,
      );
      expect(
        summary.nextAction,
        CatalogueEvidenceNextAction.requestCanonicalSource,
      );
      expect(summary.canProposeMissingViews, isFalse);
    });

    test('detail only is insufficient', () {
      final summary = _analyze([
        _evidence(
          'detail',
          CatalogueDesignViewType.detail,
          detail: CatalogueDetailClassification.neckDetail,
        ),
      ]);
      expect(
        summary.readiness,
        CatalogueReconstructionReadiness.insufficientEvidence,
      );
      expect(
        summary.detailCoverage,
        contains(CatalogueDetailClassification.neckDetail),
      );
    });

    test('unclassified single view requires classification', () {
      final summary = _analyze([
        _evidence('single', CatalogueDesignViewType.singleView, primary: true),
      ]);
      expect(
        summary.readiness,
        CatalogueReconstructionReadiness.classificationRequired,
      );
      expect(
        summary.nextAction,
        CatalogueEvidenceNextAction.classifySingleView,
      );
    });

    test('combined front back requires extraction', () {
      final summary = _analyze([
        _evidence(
          'combined',
          CatalogueDesignViewType.combinedFrontBack,
          primary: true,
        ),
      ]);
      expect(
        summary.readiness,
        CatalogueReconstructionReadiness.extractionRequired,
      );
      expect(
        summary.nextAction,
        CatalogueEvidenceNextAction.extractCombinedViews,
      );
    });

    test('front only allows limited proposal', () {
      final summary = _analyze([
        _evidence('front', CatalogueDesignViewType.front, primary: true),
      ]);
      expect(
        summary.readiness,
        CatalogueReconstructionReadiness.limitedViewProposal,
      );
      expect(summary.strength, CatalogueEvidenceStrength.limited);
      expect(summary.reviewLevel, CatalogueEvidenceReviewLevel.enhancedReview);
      expect(summary.proposedMissingViews, {
        CatalogueCanonicalView.back,
        CatalogueCanonicalView.leftSide,
        CatalogueCanonicalView.rightSide,
      });
    });

    test('back only allows limited proposal', () {
      final summary = _analyze([
        _evidence('back', CatalogueDesignViewType.back, primary: true),
      ]);
      expect(
        summary.readiness,
        CatalogueReconstructionReadiness.limitedViewProposal,
      );
      expect(
        summary.proposedMissingViews,
        contains(CatalogueCanonicalView.front),
      );
    });

    test('front and back are canonical proposal evidence', () {
      final summary = _analyze([
        _evidence('front', CatalogueDesignViewType.front, primary: true),
        _evidence('back', CatalogueDesignViewType.back, order: 2),
      ]);
      expect(
        summary.readiness,
        CatalogueReconstructionReadiness.canonicalViewProposal,
      );
      expect(summary.strength, CatalogueEvidenceStrength.moderate);
      expect(summary.proposedMissingViews, {
        CatalogueCanonicalView.leftSide,
        CatalogueCanonicalView.rightSide,
      });
    });

    test('front and directional left side are canonical proposal evidence', () {
      final summary = _analyze([
        _evidence('front', CatalogueDesignViewType.front, primary: true),
        _evidence(
          'left',
          CatalogueDesignViewType.side,
          canonical: CatalogueCanonicalView.leftSide,
          order: 2,
        ),
      ]);
      expect(
        summary.readiness,
        CatalogueReconstructionReadiness.canonicalViewProposal,
      );
      expect(summary.proposedMissingViews, {
        CatalogueCanonicalView.back,
        CatalogueCanonicalView.rightSide,
      });
    });

    test('front plus generic side requires classification', () {
      final summary = _analyze([
        _evidence('front', CatalogueDesignViewType.front, primary: true),
        _evidence('side', CatalogueDesignViewType.side, order: 2),
      ]);
      expect(
        summary.readiness,
        CatalogueReconstructionReadiness.classificationRequired,
      );
      expect(summary.hasGenericSideEvidence, isTrue);
    });

    test('front back generic side is enhanced but preserves warning', () {
      final summary = _analyze([
        _evidence('front', CatalogueDesignViewType.front, primary: true),
        _evidence('back', CatalogueDesignViewType.back, order: 2),
        _evidence('side', CatalogueDesignViewType.side, order: 3),
      ]);
      expect(
        summary.readiness,
        CatalogueReconstructionReadiness.enhancedCanonicalViewProposal,
      );
      expect(
        summary.warnings,
        contains(CatalogueDesignEvidenceWarning.sideDirectionUnspecified),
      );
    });

    test('front back left side is enhanced canonical proposal', () {
      final summary = _analyze([
        _evidence('front', CatalogueDesignViewType.front, primary: true),
        _evidence('back', CatalogueDesignViewType.back, order: 2),
        _evidence(
          'left',
          CatalogueDesignViewType.side,
          canonical: CatalogueCanonicalView.leftSide,
          order: 3,
        ),
      ]);
      expect(
        summary.readiness,
        CatalogueReconstructionReadiness.enhancedCanonicalViewProposal,
      );
      expect(summary.strength, CatalogueEvidenceStrength.strong);
      expect(summary.proposedMissingViews, {CatalogueCanonicalView.rightSide});
    });

    test('all canonical views prepare preview without generation plan', () {
      final summary = _analyze([
        _evidence('front', CatalogueDesignViewType.front, primary: true),
        _evidence('back', CatalogueDesignViewType.back, order: 2),
        _evidence(
          'left',
          CatalogueDesignViewType.side,
          canonical: CatalogueCanonicalView.leftSide,
          order: 3,
        ),
        _evidence(
          'right',
          CatalogueDesignViewType.side,
          canonical: CatalogueCanonicalView.rightSide,
          order: 4,
        ),
      ]);
      expect(
        summary.readiness,
        CatalogueReconstructionReadiness.fullCanonicalViewSetAvailable,
      );
      expect(summary.strength, CatalogueEvidenceStrength.comprehensive);
      expect(
        summary.nextAction,
        CatalogueEvidenceNextAction.prepareCanonicalPreview,
      );
      expect(summary.proposedMissingViews, isEmpty);
      expect(summary.hasCompleteCanonicalSet, isTrue);
    });
  });

  group('detail evidence and consistency checks', () {
    test('three classified details enhance front-only evidence band', () {
      final summary = _analyze([
        _evidence('front', CatalogueDesignViewType.front, primary: true),
        _evidence(
          'neck',
          CatalogueDesignViewType.detail,
          detail: CatalogueDetailClassification.neckDetail,
          order: 2,
        ),
        _evidence(
          'sleeve',
          CatalogueDesignViewType.detail,
          detail: CatalogueDetailClassification.sleeveDetail,
          order: 3,
        ),
        _evidence(
          'border',
          CatalogueDesignViewType.detail,
          detail: CatalogueDetailClassification.borderDetail,
          order: 4,
        ),
      ]);
      expect(
        summary.readiness,
        CatalogueReconstructionReadiness.limitedViewProposal,
      );
      expect(summary.strength, CatalogueEvidenceStrength.moderate);
      expect(summary.detailCoverage, hasLength(3));
    });

    test('two details enhance front-back evidence to strong', () {
      final summary = _analyze([
        _evidence('front', CatalogueDesignViewType.front, primary: true),
        _evidence('back', CatalogueDesignViewType.back, order: 2),
        _evidence(
          'neck',
          CatalogueDesignViewType.detail,
          detail: CatalogueDetailClassification.neckDetail,
          order: 3,
        ),
        _evidence(
          'closure',
          CatalogueDesignViewType.detail,
          detail: CatalogueDetailClassification.closureDetail,
          order: 4,
        ),
      ]);
      expect(summary.strength, CatalogueEvidenceStrength.strong);
    });

    test(
      'neck detail requires neckline consistency',
      () => _expectCheck(
        CatalogueDetailClassification.neckDetail,
        CatalogueVisualConsistencyDimension.neckline,
      ),
    );

    test(
      'sleeve detail requires sleeve consistency',
      () => _expectCheck(
        CatalogueDetailClassification.sleeveDetail,
        CatalogueVisualConsistencyDimension.sleeveType,
      ),
    );

    test(
      'border detail requires border consistency',
      () => _expectCheck(
        CatalogueDetailClassification.borderDetail,
        CatalogueVisualConsistencyDimension.majorBorder,
      ),
    );

    test(
      'embellishment detail requires embellishment consistency',
      () => _expectCheck(
        CatalogueDetailClassification.embellishmentDetail,
        CatalogueVisualConsistencyDimension.majorEmbellishment,
      ),
    );

    test(
      'closure detail requires closure consistency',
      () => _expectCheck(
        CatalogueDetailClassification.closureDetail,
        CatalogueVisualConsistencyDimension.closure,
      ),
    );

    test(
      'construction detail requires panel continuity check',
      () => _expectCheck(
        CatalogueDetailClassification.constructionDetail,
        CatalogueVisualConsistencyDimension.panelOrYokeContinuity,
      ),
    );

    test('base checks always include visual not physical dimensions', () {
      final summary = _analyze([
        _evidence('front', CatalogueDesignViewType.front, primary: true),
      ]);
      expect(
        summary.requiredConsistencyChecks,
        containsAll({
          CatalogueVisualConsistencyDimension.silhouette,
          CatalogueVisualConsistencyDimension.visualProportion,
          CatalogueVisualConsistencyDimension.garmentPieces,
        }),
      );
    });
  });

  group('governance boundaries', () {
    test('summary never marks customer preview ready', () {
      final summary = _analyze([
        _evidence('front', CatalogueDesignViewType.front, primary: true),
        _evidence('back', CatalogueDesignViewType.back, order: 2),
      ]);
      expect(summary.customerPreviewReady, isFalse);
    });

    test('summary never uses measurements', () {
      final summary = _analyze([
        _evidence('front', CatalogueDesignViewType.front, primary: true),
      ]);
      expect(summary.usesMeasurements, isFalse);
    });

    test('summary never creates generated assets', () {
      final summary = _analyze([
        _evidence('front', CatalogueDesignViewType.front, primary: true),
      ]);
      expect(summary.createsGeneratedAssets, isFalse);
    });

    test('duplicate canonical views remain warning evidence', () {
      final summary = _analyze([
        _evidence('front-1', CatalogueDesignViewType.front, primary: true),
        _evidence('front-2', CatalogueDesignViewType.front, order: 2),
      ]);
      expect(
        summary.warnings,
        contains(CatalogueDesignEvidenceWarning.duplicateCanonicalView),
      );
    });

    test('missing primary remains warning evidence', () {
      final summary = _analyze([
        _evidence('front', CatalogueDesignViewType.front),
      ]);
      expect(
        summary.warnings,
        contains(CatalogueDesignEvidenceWarning.primaryViewMissing),
      );
    });

    test('multiple primaries remain warning evidence', () {
      final summary = _analyze([
        _evidence('front', CatalogueDesignViewType.front, primary: true),
        _evidence(
          'back',
          CatalogueDesignViewType.back,
          primary: true,
          order: 2,
        ),
      ]);
      expect(
        summary.warnings,
        contains(CatalogueDesignEvidenceWarning.multiplePrimaryViews),
      );
    });
  });
}

void _expectCheck(
  CatalogueDetailClassification detail,
  CatalogueVisualConsistencyDimension expected,
) {
  final summary = _analyze([
    _evidence('front', CatalogueDesignViewType.front, primary: true),
    _evidence(
      'detail',
      CatalogueDesignViewType.detail,
      detail: detail,
      order: 2,
    ),
  ]);
  expect(summary.requiredConsistencyChecks, contains(expected));
}

CatalogueDesignEvidenceSummary _analyze(
  List<CatalogueClassifiedSourceEvidence> values,
) => CatalogueDesignEvidenceAnalyzer.analyze(values);

CatalogueClassifiedSourceEvidence _evidence(
  String id,
  CatalogueDesignViewType type, {
  CatalogueCanonicalView? canonical,
  CatalogueDetailClassification? detail,
  int order = 1,
  bool primary = false,
}) {
  return CatalogueClassifiedSourceEvidence(
    descriptor: CatalogueSourceViewDescriptor(
      viewId: id,
      persistedViewType: type,
      canonicalView: canonical ?? _defaultCanonical(type),
      origin: CatalogueSourceViewOrigin.designerUploaded,
      evidenceClass: CatalogueViewEvidenceClass.observed,
      displayOrder: order,
      isPrimary: primary,
    ),
    classification: detail == null
        ? null
        : CatalogueSourceViewClassification(
            persistedViewType: CatalogueDesignViewType.detail,
            source: CatalogueClassificationSource.designerDeclared,
            detail: detail,
          ),
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
