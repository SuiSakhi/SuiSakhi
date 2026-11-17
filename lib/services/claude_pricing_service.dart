import '../models/stitching_rate.dart';
import 'smart_assist_client.dart';

/// Optional rate-card guidance routed through the authenticated backend.
/// Measurements and free-form notes are intentionally excluded from requests.
class ClaudePricingService {
  static Future<PriceEstimate> estimate({
    required String dressType,
    required String fit,
    required Map<String, String> measurements,
    String? notes,
    required List<StitchingRate> shopRates,
  }) async {
    if (shopRates.isEmpty) {
      return const PriceEstimate.error(
        'No rate card loaded. The owner should add stitching rates before requesting an estimate.',
      );
    }

    final result = await SmartAssistClient.instance.request(
      feature: 'priceEstimate',
      input: {
        'garmentType': dressType,
        'fit': fit,
        'shopRates': shopRates
            .map(
              (rate) => <String, dynamic>{
                'dressType': rate.dressType,
                'basePrice': rate.basePrice,
              },
            )
            .toList(growable: false),
      },
    );
    if (!result.success) return PriceEstimate.error(result.text);
    return PriceEstimate.success(result.text);
  }
}

class PriceEstimate {
  final bool success;
  final String text;

  const PriceEstimate.success(this.text) : success = true;
  const PriceEstimate.error(this.text) : success = false;
}
