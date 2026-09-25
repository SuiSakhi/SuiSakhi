import '../models/catalogue_reconstruction_foundation.dart';

/// Deterministic metadata evaluator used before visual algorithms exist.
class CatalogueReconstructionEvaluator {
  const CatalogueReconstructionEvaluator._();

  static CatalogueReconstructionEvaluationResult createReviewRequired(
    CatalogueGeneratedViewMetadata metadata,
  ) {
    if (metadata.provenance != CatalogueReconstructionProvenance.generated) {
      throw StateError('Only generated-view metadata can be evaluated here.');
    }
    if (metadata.reviewStatus !=
        CatalogueGeneratedViewReviewStatus.reviewRequired) {
      throw StateError('Generated view must start in reviewRequired status.');
    }

    final dimensions = metadata.requiredChecks.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    final evaluations = dimensions
        .map(
          (dimension) => CatalogueConsistencyEvaluation(
            dimension: dimension,
            outcome: CatalogueEvaluationOutcome.reviewRequired,
            code: 'REVIEW_${dimension.name.toUpperCase()}',
          ),
        )
        .toList(growable: false);

    return CatalogueReconstructionEvaluationResult(
      generatedViewId: metadata.generatedViewId,
      evaluations: evaluations,
      overallOutcome: CatalogueEvaluationOutcome.reviewRequired,
    );
  }
}
