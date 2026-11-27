import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/stitching_rate.dart';

/// Shared stitching rate-card policy. The partner rate remains in `rates` so
/// existing tailor screens continue to use the same source of truth.
class StitchingPricingService {
  StitchingPricingService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const _policyPath = 'config/stitchingPricing';

  static Future<Map<String, dynamic>> loadPolicy() async {
    try {
      final snapshot = await _db.doc(_policyPath).get();
      return snapshot.data() ??
          <String, dynamic>{
            'platformPercent': 15,
            'deliveryFee': 0,
            'measurementFee': 0,
            'otherFee': 0,
            'taxPercent': 6,
          };
    } catch (_) {
      return <String, dynamic>{
        'platformPercent': 15,
        'deliveryFee': 0,
        'measurementFee': 0,
        'otherFee': 0,
        'taxPercent': 6,
      };
    }
  }

  static double customerPrice({
    required double partnerRate,
    required double platformPercent,
    required double deliveryFee,
    required double measurementFee,
    required double otherFee,
    required double taxPercent,
  }) {
    final percentTotal = partnerRate * (platformPercent + taxPercent) / 100;
    return ((partnerRate +
                    percentTotal +
                    deliveryFee +
                    measurementFee +
                    otherFee) *
                100)
            .round() /
        100;
  }

  static Future<void> publish({
    required List<StitchingRate> rates,
    required double platformPercent,
    required double deliveryFee,
    required double measurementFee,
    required double otherFee,
    required double taxPercent,
  }) async {
    final batch = _db.batch();
    batch.set(_db.doc(_policyPath), {
      'platformPercent': platformPercent,
      'deliveryPercent': FieldValue.delete(),
      'deliveryFee': deliveryFee,
      'measurementFee': measurementFee,
      'otherFee': otherFee,
      'taxPercent': taxPercent,
      'updatedAt': FieldValue.serverTimestamp(),
      'versionId': DateTime.now().microsecondsSinceEpoch.toString(),
    }, SetOptions(merge: true));
    for (final rate in rates) {
      final id = rate.dressType.replaceAll('/', '_');
      batch.set(_db.collection('rates').doc(id), {
        'dressType': rate.dressType,
        'basePrice': rate.basePrice,
        'customerPrice': rate.customerPrice,
        'customerPriceOverride': rate.customerPriceOverride,
        'notes': rate.notes,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }
}
