import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Calls Cloud Function [sendUserWhatsApp] → WhatsApp Cloud API (Meta).
///
/// Configure Firebase Functions + Meta Business before this does anything useful.
/// See `firebase/functions/index.js`.
class WhatsAppNotifyService {
  WhatsAppNotifyService._();

  /// Best-effort: does not throw to the UI; fails silently in release.
  static Future<void> tryNotifyOrderPlaced({
    required String dressType,
    required bool userOptIn,
  }) async {
    if (!userOptIn) return;
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('sendUserWhatsApp');
      await callable.call({
        'kind': 'order_placed',
        'dressType': dressType,
        // Must exist and be approved in your Meta WhatsApp Business account.
        'templateName': 'hello_world',
        'languageCode': 'en_US',
      });
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('WhatsApp notify skipped: $e\n$st');
      }
    }
  }
}
