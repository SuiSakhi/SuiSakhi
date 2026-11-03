import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/app_state.dart';
import '../../widgets/home/customer_home_groups_section.dart';
import '../../widgets/home/home_reference_artwork.dart';

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
            if (i == 4) {
              context.push('/account');
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
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Profile',
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
            const SizedBox(height: 10),
            _buildHeader(context),
            const SizedBox(height: 18),
            _buildQuickActions(context),
            const SizedBox(height: 20),
            const CustomerHomeGroupsSection(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFE5EF), Color(0xFFFFF8FA), Color(0xFFFFFFFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE74783).withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'assets/images/suisakhi_logo.png',
                  width: 62,
                  height: 62,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SuiSakhi',
                      style: TextStyle(
                        color: Color(0xFF711344),
                        fontSize: 22,
                        height: 1,
                        fontFamily: 'serif',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Your Style. Our Care.',
                      style: TextStyle(
                        color: Color(0xFF23375D),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              _HeaderIconButton(
                icon: Icons.notifications_none_rounded,
                hasNotification: true,
                onTap: () => _showHomeNotificationsSheet(context),
              ),
              const SizedBox(width: 8),
              Material(
                color: const Color(0xFFFF8BBB),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => context.push('/account'),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child: ListenableBuilder(
                        listenable: AppState.instance,
                        builder: (context, _) {
                          final photoUrl = AppState.instance.profile?.photoUrl;
                          if (photoUrl != null && photoUrl.isNotEmpty) {
                            return ClipOval(
                              child: Image.network(
                                photoUrl,
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Text(
                                  AppState.instance.initials,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            );
                          }
                          return Text(
                            AppState.instance.initials,
                            style: const TextStyle(
                              color: Colors.white,
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
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 142,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  right: -18,
                  top: 0,
                  bottom: 0,
                  width: 176,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: HomeReferenceArtwork(
                      sourceRect: const Rect.fromLTWH(374, 108, 474, 308),
                      placeholderColor: const Color(0xFFFFE5EF),
                    ),
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFFFFF8FA),
                        Color(0xE6FFF8FA),
                        Color(0x00FFF8FA),
                      ],
                      stops: [0, 0.53, 1],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: 226,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Look Good',
                          style: AppTextStyles.displayLarge.copyWith(
                            color: const Color(0xFF15284D),
                            height: 1.02,
                            fontFamily: 'serif',
                            fontSize: 30,
                          ),
                        ),
                        Text(
                          'Feel Special',
                          style: AppTextStyles.displayLarge.copyWith(
                            color: const Color(0xFFE60065),
                            height: 1.02,
                            fontFamily: 'serif',
                            fontSize: 30,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          'Design, stitch, shop, care, rent and more — all in one place.',
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: const Color(0xFF23375D),
                            height: 1.2,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: () => context.push('/service-guide'),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.search_rounded,
                      color: Color(0xFFE60065),
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'What would you like to do today?',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: const Color(0xFF667695),
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.auto_awesome_rounded,
                      color: Color(0xFFE60065),
                      size: 19,
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

  Widget _buildQuickActions(BuildContext context) {
    const actions = [
      (
        label: 'Track Orders',
        icon: Icons.local_shipping_outlined,
        route: '/customer-orders',
      ),
      (
        label: 'Saved Designs',
        icon: Icons.favorite_border_rounded,
        route: '/wishlist',
      ),
      (
        label: 'My Measurements',
        icon: Icons.straighten_rounded,
        route: '/measurements',
      ),
      (label: 'Offers & Updates', icon: Icons.sell_outlined, route: '/offers'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Actions', style: AppTextStyles.headlineMedium),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final action in actions)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => context.push(action.route),
                      child: SizedBox(
                        height: 104,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              action.icon,
                              color: const Color(0xFFE60065),
                              size: 28,
                            ),
                            const SizedBox(height: 7),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3,
                              ),
                              child: Text(
                                action.label,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF23375D),
                                  fontSize: 10,
                                  height: 1.15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
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

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
    this.hasNotification = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool hasNotification;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFFF4EAFB),
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 44,
        height: 44,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(child: Icon(icon, color: const Color(0xFF182B51))),
            if (hasNotification)
              Positioned(
                top: 7,
                right: 7,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE60065),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
