import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'core/router_keys.dart';
import 'core/theme/app_theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/onboarding/profile_setup_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/measurements/measurement_dashboard_screen.dart';
import 'screens/measurements/camera_measurement_screen.dart';
import 'screens/measurements/measurement_result_screen.dart';
import 'screens/catalog/dress_catalog_screen.dart';
import 'screens/catalog/dress_detail_screen.dart';
import 'screens/designer/dress_designer_screen.dart';
import 'screens/orders/orders_screen.dart';
import 'screens/prd/tailor_style_hub_screen.dart';
import 'screens/prd/quick_fix_screen.dart';
import 'screens/prd/bulk_orders_screen.dart';
import 'screens/prd/shop_explore_screen.dart';
import 'screens/prd/offers_membership_screen.dart';
import 'screens/owner/owner_dashboard_screen.dart';
import 'screens/owner/owner_design_templates_screen.dart';
import 'screens/owner/rates_management_screen.dart';
import 'screens/owner/owner_payout_settings_screen.dart';
import 'screens/checkout/order_checkout_screen.dart';
import 'screens/tailor/tailor_dashboard_screen.dart';
import 'screens/delivery/delivery_dashboard_screen.dart';

class StitchSmartApp extends StatelessWidget {
  const StitchSmartApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'SuiSakhi',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: _router,
    );
  }
}

final _router = GoRouter(
  navigatorKey: stitchSmartRootNavigatorKey,
  initialLocation: '/',
  // Firebase Phone reCAPTCHA returns a custom iOS URL scheme. Without this,
  // GoRouter has no matching route, [errorBuilder] runs, and the original
  // [LoginScreen] is disposed while the phone sheet is still open — OTP UI breaks.
  redirect: (BuildContext context, GoRouterState state) {
    final scheme = state.uri.scheme.toLowerCase();
    if (scheme.isEmpty) return null;
    if (scheme == 'http' || scheme == 'https' || scheme == 'file') {
      return null;
    }
    return '/login';
  },
  errorBuilder: (context, state) => const LoginScreen(),
  routes: [
    GoRoute(
      path: '/',
      builder: (ctx, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (ctx, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (ctx, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/profile-setup',
      builder: (ctx, state) => const ProfileSetupScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (ctx, state) => const HomeScreen(),
    ),
    // ── Owner routes ──────────────────────────────────────────────────────
    GoRoute(
      path: '/owner',
      builder: (ctx, state) => const OwnerDashboardScreen(),
    ),
    GoRoute(
      path: '/owner/rates',
      builder: (ctx, state) => const RatesManagementScreen(),
    ),
    GoRoute(
      path: '/owner/designs',
      builder: (ctx, state) => const OwnerDesignTemplatesScreen(),
    ),
    GoRoute(
      path: '/owner/payouts',
      builder: (ctx, state) => const OwnerPayoutSettingsScreen(),
    ),
    GoRoute(
      path: '/checkout/:orderId',
      builder: (ctx, state) => OrderCheckoutScreen(
        orderId: state.pathParameters['orderId']!,
      ),
    ),
    // ── Tailor routes ─────────────────────────────────────────────────────
    GoRoute(
      path: '/tailor',
      builder: (ctx, state) => const TailorDashboardScreen(),
    ),
    // ── Delivery routes ───────────────────────────────────────────────────
    GoRoute(
      path: '/delivery',
      builder: (ctx, state) => const DeliveryDashboardScreen(),
    ),
    // ── Customer routes ───────────────────────────────────────────────────
    GoRoute(
      path: '/measurements',
      builder: (ctx, state) => const MeasurementDashboardScreen(),
    ),
    GoRoute(
      path: '/camera',
      builder: (ctx, state) => const CameraMeasurementScreen(),
    ),
    GoRoute(
      path: '/measurement-result',
      builder: (ctx, state) => const MeasurementResultScreen(),
    ),
    GoRoute(
      path: '/catalog',
      builder: (ctx, state) => const DressCatalogScreen(),
    ),
    GoRoute(
      path: '/catalog/:id',
      builder: (ctx, state) =>
          DressDetailScreen(dressId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/designer',
      builder: (ctx, state) {
        final occasion = state.uri.queryParameters['occasion'];
        final kids = state.uri.queryParameters['kids'] == '1';
        return DressDesignerScreen(
          initialOccasionId: occasion,
          isKidsFlow: kids,
        );
      },
    ),
    GoRoute(
      path: '/tailor-style',
      builder: (ctx, state) => const TailorStyleHubScreen(),
    ),
    GoRoute(
      path: '/quick-fix',
      builder: (ctx, state) => const QuickFixScreen(),
    ),
    GoRoute(
      path: '/bulk-orders',
      builder: (ctx, state) => const BulkOrdersScreen(),
    ),
    GoRoute(
      path: '/shop-explore',
      builder: (ctx, state) => const ShopExploreScreen(),
    ),
    GoRoute(
      path: '/offers',
      builder: (ctx, state) => const OffersMembershipScreen(),
    ),
    GoRoute(
      path: '/orders',
      builder: (ctx, state) => const OrdersScreen(),
    ),
  ],
);
