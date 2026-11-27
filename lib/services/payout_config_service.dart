import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/payment_models.dart';

/// Firestore doc: `config/payouts` (same security as other `config/*`).
class PayoutConfigService {
  PayoutConfigService._();
  static final _db = FirebaseFirestore.instance;
  static const _docPath = 'config/payouts';

  static Future<ShopPayoutConfig> fetch() async {
    try {
      final doc = await _db.doc(_docPath).get();
      return ShopPayoutConfig.fromFirestore(doc.data());
    } catch (_) {
      return const ShopPayoutConfig();
    }
  }

  static Future<void> save(ShopPayoutConfig config) async {
    await _db.doc(_docPath).set({
      ...config.toFirestore(),
      // Retire the former advance-split settings so the current payout
      // policy is unambiguous in Firestore as well as in the UI.
      'ownerPercent': FieldValue.delete(),
      'tailorPercent': FieldValue.delete(),
      'deliveryPercent': FieldValue.delete(),
      'platformPercent': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
