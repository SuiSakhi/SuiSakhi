import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/dress.dart';
import '../../models/prd_catalog.dart';
import '../../core/app_state.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  /// 0 All, 1 Active, 2 Pending, 3 Delivered, 4 On the way
  int _filterIndex = 0;
  List<DressOrder> _orders = [];
  List<_OrderDraftSummary> _draftOrders = [];
  bool _loading = true;
  bool _loadingDrafts = true;

  @override
  void initState() {
    super.initState();
    _loadOrders();
    _loadDraftOrders();
  }

  Future<void> _loadDraftOrders() async {
    final phone = FirebaseAuth.instance.currentUser?.phoneNumber;

    if (phone == null || phone.trim().isEmpty) {
      if (mounted) {
        setState(() => _loadingDrafts = false);
      }
      return;
    }

    try {
      final accountId =
          await AppState.instance.fetchAccountIdForMobile(phone.trim());

      if (accountId == null || accountId.isEmpty) {
        if (mounted) {
          setState(() => _loadingDrafts = false);
        }
        return;
      }

      final snap = await FirebaseFirestore.instance
          .collection('order_drafts')
          .where('accountId', isEqualTo: accountId)
          .get();

      final drafts = snap.docs
          .map((doc) => _OrderDraftSummary.fromFirestore(doc.id, doc.data()))
          .where((draft) => draft.status == 'draft')
          .toList();

      drafts.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      if (!mounted) return;

      setState(() {
        _draftOrders = drafts;
        _loadingDrafts = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() => _loadingDrafts = false);
    }
  }

  Future<void> _discardDraftOrder(_OrderDraftSummary draft) async {
    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Discard Draft?'),
          content: Text(
            'Discard ${draft.dressType} draft?\n\n'
            'This draft will be removed from Draft Orders. '
            'It will be archived in the background and can be recovered later when Archived Drafts is available.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Discard'),
            ),
          ],
        );
      },
    );

    if (shouldDiscard != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('order_drafts')
          .doc(draft.draftId)
          .set(
        {
          'status': 'archived',
          'archivedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;

      setState(() {
        _draftOrders.removeWhere((item) => item.draftId == draft.draftId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Draft discarded'),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to discard draft. Please try again.'),
        ),
      );
    }
  }

  Future<void> _loadOrders() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final snap = await FirebaseFirestore.instance
          .collection('orders')
          .where('customerId', isEqualTo: uid)
          .get();
      if (mounted) {
        setState(() {
          _orders = snap.docs.map((d) => _orderFromDoc(d)).toList()
            ..sort((a, b) => b.orderDate.compareTo(a.orderDate));
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  static DressOrder _orderFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    return DressOrder.fromFirestore(d.id, d.data());
  }

  List<DressOrder> get _filtered {
    bool active(DressOrder o) =>
        o.status != OrderStatus.delivered && o.status != OrderStatus.cancelled;
    switch (_filterIndex) {
      case 1:
        return _orders.where(active).toList();
      case 2:
        return _orders.where((o) => o.status == OrderStatus.pending).toList();
      case 3:
        return _orders.where((o) => o.status == OrderStatus.delivered).toList();
      case 4:
        return _orders
            .where((o) => o.status == OrderStatus.outForDelivery)
            .toList();
      default:
        return _orders;
    }
  }

  /// [context.go('/orders')] leaves no stack entry, so [pop] does nothing.
  void _leaveOrders(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.go('/home');
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('My Orders'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded),
            onPressed: () => _leaveOrders(context),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _buildSummaryCards(),
                  _buildFilterChips(),
                  Expanded(
                    child: _filtered.isEmpty && _draftOrders.isEmpty
                        ? _buildEmptyState()
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                            children: [
                              _buildDraftOrdersSection(),
                              if (_draftOrders.isNotEmpty && _filtered.isNotEmpty)
                                const SizedBox(height: 14),
                              if (_filtered.isNotEmpty)
                                ..._filtered.map((order) => _OrderCard(order: order)),
                            ],
                          ),
                  ),
                ],
              ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              await context.push('/designer');

              if (!mounted) return;

              setState(() {
                _loading = true;
                _loadingDrafts = true;
              });

              await _loadOrders();
              await _loadDraftOrders();
            },
          backgroundColor: AppColors.primary,
          icon: const Icon(Icons.add, color: Colors.white),
          label: Text(
            'New Order',
            style: AppTextStyles.labelLarge.copyWith(color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    final active = _orders
        .where((o) =>
            o.status != OrderStatus.delivered && o.status != OrderStatus.cancelled)
        .length;
    final ready =
        _orders.where((o) => o.status == OrderStatus.readyForPickup).length;
    final total = _orders.length;
    final drafts = _draftOrders.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          _SummaryChip(
            label: 'Total',
            count: total,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          _SummaryChip(
            label: 'Active',
            count: active,
            color: const Color(0xFF2196F3),
          ),
          const SizedBox(width: 8),
          _SummaryChip(
            label: 'Ready',
            count: ready,
            color: const Color(0xFF9C27B0),
          ),
          const SizedBox(width: 8),
          _SummaryChip(
            label: 'Drafts',
            count: drafts,
            color: const Color(0xFFFF9800),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    const filters = ['All', 'Active', 'Pending', 'Delivered', 'On the way'];

    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final selected = _filterIndex == i;
          return GestureDetector(
            onTap: () => setState(() => _filterIndex = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.divider,
                ),
              ),
              child: Text(
                filters[i],
                style: AppTextStyles.labelMedium.copyWith(
                  color: selected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDraftOrdersSection() {
    if (_loadingDrafts) {
      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.divider),
        ),
        child: const LinearProgressIndicator(),
      );
    }

    if (_draftOrders.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Draft Orders',
              style: AppTextStyles.headlineMedium,
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_draftOrders.length}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ..._draftOrders.map(
          (draft) => _DraftOrderCard(
            draft: draft,
            onResume: () async {
              await context.push(
                '/designer?orderDraftId=${Uri.encodeComponent(draft.draftId)}',
              );

              if (!mounted) return;

              setState(() {
                _loading = true;
                _loadingDrafts = true;
              });

              await _loadOrders();
              await _loadDraftOrders();
            },
            onDiscard: () {
              _discardDraftOrder(draft);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.receipt_long_outlined,
              size: 64, color: AppColors.textHint),
          const SizedBox(height: 16),
          Text('No orders yet', style: AppTextStyles.headlineMedium),
          const SizedBox(height: 8),
          Text('Tap "+ New Order" to place your first order',
              style: AppTextStyles.bodyMedium),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _SummaryChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: AppTextStyles.headlineLarge.copyWith(color: color),
            ),
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _occasionDisplayName(String id) {
  for (final o in OccasionCategory.values) {
    if (o.name == id) return o.displayName;
  }
  return id;
}

class _OrderCard extends StatelessWidget {
  final DressOrder order;
  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: order.status.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.checkroom_rounded,
                  color: order.status.color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (order.orderModuleType != OrderModuleType.coreTailoring)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          order.orderModuleType.label,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    Text(
                      order.dressType,
                      style: AppTextStyles.headlineSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (order.tailorName.isNotEmpty)
                      Text(
                        order.tailorName,
                        style: AppTextStyles.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (order.occasionCategory != null &&
                        order.orderModuleType == OrderModuleType.coreTailoring)
                      Text(
                        _occasionDisplayName(order.occasionCategory!),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textHint,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: order.status.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    order.status.label,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: order.status.color,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          if (order.orderModuleType.label.toLowerCase() == 'bulk')
            _buildBulkRequestInfo(order)
          else
            _buildOrderForInfo(order),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              _infoItem(Icons.calendar_today_outlined,
                  _formatDate(order.orderDate), 'Ordered'),
              const SizedBox(width: 16),
              if (order.deliveryDate != null)
                _infoItem(Icons.local_shipping_outlined,
                    _formatDate(order.deliveryDate!), 'Delivery'),
              const Spacer(),
              Text(
                '₹${order.price.toInt()}',
                style: AppTextStyles.headlineSmall.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          if (order.fabricDescription != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.texture_rounded,
                    size: 16, color: AppColors.textHint),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    order.fabricDescription!,
                    style: AppTextStyles.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          if (order.deliveryAddress != null &&
              order.deliveryAddress!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_rounded,
                    size: 16, color: AppColors.textHint),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(order.deliveryAddress!,
                      style: AppTextStyles.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: order.paymentStatus.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.currency_rupee_rounded,
                        size: 12, color: order.paymentStatus.color),
                    const SizedBox(width: 2),
                    Text(order.paymentStatus.label,
                        style: AppTextStyles.bodySmall.copyWith(
                            color: order.paymentStatus.color,
                            fontWeight: FontWeight.w600,
                            fontSize: 11)),
                  ],
                ),
              ),
              if (order.deliveryFee > 0) ...[
                const SizedBox(width: 8),
                Text('+ ₹${order.deliveryFee.toInt()} delivery',
                    style: AppTextStyles.bodySmall),
              ],
            ],
          ),
          if (order.price > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Advance ${order.advancePercent}% · ₹${order.advanceAmount.toStringAsFixed(0)} · '
              'Balance ₹${order.balanceAmount.toStringAsFixed(0)}',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
            ),
          ],
          if (order.paymentStatus == PaymentStatus.pendingPayment) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => context.push('/checkout/${order.id}'),
                child: const Text('Pay advance online'),
              ),
            ),
          ],
          if (order.status != OrderStatus.delivered &&
              order.status != OrderStatus.cancelled) ...[
            const SizedBox(height: 12),
            _buildProgressBar(order),
          ],
        ],
      ),
    );
  }

  Widget _buildOrderForInfo(DressOrder order) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.person_outline_rounded,
          size: 17,
          color: AppColors.textHint,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Order For: ${order.orderForText}',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildBulkRequestInfo(DressOrder order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _orderInfoLine(
          icon: Icons.person_outline_rounded,
          text: 'Requested By: ${order.requestedByText}',
        ),
        if (order.eventText != null)
          _orderInfoLine(
            icon: Icons.event_note_outlined,
            text: 'Event: ${order.eventText}',
          ),
        if (order.consultationText != null)
          _orderInfoLine(
            icon: Icons.support_agent_outlined,
            text: 'Consultation: ${order.consultationText}',
          ),
        if (order.eventDate != null)
          _orderInfoLine(
            icon: Icons.calendar_today_outlined,
            text: 'Event Date: ${_formatDate(order.eventDate!)}',
          ),
      ],
    );
  }

  Widget _orderInfoLine({
    required IconData icon,
    required String text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 16,
            color: AppColors.textHint,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoItem(IconData icon, String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: AppColors.textHint),
            const SizedBox(width: 4),
            Text(label, style: AppTextStyles.bodySmall),
          ],
        ),
        Text(value, style: AppTextStyles.titleMedium),
      ],
    );
  }

  Widget _buildProgressBar(DressOrder order) {
    final p = order.status.pipelineProgress;
    final pct = (p * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Order progress', style: AppTextStyles.bodySmall),
            Text(
              '$pct%',
              style: AppTextStyles.bodySmall.copyWith(
                color: const Color(0xFF2196F3),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: p,
            backgroundColor: AppColors.divider,
            valueColor: const AlwaysStoppedAnimation(Color(0xFF2196F3)),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }
}

class _OrderDraftSummary {
  final String draftId;
  final String dressType;
  final String personName;
  final String relationship;
  final String occasionCategory;
  final String status;
  final DateTime updatedAt;

  const _OrderDraftSummary({
    required this.draftId,
    required this.dressType,
    required this.personName,
    required this.relationship,
    required this.occasionCategory,
    required this.status,
    required this.updatedAt,
  });

  factory _OrderDraftSummary.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    final updatedAtRaw = data['updatedAt'];

    DateTime updatedAt = DateTime.now();

    if (updatedAtRaw is Timestamp) {
      updatedAt = updatedAtRaw.toDate();
    }

    return _OrderDraftSummary(
      draftId: data['draftId']?.toString() ?? id,
      dressType: data['dressType']?.toString() ?? 'Dress Draft',
      personName: data['personName']?.toString() ?? 'Customer',
      relationship: data['relationship']?.toString() ?? '',
      occasionCategory: data['occasionCategory']?.toString() ?? '',
      status: data['status']?.toString() ?? 'draft',
      updatedAt: updatedAt,
    );
  }

  String get personText {
    if (relationship.trim().isNotEmpty &&
        relationship.trim().toLowerCase() != 'self') {
      return '$personName ($relationship)';
    }

    return personName;
  }
}

  class _DraftOrderCard extends StatelessWidget {
    final _OrderDraftSummary draft;
    final VoidCallback onResume;
    final VoidCallback onDiscard;

    const _DraftOrderCard({
      required this.draft,
      required this.onResume,
      required this.onDiscard,
    });

  @override
  Widget build(BuildContext context) {
    final occasion = draft.occasionCategory.trim().isEmpty
        ? null
        : _occasionDisplayName(draft.occasionCategory);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.bookmark_border_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${draft.dressType} Draft',
                      style: AppTextStyles.headlineSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (occasion != null)
                      Text(
                        occasion,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textHint,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Draft',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _draftLine(
            icon: Icons.person_outline_rounded,
            text: 'For: ${draft.personText}',
          ),
          const SizedBox(height: 4),
          _draftLine(
            icon: Icons.schedule_rounded,
            text: 'Updated: ${_formatDraftDate(draft.updatedAt)}',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onResume,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Resume Draft'),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                tooltip: 'Discard Draft',
                onPressed: onDiscard,
                icon: const Icon(
                  Icons.archive_outlined,
                  color: AppColors.textHint,
                ),
              ),
            ],
          ),

        ],
      ),
    );
  }

  Widget _draftLine({
    required IconData icon,
    required String text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: AppColors.textHint,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDraftDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    return '${date.day} ${months[date.month - 1]}';
  }
}
