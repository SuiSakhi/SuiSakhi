import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_state.dart';
import '../../core/constants/app_colors.dart';
import '../../models/dress.dart';
import '../../services/customer_orders_overview_service.dart';
import '../../widgets/home/home_reference_artwork.dart';

class TailoringDashboardScreen extends StatefulWidget {
  const TailoringDashboardScreen({super.key});

  @override
  State<TailoringDashboardScreen> createState() =>
      _TailoringDashboardScreenState();
}

class _TailoringDashboardScreenState extends State<TailoringDashboardScreen> {
  CustomerOrdersOverview? _overview;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
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
    final orders = overview?.tailoringOrders ?? const <DressOrder>[];
    final active = orders
        .where(
          (order) =>
              order.status != OrderStatus.delivered &&
              order.status != OrderStatus.cancelled &&
              order.status != OrderStatus.outForDelivery,
        )
        .length;
    final delivery = orders
        .where((order) => order.status == OrderStatus.outForDelivery)
        .length;
    final completed = orders
        .where((order) => order.status == OrderStatus.delivered)
        .length;
    final drafts = overview?.drafts.length ?? 0;
    final alerts = overview?.tailoringAlerts ?? const <OrderDashboardAlert>[];
    final greetingName = AppState.instance.displayName.trim().split(' ').first;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
                sliver: SliverList.list(
                  children: [
                    _DashboardHeader(
                      alertCount: alerts.length,
                      onBack: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/home');
                        }
                      },
                      onAlerts: () =>
                          context.push('/customer-orders?tab=alerts'),
                    ),
                    const SizedBox(height: 16),
                    _WelcomeBanner(name: greetingName),
                    const SizedBox(height: 22),
                    const Text(
                      'What would you like to do?',
                      style: TextStyle(
                        color: Color(0xFF24113F),
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const _QuickActions(),
                    const SizedBox(height: 22),
                    _SectionHeading(
                      title: 'Order Status at a Glance',
                      action: 'View All Orders',
                      onTap: () => context.push('/customer-orders'),
                    ),
                    const SizedBox(height: 10),
                    if (_error != null)
                      _LoadErrorCard(onRetry: _load)
                    else
                      _OrderStatusOverview(
                        loading: _loading,
                        inProgress: active,
                        delivery: delivery,
                        completed: completed,
                        drafts: drafts,
                        onTap: (tab) => context.push(
                          '/customer-orders?tab=${Uri.encodeComponent(tab)}',
                        ),
                      ),
                    const SizedBox(height: 16),
                    _RecentAlertsCard(
                      alerts: alerts,
                      loading: _loading,
                      onTap: () => context.push('/customer-orders?tab=alerts'),
                      onOpenOrder: (order) => context.push(
                        '/orders?module=coreTailoring&orderId=${Uri.encodeComponent(order.id)}',
                      ),
                    ),
                    const SizedBox(height: 22),
                    _SectionHeading(
                      title: 'Recent Orders',
                      action: 'View All',
                      onTap: () => context.push('/customer-orders'),
                    ),
                    const SizedBox(height: 10),
                    if (_loading && overview == null)
                      const _LoadingOrdersCard()
                    else if (_error != null)
                      _LoadErrorCard(onRetry: _load)
                    else if (orders.isEmpty)
                      _NoRecentOrdersCard(
                        onPlaceOrder: () =>
                            context.push('/designer?entry=order'),
                      )
                    else
                      ...orders
                          .take(3)
                          .map(
                            (order) => Padding(
                              padding: const EdgeInsets.only(bottom: 9),
                              child: _RecentOrderTile(
                                order: order,
                                onTap: () => context.push(
                                  '/orders?module=coreTailoring&orderId=${Uri.encodeComponent(order.id)}',
                                ),
                              ),
                            ),
                          ),
                    const SizedBox(height: 18),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _DashboardBottomBar(
        onHome: () => context.go('/'),
        onOrders: () => context.go('/customer-orders'),
        onNewOrder: () => context.push('/designer?entry=order'),
        onWishlist: () => context.push('/wishlist'),
        onMore: () => context.push('/account'),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.alertCount,
    required this.onBack,
    required this.onAlerts,
  });

  final int alertCount;
  final VoidCallback onBack;
  final VoidCallback onAlerts;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(
        tooltip: 'Back',
        visualDensity: VisualDensity.compact,
        onPressed: onBack,
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      Image.asset(
        'assets/images/suisakhi_logo.png',
        width: 42,
        height: 44,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const Icon(
          Icons.checkroom_rounded,
          color: AppColors.primary,
          size: 34,
        ),
      ),
      const SizedBox(width: 6),
      const Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SuiSakhi',
              style: TextStyle(
                color: Color(0xFF81165F),
                fontSize: 21,
                height: 1,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Stitching · Care · Convenience',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Color(0xFF7A6686), fontSize: 10),
            ),
          ],
        ),
      ),
      IconButton(
        tooltip: 'Order alerts',
        onPressed: onAlerts,
        icon: Badge(
          isLabelVisible: alertCount > 0,
          label: Text('$alertCount'),
          child: const Icon(Icons.notifications_none_rounded),
        ),
      ),
      const SizedBox(width: 2),
      Material(
        color: const Color(0xFFFCE4F0),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => context.push('/account'),
          child: SizedBox(
            width: 42,
            height: 42,
            child: Center(
              child: ListenableBuilder(
                listenable: AppState.instance,
                builder: (context, _) {
                  final photo = AppState.instance.profile?.photoUrl;
                  if (photo?.isNotEmpty == true) {
                    return ClipOval(
                      child: Image.network(
                        photo!,
                        width: 42,
                        height: 42,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.person_outline_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                    );
                  }
                  return const Icon(
                    Icons.person_outline_rounded,
                    color: AppColors.primary,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) => Container(
    height: 166,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(22),
      gradient: const LinearGradient(
        colors: [Color(0xFFFFEAF3), Color(0xFFFFF7FB)],
      ),
    ),
    child: Stack(
      children: [
        Positioned(
          right: -10,
          top: 0,
          bottom: 0,
          width: 190,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: HomeReferenceArtwork(
              sourceRect: const Rect.fromLTWH(374, 108, 474, 308),
              placeholderColor: const Color(0xFFFFEAF3),
            ),
          ),
        ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFFFF1F7),
                  Color(0xD9FFF1F7),
                  Color(0x00FFF1F7),
                ],
                stops: [0, 0.54, 1],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 12, 14),
          child: SizedBox(
            width: MediaQuery.sizeOf(context).width * 0.53,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Welcome back, $name!',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF261046),
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Your tailoring & stitching journey is just a tap away.',
                  style: TextStyle(
                    color: Color(0xFF35204F),
                    fontSize: 13,
                    height: 1.28,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Beautiful outfits, made for you ♡',
                  style: TextStyle(
                    color: Color(0xFFB70D72),
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  static const _actions =
      <
        ({
          String title,
          String subtitle,
          IconData icon,
          Color color,
          Color background,
          String route,
        })
      >[
        (
          title: 'Place New\nStitching Order',
          subtitle: 'Get your dream outfit stitched',
          icon: Icons.checkroom_outlined,
          color: Color(0xFFB31972),
          background: Color(0xFFFFF0F6),
          route: '/designer?entry=order',
        ),
        (
          title: 'All My Orders',
          subtitle: 'Track, view & manage your orders',
          icon: Icons.receipt_long_outlined,
          color: Color(0xFF7934A8),
          background: Color(0xFFF7F0FF),
          route: '/customer-orders',
        ),
        (
          title: 'My Wishlist',
          subtitle: 'Save your favorite designs',
          icon: Icons.favorite_border_rounded,
          color: Color(0xFF008D58),
          background: Color(0xFFEBFFF5),
          route: '/wishlist',
        ),
        (
          title: 'AI Measurement\n& Fabric Estimation',
          subtitle: 'Size and fabric suggestions',
          icon: Icons.camera_alt_outlined,
          color: Color(0xFF0085C5),
          background: Color(0xFFEDF8FF),
          route: '/measurements',
        ),
      ];

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth > 620 ? 4 : 2;
      return GridView.builder(
        itemCount: _actions.length,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: 9,
          mainAxisSpacing: 9,
          childAspectRatio: columns == 4 ? 0.87 : 1.13,
        ),
        itemBuilder: (context, index) {
          final action = _actions[index];
          return Material(
            color: action.background,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => context.push(action.route),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: action.color.withValues(alpha: 0.12),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(action.icon, color: action.color, size: 30),
                    const SizedBox(height: 8),
                    Text(
                      action.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF261046),
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        height: 1.18,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      action.subtitle,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF756A8B),
                        fontSize: 11,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.action, this.onTap});

  final String title;
  final String? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            color: Color(0xFF261046),
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      if (action != null)
        TextButton.icon(
          onPressed: onTap,
          iconAlignment: IconAlignment.end,
          icon: const Icon(Icons.arrow_forward_rounded, size: 16),
          label: Text(action!),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF951C83),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
        ),
    ],
  );
}

class _OrderStatusOverview extends StatelessWidget {
  const _OrderStatusOverview({
    required this.loading,
    required this.inProgress,
    required this.delivery,
    required this.completed,
    required this.drafts,
    required this.onTap,
  });

  final bool loading;
  final int inProgress;
  final int delivery;
  final int completed;
  final int drafts;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFFFFFEFF),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFF2E8F0)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A5E2850),
          blurRadius: 14,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 1.58,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _StatusTile(
          label: 'In Progress',
          count: inProgress,
          icon: Icons.assignment_outlined,
          color: const Color(0xFF087BE5),
          background: const Color(0xFFF1F8FF),
          loading: loading,
          onTap: () => onTap('active'),
        ),
        _StatusTile(
          label: 'Out for Delivery',
          count: delivery,
          icon: Icons.local_shipping_outlined,
          color: const Color(0xFFE07C00),
          background: const Color(0xFFFFF8EF),
          loading: loading,
          onTap: () => onTap('active'),
        ),
        _StatusTile(
          label: 'Completed',
          count: completed,
          icon: Icons.check_circle_outline_rounded,
          color: const Color(0xFF009B60),
          background: const Color(0xFFF1FFF8),
          loading: loading,
          onTap: () => onTap('completed'),
        ),
        _StatusTile(
          label: 'Draft',
          count: drafts,
          icon: Icons.description_outlined,
          color: const Color(0xFF6C7289),
          background: const Color(0xFFF8F8FB),
          loading: loading,
          onTap: () => onTap('drafts'),
        ),
      ],
    ),
  );
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
    required this.background,
    required this.loading,
    required this.onTap,
  });

  final String label;
  final int count;
  final IconData icon;
  final Color color;
  final Color background;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: background,
    borderRadius: BorderRadius.circular(15),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.11),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    loading ? '—' : '$count',
                    style: TextStyle(
                      color: color,
                      fontSize: 20,
                      height: 1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    maxLines: 2,
                    softWrap: true,
                    style: TextStyle(color: color, fontSize: 10, height: 1.05),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: color),
          ],
        ),
      ),
    ),
  );
}

class _RecentAlertsCard extends StatelessWidget {
  const _RecentAlertsCard({
    required this.alerts,
    required this.loading,
    required this.onTap,
    required this.onOpenOrder,
  });

  final List<OrderDashboardAlert> alerts;
  final bool loading;
  final VoidCallback onTap;
  final ValueChanged<DressOrder> onOpenOrder;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFFFFF2F7),
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF7DCE8)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(
                  Icons.notifications_active_outlined,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 9),
                const Expanded(
                  child: Text(
                    'Recent Alerts',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (alerts.isNotEmpty)
                  _CountBadge(count: alerts.length, color: AppColors.primary),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.primary,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (loading && alerts.isEmpty)
              const LinearProgressIndicator(minHeight: 2)
            else if (alerts.isEmpty)
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'You’re all caught up. Order updates will appear here.',
                  style: TextStyle(color: Color(0xFF6B5B79), fontSize: 13),
                ),
              )
            else
              ...alerts
                  .take(2)
                  .map(
                    (alert) => Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: InkWell(
                        onTap: () => onOpenOrder(alert.order),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              const Text(
                                '•',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 20,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${alert.title} · ${_orderNumber(alert.order)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF35204F),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    ),
  );
}

class _RecentOrderTile extends StatelessWidget {
  const _RecentOrderTile({required this.order, required this.onTap});

  final DressOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(17),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: const Color(0xFFF0E7EF)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x075E2850),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            _DressImage(url: order.designImageUrl),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order ${_orderNumber(order)}',
                    style: const TextStyle(
                      color: Color(0xFF24113F),
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    order.dressType.isEmpty
                        ? 'Stitching order'
                        : order.dressType,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF776C8B),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Placed ${MaterialLocalizations.of(context).formatMediumDate(order.orderDate.toLocal())}',
                    style: const TextStyle(
                      color: Color(0xFF8A86A0),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _OrderStatusChip(order: order),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF9B94AF)),
          ],
        ),
      ),
    ),
  );
}

class _DressImage extends StatelessWidget {
  const _DressImage({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: Container(
      width: 58,
      height: 64,
      color: const Color(0xFFFFEAF2),
      child: url?.trim().isNotEmpty == true
          ? Image.network(
              url!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(
                Icons.checkroom_outlined,
                color: AppColors.primary,
              ),
            )
          : const Icon(Icons.checkroom_outlined, color: AppColors.primary),
    ),
  );
}

class _OrderStatusChip extends StatelessWidget {
  const _OrderStatusChip({required this.order});

  final DressOrder order;

  @override
  Widget build(BuildContext context) {
    final color = switch (order.status) {
      OrderStatus.delivered => const Color(0xFF008B58),
      OrderStatus.outForDelivery => const Color(0xFFD06A00),
      OrderStatus.cancelled => const Color(0xFFAF3349),
      _ => const Color(0xFF087BE5),
    };
    final label = switch (order.status) {
      OrderStatus.delivered => 'Completed',
      _ => order.status.label,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      '$count',
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: 11,
      ),
    ),
  );
}

class _LoadErrorCard extends StatelessWidget {
  const _LoadErrorCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.divider),
    ),
    child: Row(
      children: [
        const Expanded(
          child: Text('Could not load your orders. Please retry.'),
        ),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}

class _LoadingOrdersCard extends StatelessWidget {
  const _LoadingOrdersCard();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 22),
    child: Center(child: CircularProgressIndicator()),
  );
}

class _NoRecentOrdersCard extends StatelessWidget {
  const _NoRecentOrdersCard({required this.onPlaceOrder});

  final VoidCallback onPlaceOrder;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.divider),
    ),
    child: Row(
      children: [
        const Expanded(
          child: Text(
            'Your stitching orders will appear here once you place one.',
          ),
        ),
        TextButton(onPressed: onPlaceOrder, child: const Text('Start')),
      ],
    ),
  );
}

class _DashboardBottomBar extends StatelessWidget {
  const _DashboardBottomBar({
    required this.onHome,
    required this.onOrders,
    required this.onNewOrder,
    required this.onWishlist,
    required this.onMore,
  });

  final VoidCallback onHome;
  final VoidCallback onOrders;
  final VoidCallback onNewOrder;
  final VoidCallback onWishlist;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 6),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _BottomBarItem(
            icon: Icons.home_rounded,
            label: 'Home',
            selected: true,
            onTap: onHome,
          ),
          _BottomBarItem(
            icon: Icons.receipt_long_outlined,
            label: 'Orders',
            onTap: onOrders,
          ),
          Material(
            color: AppColors.primary,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onNewOrder,
              child: const SizedBox(
                width: 54,
                height: 54,
                child: Icon(Icons.add_rounded, color: Colors.white, size: 32),
              ),
            ),
          ),
          _BottomBarItem(
            icon: Icons.favorite_border_rounded,
            label: 'Wishlist',
            onTap: onWishlist,
          ),
          _BottomBarItem(
            icon: Icons.more_horiz_rounded,
            label: 'More',
            onTap: onMore,
          ),
        ],
      ),
    ),
  );
}

class _BottomBarItem extends StatelessWidget {
  const _BottomBarItem({
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
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: SizedBox(
      width: 58,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: selected ? AppColors.primary : const Color(0xFF777993),
            size: 22,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.primary : const Color(0xFF777993),
              fontSize: 10,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
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
