import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/app_state.dart';
import '../../models/dress.dart';
import '../../models/prd_catalog.dart';
import '../../widgets/home/category_card.dart';
import '../../widgets/common/measurement_card.dart';
import '../../services/claude_smart_assistant_service.dart';

/// Uses the device local clock ([DateTime.now]).
String _homeGreeting() {
  final hour = DateTime.now().hour;
  if (hour >= 5 && hour < 12) return 'Good Morning! 👋';
  if (hour >= 12 && hour < 17) return 'Good Afternoon! 👋';
  if (hour >= 17 && hour < 22) return 'Good Evening! 👋';
  return 'Hello! 👋';
}

String _homeSeasonHint() {
  final m = DateTime.now().month;
  if (m == 11 || m == 12 || m == 1) return 'winter in India';
  if (m >= 3 && m <= 5) return 'hot summer in India';
  if (m >= 6 && m <= 9) return 'monsoon season in India';
  return 'festive season in India';
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

void _showDeliveryAddressSheet(BuildContext parentContext) {
  final ctrl = TextEditingController(
    text: AppState.instance.profile?.deliveryAddress ?? '',
  );
  showModalBottomSheet<void>(
    context: parentContext,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.viewInsetsOf(ctx).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Delivery address', style: AppTextStyles.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Saved on your profile and attached to new tailoring orders for doorstep delivery.',
            style:
                AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: ctrl,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'House, street, area, landmark, city, PIN',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () async {
              await AppState.instance.setProfileDeliveryAddress(ctrl.text);
              if (ctx.mounted) Navigator.pop(ctx);
              if (parentContext.mounted) {
                ScaffoldMessenger.of(parentContext).showSnackBar(
                  const SnackBar(content: Text('Delivery address saved')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  ).then((_) {
    ctrl.dispose();
  });
}

void _showHomeAccountSheet(BuildContext context) {
  final user = FirebaseAuth.instance.currentUser;
  final subtitle = user?.email ?? user?.phoneNumber;

  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetCtx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: ListenableBuilder(
              listenable: AppState.instance,
              builder: (context, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppState.instance.displayName,
                      style: AppTextStyles.titleLarge,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null && subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.account_circle_outlined),
            title: const Text('My Account'),
            subtitle: const Text('Profile, orders, addresses and membership'),
            onTap: () {
              Navigator.pop(sheetCtx);
              context.push('/account');
            },
          ),
          ListTile(
            leading: const Icon(Icons.home_work_outlined),
            title: const Text('Delivery address'),
            subtitle: Text(
              AppState.instance.profile?.deliveryAddress?.isNotEmpty == true
                  ? 'Tap to update'
                  : 'Add for doorstep delivery',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textHint),
            ),
            onTap: () {
              Navigator.pop(sheetCtx);
              _showDeliveryAddressSheet(context);
            },
          ),
          ListTile(
            leading: Icon(Icons.logout_rounded, color: AppColors.error),
            title: Text(
              'Log out',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: () async {
              Navigator.pop(sheetCtx);
              await AppState.instance.signOut();
              if (context.mounted) context.go('/login');
            },
          ),
          const SizedBox(height: 8),
        ],
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
            _buildMeasurementBanner(context),
            const SizedBox(height: 16),
            const _HomeSmartOutfitCard(),
            const SizedBox(height: 28),
            _buildQuickActions(context),
            const SizedBox(height: 28),
            SectionHeader(
              title: 'Tailor Your Style',
              actionLabel: 'See all',
              onAction: () => context.push('/tailor-style'),
            ),
            const SizedBox(height: 12),
            _buildTailorYourStyleRow(context),
            const SizedBox(height: 24),
            SectionHeader(
              title: 'Bulk Orders',
              actionLabel: 'Events',
              onAction: () => context.push('/bulk-orders'),
            ),
            const SizedBox(height: 12),
            CategoryCard(
              title: 'Weddings & events',
              subtitle: 'Consultation → quote → dedicated tailor',
              icon: Icons.favorite_rounded,
              color: const Color(0xFFE91E63),
              onTap: () => context.push('/bulk-orders'),
              isWide: true,
            ),
            const SizedBox(height: 24),
            SectionHeader(
              title: 'Quick Fix & Essentials',
              actionLabel: 'All',
              onAction: () => context.push('/quick-fix'),
            ),
            const SizedBox(height: 12),
            _buildQuickFixChips(context),
            const SizedBox(height: 24),
            SectionHeader(
              title: 'Shop & Explore',
              actionLabel: 'Open',
              onAction: () => context.push('/shop-explore'),
            ),
            const SizedBox(height: 12),
            _buildShopExploreRow(context),
            const SizedBox(height: 24),
            SectionHeader(
              title: 'Offers & Membership',
              actionLabel: 'View',
              onAction: () => context.push('/offers'),
            ),
            const SizedBox(height: 12),
            CategoryCard(
              title: 'Prime · Gold · Coupons',
              subtitle: 'Subscription benefits & wedding packages',
              icon: Icons.card_membership_rounded,
              color: const Color(0xFFFFA000),
              onTap: () => context.push('/offers'),
              isWide: true,
            ),
            const SizedBox(height: 28),
            SectionHeader(
              title: 'Browse catalog',
              actionLabel: 'See all',
              onAction: () => context.push('/catalog'),
            ),
            const SizedBox(height: 16),
            _buildCategoryGrid(context),
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

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _homeGreeting(),
                style: AppTextStyles.bodyMedium,
              ),
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

  Widget _buildMeasurementBanner(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/measurements'),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Take New\nMeasurements',
                    style: AppTextStyles.headlineLarge.copyWith(
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Use your camera to capture\nbody measurements instantly',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Measurements',
                      style: AppTextStyles.labelLarge,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                color: Colors.white,
                size: 44,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        QuickActionButton(
          label: 'My\nMeasures',
          icon: Icons.straighten_rounded,
          color: AppColors.primary,
          onTap: () => context.push('/measurements'),
        ),
        QuickActionButton(
          label: 'Design\nDress',
          icon: Icons.design_services_rounded,
          color: const Color(0xFFFF6B6B),
          onTap: () => context.push('/designer'),
        ),
        QuickActionButton(
          label: 'Dress\nCatalog',
          icon: Icons.checkroom_rounded,
          color: const Color(0xFFF5A623),
          onTap: () => context.push('/catalog'),
        ),
        QuickActionButton(
          label: 'My\nOrders',
          icon: Icons.receipt_long_rounded,
          color: const Color(0xFF4CAF50),
          onTap: () => context.push('/orders'),
        ),
      ],
    );
  }

  Widget _buildTailorYourStyleRow(BuildContext context) {
    final items = [
      ('Daily', Icons.wb_sunny_outlined, OccasionCategory.dailyWear),
      ('Office', Icons.work_outline_rounded, OccasionCategory.officeWear),
      ('Party', Icons.celebration_outlined, OccasionCategory.partyWear),
      ('Wedding', Icons.favorite_border_rounded, OccasionCategory.bridalHeavyOccasion),
      ('Festive', Icons.auto_awesome_outlined, OccasionCategory.festiveWear),
      ('Kids', Icons.child_care_outlined, OccasionCategory.dailyWear),
    ];
    // Tall enough for icon + 2-line label + padding; 96 caused ~2px bottom overflow on some devices.
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (ctx, i) {
          final o = items[i];
          final isKids = i == items.length - 1;
          return GestureDetector(
            onTap: () {
              final q =
                  'occasion=${Uri.encodeComponent(o.$3.name)}&kids=${isKids ? '1' : '0'}';
              context.push('/designer?$q');
            },
            child: Container(
              width: 88,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(o.$2, color: AppColors.primary, size: 24),
                  const SizedBox(height: 6),
                  Text(
                    o.$1,
                    style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.15,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickFixChips(BuildContext context) {
    return Column(
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _FixChip(
              label: 'Alterations',
              onTap: () => context.push('/quick-fix'),
            ),
            _FixChip(
              label: 'Pico / Fall',
              onTap: () => context.push('/quick-fix'),
            ),
            _FixChip(
              label: 'Express repairs',
              onTap: () => context.push('/quick-fix'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        CategoryCard(
          title: 'Doorstep Quick Fix',
          subtitle: 'Slot, estimate & tracking',
          icon: Icons.home_repair_service_rounded,
          color: const Color(0xFF00BCD4),
          onTap: () => context.push('/quick-fix'),
          isWide: true,
        ),
      ],
    );
  }

  Widget _buildShopExploreRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: CategoryCard(
            title: 'Rent · Fabrics',
            subtitle: 'Partners & collections',
            icon: Icons.storefront_rounded,
            color: const Color(0xFF7E57C2),
            onTap: () => context.push('/shop-explore'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: CategoryCard(
            title: 'Accessories',
            subtitle: 'Kids · Festivals',
            icon: Icons.palette_outlined,
            color: const Color(0xFF26A69A),
            onTap: () => context.push('/shop-explore'),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryGrid(BuildContext context) {
    return Column(
      children: [
        CategoryCard(
          title: 'Ladies Wear',
          subtitle: 'Kurti, Blouse, Saree & more',
          icon: Icons.woman_rounded,
          color: const Color(0xFFFF6B9D),
          onTap: () => context.push('/catalog'),
          isWide: true,
        ),
        const SizedBox(height: 14),
        CategoryCard(
          title: 'Quick Design from Measurements',
          subtitle: 'Auto-fill dress measurements from your body scan',
          icon: Icons.auto_fix_high_rounded,
          color: AppColors.primary,
          onTap: () => context.push('/designer'),
          isWide: true,
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
            data['tailorName'] as String? ?? '',
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
                      color: order.$4.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.checkroom_rounded, color: order.$4, size: 24),
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
                        if (order.$2.isNotEmpty)
                          Text(
                            order.$2,
                            style: AppTextStyles.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: order.$4.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        order.$3,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: order.$4,
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
      onTap: () => context.push('/designer'),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            const Icon(Icons.receipt_long_outlined,
                size: 36, color: AppColors.textHint),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('No orders yet', style: AppTextStyles.titleMedium),
                  Text('Tap to design your first dress',
                      style: AppTextStyles.bodySmall),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 16, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }
}

class _FixChip extends StatelessWidget {
  const _FixChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(
        label,
        style: AppTextStyles.labelLarge.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: AppColors.surface,
      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.35)),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      onPressed: onTap,
    );
  }
}

/// On-demand outfit idea (Claude Haiku) — tap only; no background API calls.
class _HomeSmartOutfitCard extends StatefulWidget {
  const _HomeSmartOutfitCard();

  @override
  State<_HomeSmartOutfitCard> createState() => _HomeSmartOutfitCardState();
}

class _HomeSmartOutfitCardState extends State<_HomeSmartOutfitCard> {
  bool _loading = false;
  String? _text;
  String? _error;

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
      _text = null;
    });
    final r = await ClaudeSmartAssistantService.homeOutfitIdea(
      seasonHint: _homeSeasonHint(),
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.success) {
        _text = r.text;
      } else {
        _error = r.text;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
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
              Icon(Icons.auto_awesome_rounded,
                  color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Smart style idea',
                  style: AppTextStyles.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'One AI suggestion for ${_homeSeasonHint()} — uses your shop Claude key.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: _loading ? null : _fetch,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_fix_high_rounded, size: 20),
            label: Text(_loading ? 'Getting idea…' : 'Get an outfit idea'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
            ),
          ],
          if (_text != null) ...[
            const SizedBox(height: 12),
            Text(
              _text!,
              style: AppTextStyles.bodyMedium.copyWith(height: 1.4),
            ),
          ],
        ],
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
