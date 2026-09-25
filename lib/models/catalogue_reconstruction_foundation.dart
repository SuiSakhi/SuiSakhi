import 'catalogue_design_evidence.dart';
import 'catalogue_source_view.dart';

/// Immutable truth category for every reconstruction-related datum.
enum CatalogueReconstructionProvenance { observed, inferred, generated }

/// Review lifecycle for a generated-view proposal.
enum CatalogueGeneratedViewReviewStatus {
  reviewRequired,
  changesRequested,
  approved,
  rejected,
  superseded,
}

/// Local fixture complexity. C1.4E-1 begins with [simpleSinglePiece].
enum CatalogueFixtureComplexity {
  simpleSinglePiece,
  detailedSinglePiece,
  multiPiece,
}

/// A governed, reusable local reconstruction test fixture.
class CatalogueReconstructionFixture {
  CatalogueReconstructionFixture({
    required this.fixtureId,
    required this.title,
    required this.garmentProfileCode,
    required this.sourceView,
    required this.sourceAssetPath,
    required this.complexity,
    required Set<CatalogueCanonicalView> allowedTargets,
    required Set<CatalogueVisualConsistencyDimension> evaluationDimensions,
    required this.monochrome,
    required this.localOnly,
  }) : allowedTargets = Set.unmodifiable(allowedTargets),
       evaluationDimensions = Set.unmodifiable(evaluationDimensions);

  final String fixtureId;
  final String title;
  final String garmentProfileCode;
  final CatalogueCanonicalView sourceView;
  final String sourceAssetPath;
  final CatalogueFixtureComplexity complexity;
  final Set<CatalogueCanonicalView> allowedTargets;
  final Set<CatalogueVisualConsistencyDimension> evaluationDimensions;
  final bool monochrome;
  final bool localOnly;
}

/// Metadata describing one future output without containing image bytes.
class CatalogueGeneratedViewMetadata {
  CatalogueGeneratedViewMetadata({
    required this.generatedViewId,
    required this.fixtureId,
    required this.targetView,
    required this.provenance,
    required this.reviewStatus,
    required this.providerId,
    required this.providerContractVersion,
    required Set<CatalogueCanonicalView> sourceViews,
    required Set<CatalogueVisualConsistencyDimension> requiredChecks,
    this.localAssetPath,
  }) : sourceViews = Set.unmodifiable(sourceViews),
       requiredChecks = Set.unmodifiable(requiredChecks);

  final String generatedViewId;
  final String fixtureId;
  final CatalogueCanonicalView targetView;
  final CatalogueReconstructionProvenance provenance;
  final CatalogueGeneratedViewReviewStatus reviewStatus;
  final String providerId;
  final String providerContractVersion;
  final Set<CatalogueCanonicalView> sourceViews;
  final Set<CatalogueVisualConsistencyDimension> requiredChecks;
  final String? localAssetPath;

  bool get isObservedTruth =>
      provenance == CatalogueReconstructionProvenance.observed;
  bool get customerVisible =>
      reviewStatus == CatalogueGeneratedViewReviewStatus.approved;
  bool get containsImageBytes => false;
  bool get usesMeasurements => false;
}

enum CatalogueEvaluationOutcome { notEvaluated, passed, reviewRequired, failed }

class CatalogueConsistencyEvaluation {
  const CatalogueConsistencyEvaluation({
    required this.dimension,
    required this.outcome,
    required this.code,
  });

  final CatalogueVisualConsistencyDimension dimension;
  final CatalogueEvaluationOutcome outcome;
  final String code;
}

class CatalogueReconstructionEvaluationResult {
  CatalogueReconstructionEvaluationResult({
    required this.generatedViewId,
    required List<CatalogueConsistencyEvaluation> evaluations,
    required this.overallOutcome,
  }) : evaluations = List.unmodifiable(evaluations);

  final String generatedViewId;
  final List<CatalogueConsistencyEvaluation> evaluations;
  final CatalogueEvaluationOutcome overallOutcome;

  bool get approvedAutomatically => false;
  bool get requiresHumanReview => true;
}
