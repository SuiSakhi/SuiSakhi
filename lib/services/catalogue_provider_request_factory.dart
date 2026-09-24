import '../models/catalogue_provider_manifest.dart';
import '../models/catalogue_provider_request.dart';
import '../models/catalogue_view_proposal.dart';

class CatalogueProviderRequestFactory {
  const CatalogueProviderRequestFactory._();

  static CatalogueProviderRequest fromProposal(
    CatalogueViewProposalRequest proposal,
  ) {
    if (!proposal.isActionable) {
      throw StateError('Only actionable proposal requests can be adapted.');
    }

    final targetViews = proposal.targets
        .map((item) => item.targetView)
        .toList();
    final checks = proposal.targets
        .expand((item) => item.consistencyChecks)
        .toSet();

    final manifest = CatalogueProviderManifest(
      schemaVersion: '1.0',
      requestId: proposal.requestId,
      designId: proposal.designId,
      versionId: proposal.versionId,
      sourceViewIds: proposal.sourceViewIds,
      targetViews: targetViews,
      restrictions: proposal.restrictions,
      consistencyChecks: checks,
      reviewPolicy: proposal.reviewPolicy,
    );

    return CatalogueProviderRequest(
      adapterContractVersion: '1.0',
      providerRequestId: 'provider|${proposal.requestId}',
      manifest: manifest,
    );
  }
}
