import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/dress.dart';
import '../../models/payment_models.dart';
import '../../services/payment_completion_service.dart';
import '../../services/payout_config_service.dart';
import '../../widgets/common/custom_button.dart';

/// Customer pays **advance** online (card / UPI / net banking).
/// Sandbox mode completes in-app; live Razorpay needs server + SDK.
class OrderCheckoutScreen extends StatefulWidget {
  final String orderId;

  const OrderCheckoutScreen({super.key, required this.orderId});

  @override
  State<OrderCheckoutScreen> createState() => _OrderCheckoutScreenState();
}

class _OrderCheckoutScreenState extends State<OrderCheckoutScreen> {
  DressOrder? _order;
  ShopPayoutConfig? _payoutConfig;
  String? _loadError;
  bool _busy = false;
  bool _quickCareNeedsCustomerPayment = false;
  bool _quickCareRequiresFullAmount = false;
  String? _activeRazorpayOrderId;
  late final Razorpay _razorpay;

  bool get _isBalancePayment =>
      _order?.assignmentVersion == 'v1' &&
      _order?.status == OrderStatus.readyForPickup &&
      _order?.paymentStatus == PaymentStatus.advancePaid;

  bool get _isQuickCarePayment => _quickCareNeedsCustomerPayment;

  double get _quickCareVerifiedPaid {
    final order = _order;
    if (order == null || order.paymentStatus != PaymentStatus.fullyPaid) {
      return 0;
    }
    final razorpayVerified =
        order.paymentProvider == 'razorpay' &&
        (order.quickCareGatewayPaymentId?.isNotEmpty ?? false);
    final sandboxVerified =
        _payoutConfig?.sandboxMode == true &&
        order.paymentProvider == 'sandbox' &&
        (order.quickCarePaymentMethod?.isNotEmpty ?? false);
    return razorpayVerified || sandboxVerified ? order.amountPaid ?? 0 : 0;
  }

  double get _amountDue {
    final order = _order;
    if (order == null) return 0;
    if (_isQuickCarePayment) {
      final due = _quickCareRequiresFullAmount
          ? order.price
          : order.price - (order.amountPaid ?? 0);
      return due.clamp(0, double.infinity).toDouble();
    }
    return _isBalancePayment ? order.balanceAmount : order.advanceAmount;
  }

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay()
      ..on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleRazorpaySuccess)
      ..on(Razorpay.EVENT_PAYMENT_ERROR, _handleRazorpayFailure)
      ..on(Razorpay.EVENT_EXTERNAL_WALLET, _handleRazorpayExternalWallet);
    _load();
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _loadError = 'Sign in to continue.');
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .get();
      if (!doc.exists) {
        setState(() => _loadError = 'Order not found.');
        return;
      }
      final data = doc.data()!;
      if (data['customerId'] != uid) {
        setState(() => _loadError = 'This order is not yours.');
        return;
      }
      final cfg = await PayoutConfigService.fetch();
      final isQuickCare = data['orderModuleType'] == 'quickFix';
      final workflow = (data['quickCareWorkflowStatus'] ?? '').toString();
      final provider = (data['paymentProvider'] ?? '').toString();
      final paymentStatus = (data['paymentStatus'] ?? '').toString();
      final verifiedProvider =
          paymentStatus == 'fullyPaid' &&
          ((provider == 'razorpay' &&
                  (data['quickCareGatewayPaymentId'] as String?)?.isNotEmpty ==
                      true) ||
              (provider == 'sandbox' &&
                  cfg.sandboxMode &&
                  (data['quickCarePaymentMethod'] as String?)?.isNotEmpty ==
                      true));
      final legacyPartnerClaim =
          isQuickCare &&
          !verifiedProvider &&
          data['paymentStatus'] == 'fullyPaid' &&
          (workflow == 'completed' || workflow == 'paymentPending');
      final isAdvanceDue =
          data['assignmentVersion'] == 'v1' &&
          data['assignmentStatus'] == 'awaiting_customer_decision' &&
          data['paymentStatus'] == 'pending_payment';
      final isBalanceDue =
          data['assignmentVersion'] == 'v1' &&
          data['status'] == 'readyForPickup' &&
          data['paymentStatus'] == 'advancePaid';
      final isQuickCareDue =
          isQuickCare &&
          ((workflow == 'paymentPending' && !verifiedProvider) ||
              legacyPartnerClaim);
      if (data['assignmentVersion'] == 'v1' && !isAdvanceDue && !isBalanceDue) {
        setState(
          () => _loadError = 'No payment is due for this order right now.',
        );
        return;
      }
      if (isQuickCare && !isQuickCareDue) {
        setState(
          () => _loadError =
              'Quick Care payment is available after your Partner completes the service.',
        );
        return;
      }
      final customerDeadline = data['customerDecisionExpiresAt'];
      if (isAdvanceDue &&
          customerDeadline is Timestamp &&
          customerDeadline.toDate().isBefore(DateTime.now())) {
        setState(
          () => _loadError =
              'The customer decision deadline has passed. Please contact SuiSakhi support.',
        );
        return;
      }
      if (!mounted) return;
      setState(() {
        _order = DressOrder.fromFirestore(doc.id, data);
        _payoutConfig = cfg;
        _quickCareNeedsCustomerPayment = isQuickCareDue;
        // Partner-reported amounts are not collected payments. Collect the
        // complete approved Quick Care total through checkout.
        _quickCareRequiresFullAmount = isQuickCareDue;
        _loadError = null;
      });
    } catch (e) {
      if (mounted) setState(() => _loadError = '$e');
    }
  }

  Future<void> _pay(OnlinePaymentMethod method) async {
    final o = _order;
    if (o == null ||
        (!_isQuickCarePayment &&
            !_isBalancePayment &&
            o.paymentStatus != PaymentStatus.pendingPayment) ||
        _amountDue <= 0) {
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm test payment'),
        content: Text(
          _payoutConfig?.sandboxMode == true
              ? 'This is a dummy checkout for testing. No real money is charged.\n\n'
                    'Method: ${method.label}\n'
                    'Amount: ₹${_amountDue.toStringAsFixed(0)}'
              : 'Live gateway is not fully wired from this build. Enable sandbox under Owner → Payments.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _busy = true);
    final quickCarePayment = _isQuickCarePayment;
    final balancePayment = _isBalancePayment;
    final err = quickCarePayment
        ? await PaymentCompletionService.completeQuickCarePayment(
            orderId: widget.orderId,
            method: method,
            expectedAmount: _amountDue,
          )
        : balancePayment
        ? await PaymentCompletionService.completeBalancePayment(
            orderId: widget.orderId,
            method: method,
          )
        : await PaymentCompletionService.completeAdvancePayment(
            orderId: widget.orderId,
            method: method,
          );
    if (!mounted) return;
    setState(() => _busy = false);

    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }

    if (quickCarePayment) {
      _returnToQuickCareOrders();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          balancePayment
              ? 'Remaining payment recorded. Your order can now be dispatched.'
              : 'Advance recorded — thank you!',
        ),
      ),
    );
    context.go('/orders');
  }

  void _returnToQuickCareOrders() {
    if (context.canPop()) {
      context.pop(true);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Quick Care payment verified. The booking is now closed.',
        ),
      ),
    );
    context.go('/orders?module=quickFix');
  }

  Future<void> _openRazorpayCheckout() async {
    if (_busy || !_isQuickCarePayment || _payoutConfig?.sandboxMode != false) {
      return;
    }
    setState(() => _busy = true);
    try {
      final gatewayOrder =
          await PaymentCompletionService.createQuickCareGatewayOrder(
            orderId: widget.orderId,
          );
      final keyId = gatewayOrder['keyId']?.toString() ?? '';
      final gatewayOrderId = gatewayOrder['razorpayOrderId']?.toString() ?? '';
      final amountPaise = (gatewayOrder['amountPaise'] as num?)?.toInt() ?? 0;
      if (keyId.isEmpty || gatewayOrderId.isEmpty || amountPaise <= 0) {
        throw StateError('Razorpay returned incomplete checkout details.');
      }
      _activeRazorpayOrderId = gatewayOrderId;
      final user = FirebaseAuth.instance.currentUser;
      final order = _order!;
      if (mounted) setState(() => _busy = false);
      _razorpay.open(<String, dynamic>{
        'key': keyId,
        'order_id': gatewayOrderId,
        'amount': amountPaise,
        'currency': 'INR',
        'name': 'SuiSakhi',
        'description': 'Quick Care service · ${order.dressType}',
        'prefill': <String, String>{
          if ((order.customerPhone ?? user?.phoneNumber ?? '').isNotEmpty)
            'contact': order.customerPhone ?? user!.phoneNumber!,
          if ((user?.email ?? '').isNotEmpty) 'email': user!.email!,
        },
        'theme': <String, String>{'color': '#B70D5C'},
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_paymentErrorMessage(error))));
    }
  }

  Future<void> _handleRazorpaySuccess(PaymentSuccessResponse response) async {
    final paymentId = response.paymentId;
    final gatewayOrderId = response.orderId ?? _activeRazorpayOrderId;
    final signature = response.signature;
    if (paymentId == null || gatewayOrderId == null || signature == null) {
      _showPaymentMessage(
        'Razorpay returned incomplete confirmation. Do not pay again; Helpdesk can verify this transaction.',
      );
      return;
    }
    if (mounted) setState(() => _busy = true);
    try {
      await PaymentCompletionService.verifyQuickCareGatewayPayment(
        orderId: widget.orderId,
        razorpayOrderId: gatewayOrderId,
        razorpayPaymentId: paymentId,
        razorpaySignature: signature,
      );
      if (!mounted) return;
      setState(() => _busy = false);
      _returnToQuickCareOrders();
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_paymentErrorMessage(error))));
    }
  }

  void _handleRazorpayFailure(PaymentFailureResponse response) {
    if (response.code == Razorpay.PAYMENT_CANCELLED) {
      _showPaymentMessage(
        'Payment cancelled. The service remains open with payment pending.',
      );
      return;
    }
    _showPaymentMessage(
      response.message ?? 'Payment did not complete. Please retry.',
    );
  }

  void _handleRazorpayExternalWallet(ExternalWalletResponse response) {
    _showPaymentMessage(
      '${response.walletName ?? 'External wallet'} selected. Complete payment and wait for confirmation.',
    );
  }

  String _paymentErrorMessage(Object error) {
    if (error is FirebaseFunctionsException) {
      return error.message ??
          'Could not verify payment. Contact Helpdesk before retrying.';
    }
    return 'Could not open or verify payment. Please retry or contact Helpdesk.';
  }

  void _showPaymentMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          _isQuickCarePayment
              ? 'Pay Quick Care service'
              : _isBalancePayment
              ? 'Pay remaining balance'
              : 'Pay advance',
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_loadError!, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              PrimaryButton(label: 'Back', onTap: () => context.pop()),
            ],
          ),
        ),
      );
    }
    final o = _order;
    if (o == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_isQuickCarePayment &&
        o.paymentStatus != PaymentStatus.pendingPayment &&
        !_isBalancePayment) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.success,
                size: 56,
              ),
              const SizedBox(height: 16),
              Text(
                'No payment needed',
                style: AppTextStyles.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Status: ${o.paymentStatus.label}',
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'View orders',
                onTap: () => context.go('/orders'),
              ),
            ],
          ),
        ),
      );
    }

    final sandbox = _payoutConfig?.sandboxMode ?? true;
    final hasRazorpayKey =
        (_payoutConfig?.razorpayKeyId?.trim().isNotEmpty ?? false);
    final canTapPay = sandbox && !_busy;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (sandbox)
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFFF9800).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFFF9800).withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.science_outlined,
                    color: Color(0xFFFF9800),
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Test mode: choose a method below to simulate card, UPI, or '
                      'net banking. This only records the test payment state; it does '
                      'not move real money or settle Partner payouts.',
                      style: AppTextStyles.bodySmall.copyWith(height: 1.4),
                    ),
                  ),
                ],
              ),
            )
          else if (_isQuickCarePayment && !sandbox && hasRazorpayKey)
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Secure Razorpay checkout. Pay the approved amount directly to SuiSakhi. Only a verified gateway payment closes this job.',
                style: AppTextStyles.bodySmall,
              ),
            )
          else if (_isQuickCarePayment && !sandbox)
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Online payment is not configured yet. Please contact SuiSakhi Helpdesk; the Partner cannot collect or confirm this payment.',
                style: AppTextStyles.bodySmall,
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Sandbox is off. Complete Razorpay (or another gateway) on the server '
                'before customers can pay live.',
                style: AppTextStyles.bodySmall,
              ),
            ),
          Text(o.dressType, style: AppTextStyles.headlineSmall),
          if (o.clientName != null && o.clientName!.isNotEmpty)
            Text(o.clientName!, style: AppTextStyles.bodyMedium),
          const SizedBox(height: 16),
          Text(
            _isQuickCarePayment
                ? 'Final Quick Care service amount · ₹${o.price.toStringAsFixed(0)}'
                : 'Current stitching estimate · ₹${o.price.toStringAsFixed(0)}',
            style: AppTextStyles.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            _isQuickCarePayment
                ? 'Payment due · ₹${_amountDue.toStringAsFixed(0)}'
                : _isBalancePayment
                ? 'Remaining balance · ₹${o.balanceAmount.toStringAsFixed(0)}'
                : 'Advance (${o.advancePercent}%) · ₹${o.advanceAmount.toStringAsFixed(0)}',
            style: AppTextStyles.headlineMedium.copyWith(
              color: AppColors.primary,
            ),
          ),
          Text(
            _isQuickCarePayment
                ? 'Final service amount · ₹${o.price.toStringAsFixed(0)} · verified payment received · ₹${_quickCareVerifiedPaid.toStringAsFixed(0)}'
                : _isBalancePayment
                ? 'Stitching estimate · ₹${o.price.toStringAsFixed(0)} · advance received · ₹${o.amountPaid?.toStringAsFixed(0) ?? o.advanceAmount.toStringAsFixed(0)}'
                : 'Balance after advance · ₹${o.balanceAmount.toStringAsFixed(0)}',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
          ),
          const SizedBox(height: 8),
          Text(
            _isQuickCarePayment
                ? 'Pay the final agreed Quick Care amount. The booking closes automatically after payment is recorded.'
                : _isBalancePayment
                ? 'Pay the remaining balance online before the Delivery Partner can accept the dispatch.'
                : 'Pay 50% of this stitching estimate to finalize the order.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
          ),
          const SizedBox(height: 28),
          Text(
            _isQuickCarePayment && !sandbox
                ? 'Pay securely with Razorpay'
                : 'Pay with',
            style: AppTextStyles.titleMedium,
          ),
          const SizedBox(height: 12),
          if (_isQuickCarePayment && !sandbox)
            FilledButton.icon(
              onPressed: _busy || !hasRazorpayKey
                  ? null
                  : _openRazorpayCheckout,
              icon: const Icon(Icons.lock_outline_rounded),
              label: Text(
                hasRazorpayKey
                    ? 'Pay ₹${_amountDue.toStringAsFixed(0)} securely'
                    : 'Payment gateway unavailable',
              ),
            )
          else ...[
            _methodTile(
              icon: Icons.credit_card_rounded,
              label: OnlinePaymentMethod.card.label,
              onTap: canTapPay ? () => _pay(OnlinePaymentMethod.card) : null,
            ),
            const SizedBox(height: 10),
            _methodTile(
              icon: Icons.account_balance_wallet_outlined,
              label: OnlinePaymentMethod.upi.label,
              onTap: canTapPay ? () => _pay(OnlinePaymentMethod.upi) : null,
            ),
            const SizedBox(height: 10),
            _methodTile(
              icon: Icons.account_balance_rounded,
              label: OnlinePaymentMethod.netbanking.label,
              onTap: canTapPay
                  ? () => _pay(OnlinePaymentMethod.netbanking)
                  : null,
            ),
          ],
          if (_busy) ...[
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }

  Widget _methodTile({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 26),
              const SizedBox(width: 14),
              Expanded(child: Text(label, style: AppTextStyles.titleMedium)),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textHint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
