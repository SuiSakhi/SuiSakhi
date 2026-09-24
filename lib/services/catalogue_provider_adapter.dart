import '../models/catalogue_provider_request.dart';
import '../models/catalogue_provider_response.dart';

abstract interface class CatalogueProviderAdapter {
  String get adapterId;
  String get contractVersion;

  Future<CatalogueProviderResponse> submit(CatalogueProviderRequest request);
}
