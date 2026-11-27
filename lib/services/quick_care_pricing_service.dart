import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/prd_catalog.dart';

/// Admin-managed customer and Partner rates for Quick Care & Home Services.
class QuickCarePricingService {
  QuickCarePricingService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const _policyPath = 'config/quickCarePricing';

  static Map<String, dynamic> defaults() {
    const platformPercent = 15.0;
    const taxPercent = 6.0;
    return {
      'platformPercent': platformPercent,
      'taxPercent': taxPercent,
      'homeVisitPartnerAmount': 49.0,
      'homeVisitCustomerAmount': customerPrice(
        partnerAmount: 49,
        platformPercent: platformPercent,
        taxPercent: taxPercent,
      ),
      'homeVisitCustomerPriceOverride': false,
      'expressPartnerAmount': 99.0,
      'expressCustomerAmount': customerPrice(
        partnerAmount: 99,
        platformPercent: platformPercent,
        taxPercent: taxPercent,
      ),
      'expressCustomerPriceOverride': false,
      'serviceRates': {
        for (final service in QuickFixService.catalog)
          service.id: {
            'partnerAmount': service.midEstimate,
            'customerAmount': customerPrice(
              partnerAmount: service.midEstimate,
              platformPercent: platformPercent,
              taxPercent: taxPercent,
            ),
            'customerPriceOverride': false,
          },
      },
    };
  }

  static Future<Map<String, dynamic>> load() async {
    try {
      final snapshot = await _db.doc(_policyPath).get();
      final data = snapshot.data();
      if (data == null) return defaults();
      final result = defaults();
      result.addAll(data);
      result['serviceRates'] = {
        ...Map<String, dynamic>.from(defaults()['serviceRates'] as Map),
        ...Map<String, dynamic>.from(data['serviceRates'] as Map? ?? const {}),
      };
      return result;
    } catch (_) {
      return defaults();
    }
  }

  static double customerPrice({
    required double partnerAmount,
    required double platformPercent,
    required double taxPercent,
  }) =>
      ((partnerAmount * (100 + platformPercent + taxPercent) / 100) * 100)
          .round() /
      100;

  static Future<void> publish(Map<String, dynamic> policy) async {
    final versionId = DateTime.now().microsecondsSinceEpoch.toString();
    final version = {
      ...policy,
      'versionId': versionId,
      'publishedAt': FieldValue.serverTimestamp(),
    };
    final batch = _db.batch();
    batch.set(_db.doc(_policyPath), {
      ...version,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(_db.doc('$_policyPath/versions/$versionId'), version);
    await batch.commit();
  }
}
