import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/app_state.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/dress.dart';
import '../../models/payment_models.dart';
import '../../services/claude_smart_assistant_service.dart';

class DeliveryDashboardScreen extends StatefulWidget {
  const DeliveryDashboardScreen({super.key});

  @override
  State<DeliveryDashboardScreen> createState() => _DeliveryDashboardScreenState();
}

class _DeliveryDashboardScreenState extends State<DeliveryDashboardScreen> {
  int _tab = 0; // 0 = Available, 1 = My Deliveries
  List<DressOrder> _available = [];
  List<DressOrder> _mine = [];
  bool _loading = true;
  int _totalDeliveries = 0;
  double _earnings = 0;
  bool _subscriptionActive = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final myEmail = AppState.instance.profile?.email ?? '';
    try {
      // Load subscription info
      if (myEmail.isNotEmpty) {
        final sub = await FirebaseFirestore.instance
            .collection('subscriptions')
            .doc(myEmail.toLowerCase())
            .get();
        if (sub.exists) {
          final data = sub.data()!;
          final until = (data['subscribedUntil'] as Timestamp?)?.toDate();
          _subscriptionActive = data['active'] == true &&
              (until == null || until.isAfter(DateTime.now()));
          _totalDeliveries = (data['totalDeliveries'] as num?)?.toInt() ?? 0;
        }
      }

      // Load delivery fee to calculate earnings
      final settings = await AppState.instance.getDeliverySettings();
      final feePerOrder = settings['feePerOrder'] ?? 50.0;

      // Orders ready for delivery (available to pick up)
      final availSnap = await FirebaseFirestore.instance
          .collection('orders')
          .where('status', isEqualTo: 'readyForPickup')
          .get();

      // Orders assigned to me
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final mineSnap = await FirebaseFirestore.instance
          .collection('orders')
          .where('deliveryPartnerId', isEqualTo: uid)
          .get();

      if (mounted) {
        setState(() {
          _available = availSnap.docs.map((d) => _fromDoc(d)).toList();
          _mine = mineSnap.docs
              .map((d) => _fromDoc(d))
              .where((o) => o.status == OrderStatus.outForDelivery ||
                  o.status == OrderStatus.delivered)
              .toList()
            ..sort((a, b) => b.orderDate.compareTo(a.orderDate));
          final delivered =
              _mine.where((o) => o.status == OrderStatus.delivered).length;
          _earnings = delivered * feePerOrder;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  DressOrder _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    return DressOrder.fromFirestore(d.id, d.data());
  }

  void _showDeliveryAiBrief(BuildContext context, DressOrder order) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.local_shipping_rounded,
                color: AppColors.primary, size: 22),
            const SizedBox(width: 8),
            const Expanded(child: Text('AI delivery tips')),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: FutureBuilder<SmartAssistantResult>(
            future: ClaudeSmartAssistantService.deliveryHandoffBrief(order),
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final r = snap.data!;
              return SingleChildScrollView(
                child: Text(
                  r.text,
                  style: AppTextStyles.bodySmall.copyWith(height: 1.45),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            if (!_subscriptionActive) _buildSubscriptionBanner(),
            _buildStatRow(),
            _buildTabBar(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _tab == 0
                      ? _buildAvailableList()
                      : _buildMyDeliveries(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Delivery Portal', style: AppTextStyles.bodyMedium),
                ListenableBuilder(
                  listenable: AppState.instance,
                  builder: (_, _) => Text(
                    AppState.instance.displayName,
                    style: AppTextStyles.displayMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF00BCD4).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF00BCD4).withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.delivery_dining_rounded,
                    color: Color(0xFF00BCD4), size: 15),
                const SizedBox(width: 6),
                Text('Delivery',
                    style: AppTextStyles.labelMedium
                        .copyWith(color: const Color(0xFF00BCD4))),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () {
              AppState.instance.signOut();
              context.go('/login');
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.logout_rounded,
                  color: AppColors.textSecondary, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Subscription expired. Contact the owner to renew.',
              style: AppTextStyles.bodySmall.copyWith(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          _StatCard(
            label: 'Available',
            value: '${_available.length}',
            color: const Color(0xFF9C27B0),
            icon: Icons.inventory_2_rounded,
          ),
          const SizedBox(width: 10),
          _StatCard(
            label: 'My Deliveries',
            value: '$_totalDeliveries',
            color: const Color(0xFF00BCD4),
            icon: Icons.delivery_dining_rounded,
          ),
          const SizedBox(width: 10),
          _StatCard(
            label: 'Earnings',
            value: '₹${_earnings.toInt()}',
            color: const Color(0xFF4CAF50),
            icon: Icons.currency_rupee_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          _TabBtn(
            label: 'Available (${_available.length})',
            selected: _tab == 0,
            onTap: () => setState(() => _tab = 0),
          ),
          const SizedBox(width: 10),
          _TabBtn(
            label: 'My Deliveries',
            selected: _tab == 1,
            onTap: () => setState(() => _tab = 1),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableList() {
    if (_available.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox_outlined, size: 64, color: AppColors.textHint),
            const SizedBox(height: 16),
            Text('No orders available', style: AppTextStyles.headlineMedium),
            const SizedBox(height: 8),
            Text('Orders ready for delivery will appear here',
                style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _available.length,
      itemBuilder: (_, i) => _DeliveryCard(
        order: _available[i],
        actionLabel: 'Accept Delivery',
        actionColor: const Color(0xFF00BCD4),
        onAction: () => _acceptDelivery(_available[i]),
        onAiBrief: () => _showDeliveryAiBrief(context, _available[i]),
      ),
    );
  }

  Widget _buildMyDeliveries() {
    if (_mine.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.delivery_dining_outlined,
                size: 64, color: AppColors.textHint),
            const SizedBox(height: 16),
            Text('No deliveries yet', style: AppTextStyles.headlineMedium),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _mine.length,
      itemBuilder: (_, i) {
        final o = _mine[i];
        return _DeliveryCard(
          order: o,
          actionLabel: o.status == OrderStatus.outForDelivery
              ? 'Mark Delivered'
              : 'Delivered ✓',
          actionColor: o.status == OrderStatus.outForDelivery
              ? const Color(0xFF4CAF50)
              : AppColors.textHint,
          onAction: o.status == OrderStatus.outForDelivery
              ? () => _markDelivered(o)
              : null,
          onAiBrief: () => _showDeliveryAiBrief(context, o),
        );
      },
    );
  }

  Future<void> _acceptDelivery(DressOrder order) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final myEmail = AppState.instance.profile?.email ?? '';
    await FirebaseFirestore.instance.collection('orders').doc(order.id).update({
      'status': OrderStatus.outForDelivery.name,
      'deliveryPartnerId': uid,
    });
    // Increment total deliveries count
    if (myEmail.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('subscriptions')
          .doc(myEmail.toLowerCase())
          .update({'totalDeliveries': FieldValue.increment(1)});
    }
    _loadData();
  }

  Future<void> _markDelivered(DressOrder order) async {
    await FirebaseFirestore.instance.collection('orders').doc(order.id).update({
      'status': OrderStatus.delivered.name,
    });
    _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order marked as delivered!'),
          backgroundColor: Color(0xFF4CAF50),
        ),
      );
    }
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const _StatCard(
      {required this.label,
      required this.value,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 6,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(value,
                style: AppTextStyles.displayMedium
                    .copyWith(color: color, fontSize: 20)),
            Text(label, style: AppTextStyles.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _TabBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TabBtn({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.divider),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _DeliveryPayoutStrip extends StatelessWidget {
  final List<OrderPayoutLine> ledger;

  const _DeliveryPayoutStrip({required this.ledger});

  @override
  Widget build(BuildContext context) {
    OrderPayoutLine? line;
    for (final l in ledger) {
      if (l.role == 'delivery') {
        line = l;
        break;
      }
    }
    if (line == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF00BCD4).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF00BCD4).withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Advance share (delivery)',
            style: AppTextStyles.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
              color: const Color(0xFF006064),
            ),
          ),
          Text(
            '₹${line.amount.toStringAsFixed(2)}',
            style: AppTextStyles.titleMedium.copyWith(
              color: const Color(0xFF00838F),
            ),
          ),
          if (line.creditToUpi != null && line.creditToUpi!.isNotEmpty)
            Text(
              'Ledger UPI: ${line.creditToUpi}',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
            ),
        ],
      ),
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  final DressOrder order;
  final String actionLabel;
  final Color actionColor;
  final VoidCallback? onAction;
  final VoidCallback onAiBrief;

  const _DeliveryCard({
    required this.order,
    required this.actionLabel,
    required this.actionColor,
    this.onAction,
    required this.onAiBrief,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF00BCD4).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.checkroom_rounded,
                    color: Color(0xFF00BCD4), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.dressType, style: AppTextStyles.titleMedium),
                    Text('₹${order.price.toInt()}',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.primary)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: order.status.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  order.status.label,
                  style: AppTextStyles.bodySmall.copyWith(
                      color: order.status.color, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (order.deliveryAddress != null && order.deliveryAddress!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_rounded,
                    size: 16, color: AppColors.textHint),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(order.deliveryAddress!,
                      style: AppTextStyles.bodySmall),
                ),
              ],
            ),
          ],
          if (order.payoutLedger != null) ...[
            const SizedBox(height: 10),
            _DeliveryPayoutStrip(ledger: order.payoutLedger!),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onAiBrief,
              icon: const Icon(Icons.auto_awesome_outlined, size: 18),
              label: const Text('AI pickup / drop tips'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: onAction != null ? actionColor : AppColors.divider,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: Text(actionLabel,
                  style: AppTextStyles.labelMedium.copyWith(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
