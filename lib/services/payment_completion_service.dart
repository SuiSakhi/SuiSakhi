import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/app_state.dart';
import '../models/payment_models.dart';
import 'payout_config_service.dart';
import 'order_lifecycle_service.dart';
import 'whatsapp_notify_service.dart';

/// Marks advance as paid, writes payout ledger, optional WhatsApp ping.
///
/// **Sandbox**: completes immediately from the app (for QA). **Live** Razorpay
/// still needs a server to create orders, verify signatures, and run payouts —
/// set [sandboxMode] false only after deploying Functions + gateway.
class PaymentCompletionService {
  PaymentCompletionService._();
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// Returns null on success, or an error message.
  static Future<String?> completeAdvancePayment({
    required String orderId,
    required OnlinePaymentMethod method,
    String? tailorUpiOverride,
    String? deliveryUpiOverride,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return 'Sign in to pay.';

    final orderRef = _db.collection('orders').doc(orderId);
    final snap = await orderRef.get();
    if (!snap.exists) return 'Order not found.';
    final data = snap.data()!;
    if (data['customerId'] != uid) {
      return 'This order does not belong to you.';
    }
    final ps = data['paymentStatus'] as String? ?? 'unpaid';
    if (ps != 'pending_payment') {
      return 'This order does not need an online payment.';
    }

    final config = await PayoutConfigService.fetch();
    if (!config.sandboxMode) {
      if (kDebugMode) {
        debugPrint(
          '[Payment] sandboxMode=false but live Razorpay flow is not wired in-app. '
          'Use sandbox or add Cloud Functions + razorpay_flutter.',
        );
      }
      return 'Live card/UPI is not enabled yet. Ask the owner to turn on '
          '“Test (dummy) payments” under Owner → Payments & payouts, or finish '
          'Razorpay server setup.';
    }

    if (data['assignmentVersion'] == 'v1') {
      if (data['assignmentStatus'] != 'awaiting_customer_decision') {
        return 'This order is not waiting for your decision.';
      }
      final deadline = data['customerDecisionExpiresAt'];
      if (deadline is Timestamp && deadline.toDate().isBefore(DateTime.now())) {
        return 'The customer decision deadline has passed. Please contact SuiSakhi support.';
      }
      try {
        await FirebaseFunctions.instance
            .httpsCallable('completeSandboxOrderAdvance')
            .call({
              'orderId': orderId,
              'paymentMethod': method.name,
            });
      } on FirebaseFunctionsException catch (error) {
        return error.message ?? 'Could not complete the advance payment.';
      } catch (_) {
        return 'Could not complete the advance payment. Please retry.';
      }

      final dressType = data['dressType'] as String? ?? 'Order';
      await WhatsAppNotifyService.tryNotifyOrderPlaced(
        dressType: dressType,
        userOptIn: AppState.instance.profile?.notifyWhatsApp ?? true,
      );
      return null;
    }

    final advance = (data['advanceAmount'] as num?)?.toDouble() ?? 0;
    if (advance <= 0) return 'Invalid advance amount.';

    var ledger = config.buildLedger(advance);
    if (tailorUpiOverride != null && tailorUpiOverride.trim().isNotEmpty) {
      ledger = _applyUpiOverride(ledger, 'tailor', tailorUpiOverride.trim());
    }
    if (deliveryUpiOverride != null && deliveryUpiOverride.trim().isNotEmpty) {
      ledger =
          _applyUpiOverride(ledger, 'delivery', deliveryUpiOverride.trim());
    }

    await orderRef.update({
      'paymentStatus': 'advancePaid',
      'paidAt': FieldValue.serverTimestamp(),
      'paymentMethod': method.name,
      'paymentProvider': 'sandbox',
      'amountPaid': advance,
      'payoutLedger': ledger.map((e) => e.toMap()).toList(),
    });

    final dressType = data['dressType'] as String? ?? 'Order';
    await WhatsAppNotifyService.tryNotifyOrderPlaced(
      dressType: dressType,
      userOptIn: AppState.instance.profile?.notifyWhatsApp ?? true,
    );

    return null;
  }

  static Future<String?> completeBalancePayment({
    required String orderId,
    required OnlinePaymentMethod method,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return 'Sign in to pay.';
    final snapshot = await _db.collection('orders').doc(orderId).get();
    if (!snapshot.exists || snapshot.get('customerId') != uid) {
      return 'This order does not belong to you.';
    }
    final data = snapshot.data() ?? const <String, dynamic>{};
    if (data['assignmentVersion'] != 'v1' ||
        data['status'] != 'readyForPickup' ||
        data['paymentStatus'] != 'advancePaid') {
      return 'The remaining payment becomes available when the order is ready for delivery.';
    }
    final config = await PayoutConfigService.fetch();
    if (!config.sandboxMode) {
      return 'Live card/UPI is not enabled yet. Complete the payment gateway setup first.';
    }
    try {
      await OrderLifecycleService.payBalance(orderId: orderId, method: method);
      return null;
    } on FirebaseFunctionsException catch (error) {
      return error.message ?? 'Could not complete the remaining payment.';
    } catch (_) {
      return 'Could not complete the remaining payment. Please retry.';
    }
  }

  static List<OrderPayoutLine> _applyUpiOverride(
    List<OrderPayoutLine> lines,
    String role,
    String upi,
  ) {
    return lines
        .map((l) => l.role == role
            ? OrderPayoutLine(
                role: l.role,
                amount: l.amount,
                percent: l.percent,
                creditToUpi: upi,
              )
            : l)
        .toList();
  }
}
