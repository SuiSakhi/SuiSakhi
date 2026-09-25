import 'package:flutter_test/flutter_test.dart';
import 'package:suisakhi/models/catalogue_design_evidence.dart';
import 'package:suisakhi/models/catalogue_reconstruction_foundation.dart';
import 'package:suisakhi/models/catalogue_source_view.dart';
import 'package:suisakhi/services/catalogue_reconstruction_evaluator.dart';
import 'package:suisakhi/services/catalogue_reconstruction_fixture_registry.dart';

void main() {
  group('CatalogueReconstructionFixtureRegistry', () {
    test('simple blouse fixture is registered with frozen identity', () {
      final fixture =
          CatalogueReconstructionFixtureRegistry.simpleBlouseFrontV1();
      expect(fixture.fixtureId, 'simple-blouse-front-v1');
      expect(fixture.garmentProfileCode, 'blouseV1');
      expect(fixture.sourceView, CatalogueCanonicalView.front);
    });

    test('simple blouse allows back and both side targets', () {
      final fixture =
          CatalogueReconstructionFixtureRegistry.simpleBlouseFrontV1();
      expect(fixture.allowedTargets, {
        CatalogueCanonicalView.back,
        CatalogueCanonicalView.leftSide,
        CatalogueCanonicalView.rightSide,
      });
    });

    test('fixture is monochrome and local only', () {
      final fixture =
          CatalogueReconstructionFixtureRegistry.simpleBlouseFrontV1();
      expect(fixture.monochrome, isTrue);
      expect(fixture.localOnly, isTrue);
      CatalogueReconstructionFixtureRegistry.validate(fixture);
    });

    test('fixture includes visual consistency dimensions', () {
      final fixture =
          CatalogueReconstructionFixtureRegistry.simpleBlouseFrontV1();
      expect(
        fixture.evaluationDimensions,
        containsAll({
          CatalogueVisualConsistencyDimension.neckline,
          CatalogueVisualConsistencyDimension.sleeveType,
          CatalogueVisualConsistencyDimension.silhouette,
          CatalogueVisualConsistencyDimension.visualProportion,
          CatalogueVisualConsistencyDimension.garmentPieces,
        }),
      );
    });

    test('empty fixture ID is rejected', () {
      expect(
        () => CatalogueReconstructionFixtureRegistry.validate(
          _fixture(fixtureId: ''),
        ),
        throwsArgumentError,
      );
    });

    test('empty source path is rejected', () {
      expect(
        () => CatalogueReconstructionFixtureRegistry.validate(
          _fixture(sourceAssetPath: ''),
        ),
        throwsArgumentError,
      );
    });

    test('non-monochrome fixture is rejected in E-1', () {
      expect(
        () => CatalogueReconstructionFixtureRegistry.validate(
          _fixture(monochrome: false),
        ),
        throwsStateError,
      );
    });

    test('non-local fixture is rejected in E-1', () {
      expect(
        () => CatalogueReconstructionFixtureRegistry.validate(
          _fixture(localOnly: false),
        ),
        throwsStateError,
      );
    });

    test('empty target set is rejected', () {
      expect(
        () => CatalogueReconstructionFixtureRegistry.validate(
          _fixture(allowedTargets: const {}),
        ),
        throwsStateError,
      );
    });

    test('source cannot also be target', () {
      expect(
        () => CatalogueReconstructionFixtureRegistry.validate(
          _fixture(allowedTargets: const {CatalogueCanonicalView.front}),
        ),
        throwsStateError,
      );
    });
  });

  group('CatalogueGeneratedViewMetadata', () {
    test('generated view is never observed truth', () {
      final metadata = _generated();
      expect(metadata.provenance, CatalogueReconstructionProvenance.generated);
      expect(metadata.isObservedTruth, isFalse);
    });

    test('generated view begins with review required', () {
      expect(
        _generated().reviewStatus,
        CatalogueGeneratedViewReviewStatus.reviewRequired,
      );
    });

    test('review-required generated view is not customer visible', () {
      expect(_generated().customerVisible, isFalse);
    });

    test('approved metadata may be customer visible only after approval', () {
      final metadata = _generated(
        reviewStatus: CatalogueGeneratedViewReviewStatus.approved,
      );
      expect(metadata.customerVisible, isTrue);
    });

    test('metadata contains no image bytes and uses no measurements', () {
      final metadata = _generated();
      expect(metadata.containsImageBytes, isFalse);
      expect(metadata.usesMeasurements, isFalse);
    });

    test('source views and checks are immutable snapshots', () {
      final sources = <CatalogueCanonicalView>{CatalogueCanonicalView.front};
      final checks = <CatalogueVisualConsistencyDimension>{
        CatalogueVisualConsistencyDimension.silhouette,
      };
      final metadata = _generated(sourceViews: sources, requiredChecks: checks);
      sources.add(CatalogueCanonicalView.back);
      checks.add(CatalogueVisualConsistencyDimension.neckline);
      expect(metadata.sourceViews, {CatalogueCanonicalView.front});
      expect(metadata.requiredChecks, {
        CatalogueVisualConsistencyDimension.silhouette,
      });
    });
  });

  group('CatalogueReconstructionEvaluator', () {
    test('creates one review item for every required check', () {
      final metadata = _generated(
        requiredChecks: const {
          CatalogueVisualConsistencyDimension.neckline,
          CatalogueVisualConsistencyDimension.sleeveType,
          CatalogueVisualConsistencyDimension.silhouette,
        },
      );
      final result = CatalogueReconstructionEvaluator.createReviewRequired(
        metadata,
      );
      expect(result.evaluations, hasLength(3));
      expect(
        result.evaluations.map((item) => item.dimension).toSet(),
        metadata.requiredChecks,
      );
    });

    test('evaluation always requires human review', () {
      final result = CatalogueReconstructionEvaluator.createReviewRequired(
        _generated(),
      );
      expect(result.overallOutcome, CatalogueEvaluationOutcome.reviewRequired);
      expect(result.requiresHumanReview, isTrue);
      expect(result.approvedAutomatically, isFalse);
    });

    test('evaluation order is deterministic', () {
      final metadata = _generated(
        requiredChecks: const {
          CatalogueVisualConsistencyDimension.visualProportion,
          CatalogueVisualConsistencyDimension.neckline,
          CatalogueVisualConsistencyDimension.silhouette,
        },
      );
      final first = CatalogueReconstructionEvaluator.createReviewRequired(
        metadata,
      );
      final second = CatalogueReconstructionEvaluator.createReviewRequired(
        metadata,
      );
      expect(
        first.evaluations.map((item) => item.code).toList(),
        second.evaluations.map((item) => item.code).toList(),
      );
    });

    test('observed provenance is rejected by generated-view evaluator', () {
      expect(
        () => CatalogueReconstructionEvaluator.createReviewRequired(
          _generated(provenance: CatalogueReconstructionProvenance.observed),
        ),
        throwsStateError,
      );
    });

    test('already approved metadata is rejected by initial evaluator', () {
      expect(
        () => CatalogueReconstructionEvaluator.createReviewRequired(
          _generated(reviewStatus: CatalogueGeneratedViewReviewStatus.approved),
        ),
        throwsStateError,
      );
    });
  });
}

CatalogueReconstructionFixture _fixture({
  String fixtureId = 'fixture-1',
  String sourceAssetPath = 'test/fixtures/front.png',
  bool monochrome = true,
  bool localOnly = true,
  Set<CatalogueCanonicalView> allowedTargets = const {
    CatalogueCanonicalView.back,
  },
}) {
  return CatalogueReconstructionFixture(
    fixtureId: fixtureId,
    title: 'Fixture',
    garmentProfileCode: 'blouseV1',
    sourceView: CatalogueCanonicalView.front,
    sourceAssetPath: sourceAssetPath,
    complexity: CatalogueFixtureComplexity.simpleSinglePiece,
    allowedTargets: allowedTargets,
    evaluationDimensions: const {
      CatalogueVisualConsistencyDimension.silhouette,
    },
    monochrome: monochrome,
    localOnly: localOnly,
  );
}

CatalogueGeneratedViewMetadata _generated({
  CatalogueReconstructionProvenance provenance =
      CatalogueReconstructionProvenance.generated,
  CatalogueGeneratedViewReviewStatus reviewStatus =
      CatalogueGeneratedViewReviewStatus.reviewRequired,
  Set<CatalogueCanonicalView> sourceViews = const {
    CatalogueCanonicalView.front,
  },
  Set<CatalogueVisualConsistencyDimension> requiredChecks = const {
    CatalogueVisualConsistencyDimension.silhouette,
    CatalogueVisualConsistencyDimension.visualProportion,
  },
}) {
  return CatalogueGeneratedViewMetadata(
    generatedViewId: 'generated-back-1',
    fixtureId: 'simple-blouse-front-v1',
    targetView: CatalogueCanonicalView.back,
    provenance: provenance,
    reviewStatus: reviewStatus,
    providerId: 'future-provider',
    providerContractVersion: '1.0',
    sourceViews: sourceViews,
    requiredChecks: requiredChecks,
  );
}
