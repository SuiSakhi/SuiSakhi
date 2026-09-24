import 'catalogue_design_evidence.dart';
import 'catalogue_source_view.dart';
import 'catalogue_view_proposal.dart';

/// Provider-neutral manifest supplied to a future reconstruction adapter.
class CatalogueProviderManifest {
  CatalogueProviderManifest({
    required this.schemaVersion,
    required this.requestId,
    required this.designId,
    required this.versionId,
    required List<String> sourceViewIds,
    required List<CatalogueCanonicalView> targetViews,
    required Set<CatalogueViewProposalRestriction> restrictions,
    required Set<CatalogueVisualConsistencyDimension> consistencyChecks,
    required this.reviewPolicy,
  }) : sourceViewIds = List.unmodifiable(sourceViewIds),
       targetViews = List.unmodifiable(targetViews),
       restrictions = Set.unmodifiable(restrictions),
       consistencyChecks = Set.unmodifiable(consistencyChecks);

  final String schemaVersion;
  final String requestId;
  final String designId;
  final String versionId;
  final List<String> sourceViewIds;
  final List<CatalogueCanonicalView> targetViews;
  final Set<CatalogueViewProposalRestriction> restrictions;
  final Set<CatalogueVisualConsistencyDimension> consistencyChecks;
  final CatalogueViewProposalReviewPolicy reviewPolicy;

  Map<String, dynamic> toMap() => {
    'schemaVersion': schemaVersion,
    'requestId': requestId,
    'designId': designId,
    'versionId': versionId,
    'sourceViewIds': sourceViewIds,
    'targetViews': targetViews.map((item) => item.name).toList(),
    'restrictions': restrictions.map((item) => item.name).toList()..sort(),
    'consistencyChecks': consistencyChecks.map((item) => item.name).toList()
      ..sort(),
    'reviewPolicy': reviewPolicy.name,
  };
}
