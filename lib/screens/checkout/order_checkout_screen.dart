import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
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
      if (!mounted) return;
      setState(() {
        _order = DressOrder.fromFirestore(doc.id, data);
        _payoutConfig = cfg;
        _loadError = null;
      });
    } catch (e) {
      if (mounted) setState(() => _loadError = '$e');
    }
  }

  Future<void> _pay(OnlinePaymentMethod method) async {
    final o = _order;
    if (o == null || o.paymentStatus != PaymentStatus.pendingPayment) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm test payment'),
        content: Text(
          _payoutConfig?.sandboxMode == true
              ? 'This is a dummy checkout for testing. No real money is charged.\n\n'
                  'Method: ${method.label}\n'
                  'Amount: ₹${o.advanceAmount.toStringAsFixed(0)}'
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
    final err = await PaymentCompletionService.completeAdvancePayment(
      orderId: widget.orderId,
      method: method,
    );
    if (!mounted) return;
    setState(() => _busy = false);

    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Payment recorded — thank you!')),
    );
    context.go('/orders');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pay advance'),
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
              PrimaryButton(
                label: 'Back',
                onTap: () => context.pop(),
              ),
            ],
          ),
        ),
      );
    }
    final o = _order;
    if (o == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (o.paymentStatus != PaymentStatus.pendingPayment) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: 56),
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
                  const Icon(Icons.science_outlined,
                      color: Color(0xFFFF9800), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Test mode: choose a method below to simulate card, UPI, or '
                      'net banking. Splits are saved on the order for owner, tailor, '
                      'delivery, and platform.',
                      style: AppTextStyles.bodySmall.copyWith(height: 1.4),
                    ),
                  ),
                ],
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
            'Order total · ₹${o.price.toStringAsFixed(0)}',
            style: AppTextStyles.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Advance (${o.advancePercent}%) · ₹${o.advanceAmount.toStringAsFixed(0)}',
            style: AppTextStyles.headlineMedium.copyWith(color: AppColors.primary),
          ),
          Text(
            'Balance after advance · ₹${o.balanceAmount.toStringAsFixed(0)}',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
          ),
          const SizedBox(height: 8),
          Text(
            'Only online payment is accepted for the advance (card, UPI, or net banking).',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
          ),
          const SizedBox(height: 28),
          Text('Pay with', style: AppTextStyles.titleMedium),
          const SizedBox(height: 12),
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
            onTap: canTapPay ? () => _pay(OnlinePaymentMethod.netbanking) : null,
          ),
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
              Expanded(
                child: Text(label, style: AppTextStyles.titleMedium),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
            ],
          ),
        ),
      ),
    );
  }
}
