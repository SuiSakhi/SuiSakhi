import 'package:flutter_test/flutter_test.dart';
import 'package:suisakhi/models/catalogue_design_evidence.dart';
import 'package:suisakhi/models/catalogue_source_view.dart';
import 'package:suisakhi/models/catalogue_view_proposal.dart';
import 'package:suisakhi/services/catalogue_view_proposal_planner.dart';

void main() {
  group('CatalogueViewProposalPlanner actionable plans', () {
    test('front only requests back and both sides', () {
      final plan = _build(
        _summary(
          readiness: CatalogueReconstructionReadiness.limitedViewProposal,
          observed: {CatalogueCanonicalView.front},
          missing: {
            CatalogueCanonicalView.back,
            CatalogueCanonicalView.leftSide,
            CatalogueCanonicalView.rightSide,
          },
          review: CatalogueEvidenceReviewLevel.enhancedReview,
        ),
      );
      expect(plan.status, CatalogueViewProposalStatus.planned);
      expect(_targetViews(plan), [
        CatalogueCanonicalView.back,
        CatalogueCanonicalView.leftSide,
        CatalogueCanonicalView.rightSide,
      ]);
      expect(
        plan.reviewPolicy,
        CatalogueViewProposalReviewPolicy.enhancedReview,
      );
    });

    test('back only includes front target', () {
      final plan = _build(
        _summary(
          readiness: CatalogueReconstructionReadiness.limitedViewProposal,
          observed: {CatalogueCanonicalView.back},
          missing: {
            CatalogueCanonicalView.front,
            CatalogueCanonicalView.leftSide,
            CatalogueCanonicalView.rightSide,
          },
          review: CatalogueEvidenceReviewLevel.enhancedReview,
        ),
      );
      expect(_targetViews(plan), contains(CatalogueCanonicalView.front));
    });

    test('front and back request both sides with standard review', () {
      final plan = _build(
        _summary(
          readiness: CatalogueReconstructionReadiness.canonicalViewProposal,
          observed: {CatalogueCanonicalView.front, CatalogueCanonicalView.back},
          missing: {
            CatalogueCanonicalView.leftSide,
            CatalogueCanonicalView.rightSide,
          },
          review: CatalogueEvidenceReviewLevel.standardReview,
        ),
      );
      expect(plan.targets, hasLength(2));
      expect(
        plan.reviewPolicy,
        CatalogueViewProposalReviewPolicy.standardReview,
      );
      expect(
        plan.targets.first.evidenceClass,
        CatalogueViewProposalEvidenceClass.partiallyObserved,
      );
    });

    test('front back left side requests only right side', () {
      final plan = _build(
        _summary(
          readiness:
              CatalogueReconstructionReadiness.enhancedCanonicalViewProposal,
          observed: {
            CatalogueCanonicalView.front,
            CatalogueCanonicalView.back,
            CatalogueCanonicalView.leftSide,
          },
          missing: {CatalogueCanonicalView.rightSide},
          review: CatalogueEvidenceReviewLevel.focusedReview,
        ),
      );
      expect(_targetViews(plan), [CatalogueCanonicalView.rightSide]);
      expect(
        plan.reviewPolicy,
        CatalogueViewProposalReviewPolicy.focusedReview,
      );
    });

    test('target preserves required consistency checks', () {
      final checks = {
        CatalogueVisualConsistencyDimension.neckline,
        CatalogueVisualConsistencyDimension.sleeveType,
        CatalogueVisualConsistencyDimension.silhouette,
      };
      final plan = _build(
        _summary(
          readiness: CatalogueReconstructionReadiness.canonicalViewProposal,
          observed: {CatalogueCanonicalView.front, CatalogueCanonicalView.back},
          missing: {CatalogueCanonicalView.leftSide},
          review: CatalogueEvidenceReviewLevel.standardReview,
          checks: checks,
        ),
      );
      expect(plan.targets.single.consistencyChecks, checks);
    });

    test('single observed canonical view marks targets inferred', () {
      final plan = _build(
        _summary(
          readiness: CatalogueReconstructionReadiness.limitedViewProposal,
          observed: {CatalogueCanonicalView.front},
          missing: {CatalogueCanonicalView.back},
          review: CatalogueEvidenceReviewLevel.enhancedReview,
        ),
      );
      expect(
        plan.targets.single.evidenceClass,
        CatalogueViewProposalEvidenceClass.inferred,
      );
    });
  });

  group('blocked plans', () {
    test('insufficient evidence is blocked', () {
      final plan = _build(
        _summary(
          readiness: CatalogueReconstructionReadiness.insufficientEvidence,
          observed: const {},
          missing: const {},
          review: CatalogueEvidenceReviewLevel.sourceCorrectionRequired,
        ),
      );
      expect(
        plan.blockReason,
        CatalogueViewProposalBlockReason.insufficientEvidence,
      );
      expect(plan.isActionable, isFalse);
    });

    test('classification required is blocked', () {
      final plan = _build(
        _summary(
          readiness: CatalogueReconstructionReadiness.classificationRequired,
          observed: {CatalogueCanonicalView.front},
          missing: {CatalogueCanonicalView.back},
          review: CatalogueEvidenceReviewLevel.sourceCorrectionRequired,
        ),
      );
      expect(
        plan.blockReason,
        CatalogueViewProposalBlockReason.classificationRequired,
      );
      expect(plan.targets, isEmpty);
    });

    test('extraction required is blocked', () {
      final plan = _build(
        _summary(
          readiness: CatalogueReconstructionReadiness.extractionRequired,
          observed: const {},
          missing: const {},
          review: CatalogueEvidenceReviewLevel.sourceCorrectionRequired,
        ),
      );
      expect(
        plan.blockReason,
        CatalogueViewProposalBlockReason.extractionRequired,
      );
    });

    test('complete canonical set requires no proposal', () {
      final plan = _build(
        _summary(
          readiness:
              CatalogueReconstructionReadiness.fullCanonicalViewSetAvailable,
          observed: CatalogueCanonicalView.values.toSet(),
          missing: const {},
          review: CatalogueEvidenceReviewLevel.focusedReview,
        ),
      );
      expect(
        plan.blockReason,
        CatalogueViewProposalBlockReason.noMissingCanonicalViews,
      );
      expect(plan.targets, isEmpty);
    });
  });

  group('mandatory restrictions and boundaries', () {
    late CatalogueViewProposalRequest plan;
    setUp(() {
      plan = _build(
        _summary(
          readiness: CatalogueReconstructionReadiness.limitedViewProposal,
          observed: {CatalogueCanonicalView.front},
          missing: {CatalogueCanonicalView.back},
          review: CatalogueEvidenceReviewLevel.enhancedReview,
        ),
      );
    });

    for (final restriction in CatalogueViewProposalRestriction.values) {
      test('includes ${restriction.name}', () {
        expect(plan.restrictions, contains(restriction));
      });
    }

    test(
      'does not create generated assets',
      () => expect(plan.createsGeneratedAssets, isFalse),
    );
    test('does not write Firebase', () => expect(plan.writesFirebase, isFalse));
    test(
      'does not use measurements',
      () => expect(plan.usesMeasurements, isFalse),
    );
    test(
      'is not customer visible',
      () => expect(plan.customerVisible, isFalse),
    );
  });

  group('identity and normalization', () {
    test('source IDs are trimmed, deduplicated and sorted', () {
      final plan = _build(
        _summary(
          readiness: CatalogueReconstructionReadiness.limitedViewProposal,
          observed: {CatalogueCanonicalView.front},
          missing: {CatalogueCanonicalView.back},
          review: CatalogueEvidenceReviewLevel.enhancedReview,
        ),
        sources: [' z ', 'a', 'a', ''],
      );
      expect(plan.sourceViewIds, ['a', 'z']);
    });

    test('request identity is deterministic across source order', () {
      final summary = _summary(
        readiness: CatalogueReconstructionReadiness.canonicalViewProposal,
        observed: {CatalogueCanonicalView.front, CatalogueCanonicalView.back},
        missing: {CatalogueCanonicalView.leftSide},
        review: CatalogueEvidenceReviewLevel.standardReview,
      );
      final first = _build(summary, sources: ['back', 'front']);
      final second = _build(summary, sources: ['front', 'back']);
      expect(first.requestId, second.requestId);
    });

    test('request identity changes when missing target changes', () {
      final first = _build(
        _summary(
          readiness: CatalogueReconstructionReadiness.canonicalViewProposal,
          observed: {CatalogueCanonicalView.front, CatalogueCanonicalView.back},
          missing: {CatalogueCanonicalView.leftSide},
          review: CatalogueEvidenceReviewLevel.standardReview,
        ),
      );
      final second = _build(
        _summary(
          readiness: CatalogueReconstructionReadiness.canonicalViewProposal,
          observed: {CatalogueCanonicalView.front, CatalogueCanonicalView.back},
          missing: {CatalogueCanonicalView.rightSide},
          review: CatalogueEvidenceReviewLevel.standardReview,
        ),
      );
      expect(first.requestId, isNot(second.requestId));
    });

    test('empty design ID is rejected', () {
      expect(
        () => CatalogueViewProposalPlanner.build(
          designId: ' ',
          versionId: 'version-1',
          sourceViewIds: const ['front'],
          evidence: _summary(
            readiness: CatalogueReconstructionReadiness.limitedViewProposal,
            observed: {CatalogueCanonicalView.front},
            missing: {CatalogueCanonicalView.back},
            review: CatalogueEvidenceReviewLevel.enhancedReview,
          ),
        ),
        throwsArgumentError,
      );
    });

    test('empty version ID is rejected', () {
      expect(
        () => CatalogueViewProposalPlanner.build(
          designId: 'design-1',
          versionId: '',
          sourceViewIds: const ['front'],
          evidence: _summary(
            readiness: CatalogueReconstructionReadiness.limitedViewProposal,
            observed: {CatalogueCanonicalView.front},
            missing: {CatalogueCanonicalView.back},
            review: CatalogueEvidenceReviewLevel.enhancedReview,
          ),
        ),
        throwsArgumentError,
      );
    });
  });
}

CatalogueViewProposalRequest _build(
  CatalogueDesignEvidenceSummary summary, {
  List<String> sources = const ['front-source'],
}) {
  return CatalogueViewProposalPlanner.build(
    designId: 'design-1',
    versionId: 'version-1',
    sourceViewIds: sources,
    evidence: summary,
  );
}

List<CatalogueCanonicalView> _targetViews(CatalogueViewProposalRequest plan) =>
    plan.targets.map((item) => item.targetView).toList();

CatalogueDesignEvidenceSummary _summary({
  required CatalogueReconstructionReadiness readiness,
  required Set<CatalogueCanonicalView> observed,
  required Set<CatalogueCanonicalView> missing,
  required CatalogueEvidenceReviewLevel review,
  Set<CatalogueVisualConsistencyDimension> checks = const {
    CatalogueVisualConsistencyDimension.silhouette,
    CatalogueVisualConsistencyDimension.visualProportion,
  },
}) {
  return CatalogueDesignEvidenceSummary(
    readiness: readiness,
    strength: CatalogueEvidenceStrength.moderate,
    reviewLevel: review,
    nextAction: CatalogueEvidenceNextAction.proposeMissingCanonicalViews,
    observedCanonicalViews: observed,
    proposedMissingViews: missing,
    detailCoverage: const {},
    requiredConsistencyChecks: checks,
    warnings: const {},
    sourceCount: observed.length,
    canonicalSourceCount: observed.length,
    detailSourceCount: 0,
    hasGenericSideEvidence: false,
  );
}
