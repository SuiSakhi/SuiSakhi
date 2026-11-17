import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_state.dart';
import '../../core/constants/app_colors.dart';
import '../../models/dress.dart';
import '../../models/prd_catalog.dart';
import '../../services/customer_orders_overview_service.dart';
import '../../services/garment_care_service.dart';

class CustomerOrdersHubScreen extends StatefulWidget {
  const CustomerOrdersHubScreen({super.key, this.initialTab});

  final String? initialTab;

  @override
  State<CustomerOrdersHubScreen> createState() =>
      _CustomerOrdersHubScreenState();
}

class _CustomerOrdersHubScreenState extends State<CustomerOrdersHubScreen> {
  CustomerOrdersOverview? _overview;
  Object? _error;
  bool _loading = true;
  String _selectedTab = 'active';

  @override
  void initState() {
    super.initState();
    _selectedTab = switch (widget.initialTab) {
      'completed' => 'completed',
      'drafts' => 'drafts',
      'alerts' => 'alerts',
      _ => 'active',
    };
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final overview = await CustomerOrdersOverview.load();
      if (!mounted) return;
      setState(() {
        _overview = overview;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final overview = _overview;
    final tailoringOrders = overview?.tailoringOrders ?? const <DressOrder>[];
    final activeOrders =
        overview?.activeTailoringOrders ?? const <DressOrder>[];
    final completedOrders =
        overview?.completedTailoringOrders ?? const <DressOrder>[];
    final drafts = overview?.drafts ?? const <CustomerOrderDraftSummary>[];
    final alerts = overview?.tailoringAlerts ?? const <OrderDashboardAlert>[];
    final quickCareOrders = (overview?.orders ?? const <DressOrder>[])
        .where((order) => order.orderModuleType == OrderModuleType.quickFix)
        .where(_isActiveCustomerOrder)
        .length;
    final name = AppState.instance.displayName.trim().isEmpty
        ? 'SuiSakhi Customer'
        : AppState.instance.displayName.trim();
    final lastOrder = tailoringOrders.isEmpty ? null : tailoringOrders.first;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF9FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF9FC),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primary),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Stitching Orders',
              style: TextStyle(
                color: Color(0xFF182447),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Manage orders, track progress & get alerts',
              style: TextStyle(color: Color(0xFF777F99), fontSize: 11),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh orders',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 5, 16, 20),
              sliver: SliverList.list(
                children: [
                  _WelcomeOrderCard(
                    name: name,
                    activeCount: activeOrders.length,
                    lastOrder: lastOrder,
                  ),
                  const SizedBox(height: 12),
                  _OrderServiceCategories(
                    stitchingCount: activeOrders.length,
                    draftCount: drafts.length,
                    quickCareCount: quickCareOrders,
                    onStitching: () => setState(() => _selectedTab = 'active'),
                    onGarmentCare: () => context.push('/garment-care/orders'),
                    onQuickCare: () => context.push('/orders?module=quickFix'),
                    onRentals: () => context.push('/dress-rental-request'),
                  ),
                  const SizedBox(height: 16),
                  _OrderTabs(
                    selected: _selectedTab,
                    active: activeOrders.length,
                    completed: completedOrders.length,
                    drafts: drafts.length,
                    alerts: alerts.length,
                    onSelect: (tab) => setState(() => _selectedTab = tab),
                  ),
                  const SizedBox(height: 14),
                  if (_error != null)
                    _OrdersLoadError(onRetry: _load)
                  else if (_loading && overview == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 44),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    _buildSelectedContent(
                      activeOrders: activeOrders,
                      completedOrders: completedOrders,
                      drafts: drafts,
                      alerts: alerts,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _OrdersBottomBar(
        onHome: () => context.go('/'),
        onServices: () => context.push('/service-guide'),
        onOrders: () => context.go('/customer-orders'),
        onChat: () => context.push('/support'),
        onProfile: () => context.push('/account'),
      ),
    );
  }

  Widget _buildSelectedContent({
    required List<DressOrder> activeOrders,
    required List<DressOrder> completedOrders,
    required List<CustomerOrderDraftSummary> drafts,
    required List<OrderDashboardAlert> alerts,
  }) {
    switch (_selectedTab) {
      case 'completed':
        return completedOrders.isEmpty
            ? _EmptyOrdersState(
                title: 'No completed orders yet',
                message: 'Finished orders will appear here.',
                icon: Icons.check_circle_outline_rounded,
              )
            : Column(
                children: completedOrders
                    .map((order) => _OrderCard(order: order, completed: true))
                    .toList(),
              );
      case 'drafts':
        return drafts.isEmpty
            ? _EmptyOrdersState(
                title: 'No saved drafts',
                message:
                    'If you leave an order before submitting it, you can resume it here.',
                icon: Icons.description_outlined,
              )
            : Column(
                children: drafts
                    .map((draft) => _DraftOrderCard(draft: draft))
                    .toList(),
              );
      case 'alerts':
        return alerts.isEmpty
            ? _EmptyOrdersState(
                title: 'You’re all caught up',
                message: 'There are no order actions waiting for you.',
                icon: Icons.notifications_none_rounded,
              )
            : Column(
                children: alerts
                    .map((alert) => _AlertOrderCard(alert: alert))
                    .toList(),
              );
      default:
        return activeOrders.isEmpty
            ? _EmptyOrdersState(
                title: 'No active stitching orders',
                message: 'Place an order and follow every step from here.',
                icon: Icons.checkroom_outlined,
                actionLabel: 'Place an order',
                onAction: () => context.push('/designer?entry=order'),
              )
            : Column(
                children: activeOrders
                    .map((order) => _OrderCard(order: order))
                    .toList(),
              );
    }
  }
}

class _WelcomeOrderCard extends StatelessWidget {
  const _WelcomeOrderCard({
    required this.name,
    required this.activeCount,
    required this.lastOrder,
  });

  final String name;
  final int activeCount;
  final DressOrder? lastOrder;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(21),
      gradient: const LinearGradient(
        colors: [Color(0xFFFFEFF6), Color(0xFFFFE5F0)],
      ),
      border: Border.all(color: const Color(0xFFF9DAE7)),
    ),
    child: Row(
      children: [
        Container(
          width: 62,
          height: 62,
          decoration: const BoxDecoration(
            color: Color(0xFFFFF9FC),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.content_cut_rounded,
            color: AppColors.primary,
            size: 29,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Welcome back,',
                style: TextStyle(color: Color(0xFF68728E), fontSize: 12),
              ),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF182447),
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (lastOrder != null) ...[
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFDCEB),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Last order: ${MaterialLocalizations.of(context).formatMediumDate(lastOrder!.orderDate.toLocal())}',
                    style: const TextStyle(
                      color: Color(0xFF5E2448),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Container(height: 66, width: 1, color: const Color(0xFFEEC6D8)),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Active Orders',
              style: TextStyle(
                color: Color(0xFF182447),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '$activeCount',
              style: const TextStyle(
                color: Color(0xFF182447),
                fontSize: 29,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 2),
            Material(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                onTap: () => context.push('/orders?module=coreTailoring'),
                borderRadius: BorderRadius.circular(18),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  child: Row(
                    children: [
                      Text(
                        'View All',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _OrderServiceCategories extends StatelessWidget {
  const _OrderServiceCategories({
    required this.stitchingCount,
    required this.draftCount,
    required this.quickCareCount,
    required this.onStitching,
    required this.onGarmentCare,
    required this.onQuickCare,
    required this.onRentals,
  });

  final int stitchingCount;
  final int draftCount;
  final int quickCareCount;
  final VoidCallback onStitching;
  final VoidCallback onGarmentCare;
  final VoidCallback onQuickCare;
  final VoidCallback onRentals;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final cardWidth = (constraints.maxWidth - 9) / 2;
      return Wrap(
        spacing: 9,
        runSpacing: 9,
        children: [
          SizedBox(
            width: cardWidth,
            child: _ServiceCategoryCard(
              title: 'Stitching Orders',
              subtitle: '$stitchingCount Active · $draftCount Draft',
              icon: Icons.checkroom_outlined,
              color: const Color(0xFFD51278),
              background: const Color(0xFFFFF4F8),
              selected: true,
              badge: draftCount > 0 ? '$draftCount' : null,
              onTap: onStitching,
            ),
          ),
          SizedBox(
            width: cardWidth,
            child: _GarmentCareCategoryCard(onTap: onGarmentCare),
          ),
          SizedBox(
            width: cardWidth,
            child: _ServiceCategoryCard(
              title: 'Quick Care',
              subtitle: quickCareCount == 0
                  ? 'No active orders'
                  : '$quickCareCount Active',
              icon: Icons.local_shipping_outlined,
              color: const Color(0xFFDA8B00),
              background: const Color(0xFFFFFAF0),
              onTap: onQuickCare,
            ),
          ),
          SizedBox(
            width: cardWidth,
            child: _ServiceCategoryCard(
              title: 'Rentals',
              subtitle: 'Browse rental outfits',
              icon: Icons.event_available_outlined,
              color: const Color(0xFFAB39A2),
              background: const Color(0xFFFFF6FF),
              onTap: onRentals,
            ),
          ),
        ],
      );
    },
  );
}

class _GarmentCareCategoryCard extends StatelessWidget {
  const _GarmentCareCategoryCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: GarmentCareService.customerOrders(),
        builder: (context, snapshot) {
          var active = 0;
          for (final order in snapshot.data?.docs ?? const []) {
            final data = order.data();
            final status = data['statusProjection']?.toString();
            if (!{'completed', 'cancelled'}.contains(status) ||
                data['paymentActionRequired'] == true) {
              active += 1;
            }
          }
          return _ServiceCategoryCard(
            title: 'Garment Care',
            subtitle: snapshot.hasError
                ? 'Laundry & care orders'
                : snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData
                ? 'Loading your orders…'
                : active == 0
                ? 'No active orders'
                : '$active Active',
            icon: Icons.local_laundry_service_outlined,
            color: const Color(0xFF008DB0),
            background: const Color(0xFFF1FBFF),
            onTap: onTap,
          );
        },
      );
}

class _ServiceCategoryCard extends StatelessWidget {
  const _ServiceCategoryCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.background,
    required this.onTap,
    this.selected = false,
    this.badge,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color background;
  final VoidCallback onTap;
  final bool selected;
  final String? badge;

  @override
  Widget build(BuildContext context) => Material(
    color: background,
    borderRadius: BorderRadius.circular(17),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Container(
        height: 92,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.14),
            width: selected ? 1.3 : 1,
          ),
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 23),
                ),
                if (badge != null)
                  Positioned(
                    right: -5,
                    top: -7,
                    child: CircleAvatar(
                      radius: 9,
                      backgroundColor: color,
                      child: Text(
                        badge!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF182447),
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF777F99),
                      fontSize: 10,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _OrderTabs extends StatelessWidget {
  const _OrderTabs({
    required this.selected,
    required this.active,
    required this.completed,
    required this.drafts,
    required this.alerts,
    required this.onSelect,
  });

  final String selected;
  final int active;
  final int completed;
  final int drafts;
  final int alerts;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final tabs = <({String id, String title, int count, IconData icon})>[
      (
        id: 'active',
        title: 'Active',
        count: active,
        icon: Icons.format_list_bulleted_rounded,
      ),
      (
        id: 'completed',
        title: 'Completed',
        count: completed,
        icon: Icons.check_circle_outline_rounded,
      ),
      (
        id: 'drafts',
        title: 'Drafts',
        count: drafts,
        icon: Icons.description_outlined,
      ),
      (
        id: 'alerts',
        title: 'Alerts',
        count: alerts,
        icon: Icons.notifications_none_rounded,
      ),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFEDE5EE)),
      ),
      child: Row(
        children: [
          for (final tab in tabs)
            Expanded(
              child: InkWell(
                onTap: () => onSelect(tab.id),
                borderRadius: BorderRadius.circular(11),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 2,
                  ),
                  decoration: BoxDecoration(
                    color: selected == tab.id
                        ? AppColors.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        tab.icon,
                        size: 15,
                        color: selected == tab.id
                            ? Colors.white
                            : const Color(0xFF182447),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          tab.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: selected == tab.id
                                ? Colors.white
                                : const Color(0xFF182447),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: selected == tab.id
                              ? Colors.white.withValues(alpha: 0.2)
                              : const Color(0xFFFFE3EF),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${tab.count}',
                          style: TextStyle(
                            color: selected == tab.id
                                ? Colors.white
                                : AppColors.primary,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, this.completed = false});

  final DressOrder order;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final alert = OrderDashboardAlert.fromOrder(order);
    final eta = order.expectedReadyAt ?? order.deliveryDate;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: completed ? const Color(0xFFE4E8EF) : const Color(0xFFFFB8D6),
          width: completed ? 1 : 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A34213F),
            blurRadius: 11,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _OrderStatusPill(order: order),
              const Spacer(),
              if (eta != null)
                Row(
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      size: 14,
                      color: Color(0xFF845071),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Est. ${MaterialLocalizations.of(context).formatMediumDate(eta.toLocal())}',
                      style: const TextStyle(
                        color: Color(0xFF6D748C),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.receipt_long_outlined,
                color: AppColors.primary,
                size: 18,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  _orderNumber(order),
                  style: const TextStyle(
                    color: Color(0xFF182447),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                'Placed ${MaterialLocalizations.of(context).formatMediumDate(order.orderDate.toLocal())}',
                style: const TextStyle(color: Color(0xFF777F99), fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Padding(
            padding: const EdgeInsets.only(left: 25),
            child: Text(
              '${order.dressType.isEmpty ? 'Stitching' : order.dressType}${order.fit?.trim().isNotEmpty == true ? ' · ${order.fit}' : ''}${order.fabricChoice?.trim().isNotEmpty == true ? ' · ${order.fabricChoice}' : ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF68728E), fontSize: 11),
            ),
          ),
          const SizedBox(height: 14),
          _OrderProgressTimeline(order: order),
          if (alert != null) ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: () =>
                  context.push('/orders?module=coreTailoring&filter=active'),
              borderRadius: BorderRadius.circular(13),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0F5),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        '${alert.title}. ${alert.message}',
                        style: const TextStyle(
                          color: Color(0xFF9D174D),
                          fontSize: 11,
                          height: 1.25,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: AppColors.primary,
                      size: 17,
                    ),
                  ],
                ),
              ),
            ),
          ] else if (eta == null && !completed) ...[
            const SizedBox(height: 8),
            const Text(
              'We’ll show an estimated delivery date when your Tailor confirms it.',
              style: TextStyle(color: Color(0xFF777F99), fontSize: 10),
            ),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => context.push('/orders?module=coreTailoring'),
              icon: const Icon(Icons.arrow_forward_rounded, size: 15),
              label: const Text('Full Details'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderProgressTimeline extends StatelessWidget {
  const _OrderProgressTimeline({required this.order});

  final DressOrder order;

  @override
  Widget build(BuildContext context) {
    final completed = switch (order.status) {
      OrderStatus.delivered => 5,
      OrderStatus.outForDelivery => 4,
      OrderStatus.readyForPickup => 4,
      OrderStatus.qcPassed => 3,
      OrderStatus.qcPending => 3,
      OrderStatus.inStitching => 2,
      OrderStatus.atTailor => 1,
      OrderStatus.pickedUp => 1,
      OrderStatus.pending => 0,
      OrderStatus.cancelled => -1,
    };
    const labels = [
      'Confirmed',
      'At tailor',
      'Stitching',
      'Finishing & QC',
      'Delivery',
    ];
    return Row(
      children: [
        for (var index = 0; index < labels.length; index++) ...[
          Expanded(
            child: Column(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index < completed
                        ? AppColors.primary
                        : index == completed
                        ? const Color(0xFFE74B9A)
                        : Colors.white,
                    border: Border.all(
                      color: index <= completed
                          ? AppColors.primary
                          : const Color(0xFFE0D7E2),
                      width: 1.5,
                    ),
                  ),
                  child: index < completed
                      ? const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 13,
                        )
                      : index == completed
                      ? const Center(
                          child: CircleAvatar(
                            radius: 3,
                            backgroundColor: Colors.white,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 4),
                Text(
                  labels[index],
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: index <= completed
                        ? const Color(0xFF28314D)
                        : const Color(0xFF8B8CA0),
                    fontSize: 9,
                    fontWeight: index == completed
                        ? FontWeight.w700
                        : FontWeight.w500,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          if (index < labels.length - 1)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.only(bottom: 17),
                color: index + 1 < completed
                    ? AppColors.primary
                    : const Color(0xFFE9E2EA),
              ),
            ),
        ],
      ],
    );
  }
}

class _OrderStatusPill extends StatelessWidget {
  const _OrderStatusPill({required this.order});

  final DressOrder order;

  @override
  Widget build(BuildContext context) {
    final color = switch (order.status) {
      OrderStatus.delivered => const Color(0xFF009455),
      OrderStatus.outForDelivery => const Color(0xFF009455),
      OrderStatus.cancelled => const Color(0xFFAF3349),
      _ => const Color(0xFFD31372),
    };
    final label = switch (order.status) {
      OrderStatus.delivered => 'Completed Order',
      OrderStatus.outForDelivery => 'Out for Delivery',
      _ => order.status.label,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DraftOrderCard extends StatelessWidget {
  const _DraftOrderCard({required this.draft});

  final CustomerOrderDraftSummary draft;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 11),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF7FB),
      border: Border.all(color: const Color(0xFFF2D6E4)),
      borderRadius: BorderRadius.circular(17),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.description_outlined, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                draft.dressType,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF182447),
                ),
              ),
            ),
            const _SmallStatusBadge(label: 'Draft', color: Color(0xFFC03778)),
          ],
        ),
        const SizedBox(height: 7),
        Text(
          'For: ${draft.personName}',
          style: const TextStyle(color: Color(0xFF727891), fontSize: 12),
        ),
        const SizedBox(height: 3),
        Text(
          'Updated ${MaterialLocalizations.of(context).formatMediumDate(draft.updatedAt.toLocal())}',
          style: const TextStyle(color: Color(0xFF8A8DA2), fontSize: 11),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => context.push(
              '/designer?orderDraftId=${Uri.encodeComponent(draft.id)}',
            ),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Resume Draft'),
          ),
        ),
      ],
    ),
  );
}

class _AlertOrderCard extends StatelessWidget {
  const _AlertOrderCard({required this.alert});

  final OrderDashboardAlert alert;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF3F7),
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: const Color(0xFFF7DCE7)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CircleAvatar(
          radius: 18,
          backgroundColor: Color(0xFFFFDCE9),
          child: Icon(
            Icons.notifications_active_outlined,
            color: AppColors.primary,
            size: 19,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                alert.title,
                style: const TextStyle(
                  color: Color(0xFF9D174D),
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_orderNumber(alert.order)} · ${alert.message}',
                style: const TextStyle(
                  color: Color(0xFF6D748C),
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 7),
              TextButton(
                onPressed: () => context.push(
                  '/orders?module=coreTailoring&orderId=${Uri.encodeComponent(alert.order.id)}',
                ),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
                child: Text(alert.actionLabel),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SmallStatusBadge extends StatelessWidget {
  const _SmallStatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 10),
    ),
  );
}

class _EmptyOrdersState extends StatelessWidget {
  const _EmptyOrdersState({
    required this.title,
    required this.message,
    required this.icon,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFEFE7EF)),
    ),
    child: Column(
      children: [
        Icon(icon, size: 40, color: const Color(0xFFC3B3C4)),
        const SizedBox(height: 10),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF182447),
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF777F99),
            fontSize: 12,
            height: 1.35,
          ),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 12),
          FilledButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    ),
  );
}

class _OrdersLoadError extends StatelessWidget {
  const _OrdersLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => _EmptyOrdersState(
    title: 'Orders could not load',
    message: 'Check your connection and try again.',
    icon: Icons.cloud_off_outlined,
    actionLabel: 'Retry',
    onAction: onRetry,
  );
}

class _OrdersBottomBar extends StatelessWidget {
  const _OrdersBottomBar({
    required this.onHome,
    required this.onServices,
    required this.onOrders,
    required this.onChat,
    required this.onProfile,
  });

  final VoidCallback onHome;
  final VoidCallback onServices;
  final VoidCallback onOrders;
  final VoidCallback onChat;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      padding: const EdgeInsets.fromLTRB(4, 5, 4, 5),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 11,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          _BottomNavItem(
            icon: Icons.home_outlined,
            label: 'Home',
            onTap: onHome,
          ),
          _BottomNavItem(
            icon: Icons.grid_view_rounded,
            label: 'Services',
            onTap: onServices,
          ),
          _BottomNavItem(
            icon: Icons.checkroom_outlined,
            label: 'Orders',
            selected: true,
            onTap: onOrders,
          ),
          _BottomNavItem(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'Chat',
            onTap: onChat,
          ),
          _BottomNavItem(
            icon: Icons.person_outline_rounded,
            label: 'Profile',
            onTap: onProfile,
          ),
        ],
      ),
    ),
  );
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: selected ? AppColors.primary : const Color(0xFF65718A),
              size: 22,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.primary : const Color(0xFF65718A),
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

String _orderNumber(DressOrder order) {
  final tracking = order.orderTrackingId?.trim() ?? '';
  if (tracking.isNotEmpty) return '#$tracking';
  final id = order.id.trim();
  return '#${id.length > 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase()}';
}

bool _isActiveCustomerOrder(DressOrder order) {
  if (order.orderModuleType == OrderModuleType.quickFix) {
    final workflow = (order.quickCareWorkflowStatus ?? '')
        .replaceAllMapped(
          RegExp(r'([a-z])([A-Z])'),
          (match) => '${match.group(1)}_${match.group(2)}',
        )
        .toLowerCase()
        .replaceAll(RegExp(r'[\s-]+'), '_');
    return !const {'completed', 'cancelled'}.contains(workflow);
  }
  return order.status != OrderStatus.delivered &&
      order.status != OrderStatus.cancelled;
}
