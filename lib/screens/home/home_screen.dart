import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/app_state.dart';
import '../../models/dress.dart';
import '../../widgets/common/measurement_card.dart';
import '../../widgets/home/customer_home_groups_section.dart';

/// Uses the device local clock ([DateTime.now]).
String _homeGreeting() {
  final hour = DateTime.now().hour;
  if (hour >= 5 && hour < 12) return 'Good Morning! 👋';
  if (hour >= 12 && hour < 17) return 'Good Afternoon! 👋';
  if (hour >= 17 && hour < 22) return 'Good Evening! 👋';
  return 'Hello! 👋';
}

void _showHomeNotificationsSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              size: 48,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 16),
            Text('Notifications', style: AppTextStyles.titleLarge),
            const SizedBox(height: 8),
            Text(
              'You have no notifications yet. Order updates and offers will appear here.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _bottomNavIndex = 0;

  final List<Widget> _pages = const [
    _HomeContent(),
    _PlaceholderPage(icon: Icons.straighten_rounded, label: 'Measurements'),
    _PlaceholderPage(icon: Icons.checkroom_rounded, label: 'Catalog'),
    _PlaceholderPage(icon: Icons.receipt_long_rounded, label: 'Orders'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(index: _bottomNavIndex, children: _pages),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: BottomNavigationBar(
          currentIndex: _bottomNavIndex,
          onTap: (i) {
            if (i == 1) {
              context.push('/measurements');
              return;
            }
            if (i == 2) {
              context.push('/catalog');
              return;
            }
            if (i == 3) {
              context.push('/orders');
              return;
            }
            setState(() => _bottomNavIndex = i);
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.straighten_outlined),
              activeIcon: Icon(Icons.straighten_rounded),
              label: 'Measure',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.checkroom_outlined),
              activeIcon: Icon(Icons.checkroom_rounded),
              label: 'Catalog',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long_rounded),
              label: 'Orders',
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            _buildHeader(context),
            const SizedBox(height: 24),
            const CustomerHomeGroupsSection(),
            const SizedBox(height: 28),
            _buildPartnerRegistration(context),
            const SizedBox(height: 28),
            SectionHeader(
              title: 'Recent Orders',
              actionLabel: 'View all',
              onAction: () => context.push('/orders'),
            ),
            const SizedBox(height: 16),
            _buildRecentOrders(context),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildPartnerRegistration(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Register as a Partner'),
        const SizedBox(height: 12),
        Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => context.push('/partner/opportunities'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.handshake_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Become a Partner',
                          style: AppTextStyles.titleMedium,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Apply as a Tailor, Designer, Supplier or Service Partner',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textHint,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_homeGreeting(), style: AppTextStyles.bodyMedium),
              ListenableBuilder(
                listenable: AppState.instance,
                builder: (context, _) => Text(
                  AppState.instance.displayName,
                  style: AppTextStyles.displayMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Material(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: () => _showHomeNotificationsSheet(context),
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 46,
              height: 46,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Center(
                    child: Icon(
                      Icons.notifications_outlined,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: AppColors.secondary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push('/account'),
            child: Ink(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: ListenableBuilder(
                  listenable: AppState.instance,
                  builder: (context, _) {
                    final url = AppState.instance.profile?.photoUrl;
                    if (url != null && url.isNotEmpty) {
                      return Image.network(
                        url,
                        width: 46,
                        height: 46,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Text(
                          AppState.instance.initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      );
                    }
                    return Text(
                      AppState.instance.initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
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

  Widget _buildRecentOrders(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return _emptyOrders(context);

    return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('orders')
          .where('customerId', isEqualTo: uid)
          .limit(2)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return _emptyOrders(context);

        final orders = docs.map((d) {
          final data = d.data();
          final status = OrderStatus.values.firstWhere(
            (s) => s.name == (data['status'] as String? ?? 'pending'),
            orElse: () => OrderStatus.pending,
          );
          return (
            data['dressType'] as String? ?? '',
            status.label,
            status.color,
          );
        }).toList();

        return Column(
          children: orders.map((order) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.cardShadow,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: order.$3.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.checkroom_rounded,
                      color: order.$3,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.$1,
                          style: AppTextStyles.titleMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: order.$3.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        order.$2,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: order.$3,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _emptyOrders(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/smart-style-ideas'),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              size: 36,
              color: AppColors.textHint,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('No orders yet', style: AppTextStyles.titleMedium),
                  Text(
                    'Browse designs or start your first order',
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: AppColors.textHint,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderPage extends StatelessWidget {
  final IconData icon;
  final String label;
  const _PlaceholderPage({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 60, color: AppColors.textHint),
          const SizedBox(height: 16),
          Text(label, style: AppTextStyles.headlineMedium),
        ],
      ),
    );
  }
}
