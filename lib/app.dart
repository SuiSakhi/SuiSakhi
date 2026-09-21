import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'core/router_keys.dart';
import 'core/theme/app_theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/profile/profile_selection_screen.dart';
import 'screens/profile/customer_account_center_screen.dart';
import 'screens/profile/customer_addresses_screen.dart';
import 'screens/profile/customer_profile_screen.dart';
import 'screens/profile/customer_edit_profile_screen.dart';
import 'screens/profile/family_members_screen.dart';
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
import 'screens/owner/owner_partner_applications_screen.dart';
import 'screens/owner/owner_partner_application_review_screen.dart';
import 'screens/owner/rates_management_screen.dart';
import 'screens/owner/owner_payout_settings_screen.dart';
import 'screens/checkout/order_checkout_screen.dart';
import 'screens/measurements/measurement_context_screen.dart';
import 'screens/tailor/tailor_dashboard_screen.dart';
import 'screens/profile/tailor_account_center_screen.dart' as tailor_account;
import 'screens/partner/partner_opportunities_screen.dart';
import 'screens/partner/tailor_application_screen.dart';
import 'screens/partner/boutique_application_screen.dart';
import 'screens/partner/brand_application_screen.dart';
import 'screens/partner/designer_application_screen.dart';
import 'screens/partner/fabric_supplier_application_screen.dart';
import 'screens/partner/garment_care_application_screen.dart';
import 'screens/partner/rental_application_screen.dart';
import 'screens/partner/printing_application_screen.dart';
import 'screens/partner/delivery_partner_application_screen.dart';
import 'screens/partner/measurement_partner_application_screen.dart';
import 'screens/partner/quickcare_application_screen.dart';
import 'screens/delivery/delivery_dashboard_screen.dart';
import 'screens/partner/partner_profile_landing_screen.dart';
import 'screens/partner/partner_workspace_screen.dart';
import 'screens/partner/partner_profile_view_screen.dart';
import 'screens/partner/partner_business_details_screen.dart';
import 'screens/partner/partner_addresses_view_screen.dart';
import 'screens/owner/owner_catalogue_upload_screen.dart';
import 'screens/partner/designer_catalogue_upload_screen.dart';
import 'screens/owner/owner_catalogue_screen.dart';
import 'screens/owner/owner_catalogue_review_screen.dart';
import 'screens/owner/catalogue_correction_screen.dart';
import 'screens/partner/designer_catalogue_screen.dart';
import 'screens/partner/designer_catalogue_details_screen.dart';
import 'screens/partner/designer_catalogue_correction_screen.dart';

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
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(title: const Text('Page unavailable')),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.route_outlined, size: 56),
            const SizedBox(height: 16),
            const Text(
              'This page is not available.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(state.uri.toString(), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go('/login'),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Go Back'),
            ),
          ],
        ),
      ),
    ),
  ),
  routes: [
    GoRoute(path: '/', builder: (ctx, state) => const SplashScreen()),
    GoRoute(path: '/login', builder: (ctx, state) => const LoginScreen()),
    GoRoute(
      path: '/profile-selection',
      builder: (ctx, state) => ProfileSelectionScreen(
        profiles: const [
          {
            'role': 'customer',
            'displayName': 'Sudhir',
            'isDefaultProfile': true,
          },
          {
            'role': 'owner',
            'displayName': 'Sudhir',
            'shopName': 'Sudhir Boutique',
          },
          {
            'role': 'tailor',
            'displayName': 'Ramesh',
            'shopName': 'Perfect Tailors',
          },
          {'role': 'delivery_partner', 'displayName': 'Sunil'},
          {
            'role': 'supplier',
            'displayName': 'Anand',
            'shopName': 'Mahalaxmi Fabrics',
          },
        ],
      ),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (ctx, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/account',
      builder: (ctx, state) => const CustomerAccountCenterScreen(),
    ),
    GoRoute(
      path: '/partner/landing',
      builder: (context, state) => PartnerProfileLandingScreen(
        accountId: state.uri.queryParameters['accountId'],
        partnerProfileId: state.uri.queryParameters['profileId'],
        partnerCategoryCode: state.uri.queryParameters['category'],
      ),
    ),
    GoRoute(
      path: '/partner/workspace',
      builder: (context, state) => PartnerWorkspaceScreen(
        accountId: state.uri.queryParameters['accountId'] ?? '',
        partnerProfileId: state.uri.queryParameters['profileId'] ?? '',
        partnerCategoryCode: state.uri.queryParameters['category'],
      ),
    ),
    GoRoute(
      path: '/partner/profile',
      builder: (context, state) => PartnerProfileViewScreen(
        accountId: state.uri.queryParameters['accountId'] ?? '',
        profileId: state.uri.queryParameters['profileId'] ?? '',
      ),
    ),
    GoRoute(
      path: '/partner/business-details',
      builder: (context, state) => PartnerBusinessDetailsScreen(
        accountId: state.uri.queryParameters['accountId'] ?? '',
        profileId: state.uri.queryParameters['profileId'] ?? '',
      ),
    ),
    GoRoute(
      path: '/partner/addresses',
      builder: (context, state) => PartnerAddressesViewScreen(
        accountId: state.uri.queryParameters['accountId'] ?? '',
        profileId: state.uri.queryParameters['profileId'] ?? '',
      ),
    ),
    GoRoute(
      path: '/partner/opportunities',
      builder: (ctx, state) => const PartnerOpportunitiesScreen(),
    ),
    GoRoute(
      path: '/partner/apply/tailor',
      builder: (ctx, state) => const TailorApplicationScreen(),
    ),
    GoRoute(
      path: '/partner/apply/measurement',
      builder: (ctx, state) => const MeasurementPartnerApplicationScreen(),
    ),
    GoRoute(
      path: '/partner/apply/designer',
      builder: (ctx, state) => const DesignerApplicationScreen(),
    ),
    GoRoute(
      path: '/partner/apply/boutique',
      builder: (ctx, state) => const BoutiqueApplicationScreen(),
    ),
    GoRoute(
      path: '/partner/apply/brand',
      builder: (ctx, state) => const BrandApplicationScreen(),
    ),
    GoRoute(
      path: '/partner/apply/garment-care',
      builder: (ctx, state) => const GarmentCareApplicationScreen(),
    ),
    GoRoute(
      path: '/partner/apply/quickcare',
      builder: (ctx, state) => const QuickCareApplicationScreen(),
    ),
    GoRoute(
      path: '/partner/apply/fabric-supplier',
      builder: (context, state) => const FabricSupplierApplicationScreen(),
    ),
    GoRoute(
      path: '/partner/apply/rental',
      builder: (context, state) => const RentalApplicationScreen(),
    ),
    GoRoute(
      path: '/partner/apply/printing',
      builder: (context, state) => const PrintingApplicationScreen(),
    ),
    GoRoute(
      path: '/partner/apply/delivery',
      builder: (context, state) => const DeliveryApplicationScreen(),
    ),

    GoRoute(
      path: '/customer-profile',
      builder: (ctx, state) => const CustomerProfileScreen(),
    ),
    GoRoute(
      path: '/customer-edit-profile',
      builder: (ctx, state) => const CustomerEditProfileScreen(),
    ),
    GoRoute(
      path: '/family-members',
      builder: (ctx, state) => const FamilyMembersScreen(),
    ),
    GoRoute(
      path: '/customer-addresses',
      builder: (ctx, state) => const CustomerAddressesScreen(),
    ),
    GoRoute(
      path: '/profile-setup',
      builder: (ctx, state) => const ProfileSetupScreen(),
    ),
    GoRoute(path: '/home', builder: (ctx, state) => const HomeScreen()),
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
      path: '/owner/partner-applications',
      builder: (ctx, state) => const OwnerPartnerApplicationsScreen(),
    ),
    GoRoute(
      path: '/owner/partner-applications/:applicationId',
      builder: (ctx, state) => OwnerPartnerApplicationReviewScreen(
        applicationId: state.pathParameters['applicationId']!,
      ),
    ),
    GoRoute(
      path: '/checkout/:orderId',
      builder: (ctx, state) =>
          OrderCheckoutScreen(orderId: state.pathParameters['orderId']!),
    ),
    // ── Tailor routes ─────────────────────────────────────────────────────
    GoRoute(
      path: '/tailor',
      builder: (context, state) => TailorDashboardScreen(
        accountId: state.uri.queryParameters['accountId'],
        tailorProfileId: state.uri.queryParameters['profileId'],
      ),
    ),
    GoRoute(
      path: '/tailor-account',
      builder: (ctx, state) => const tailor_account.TailorAccountCenterScreen(),
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
      path: '/measurement-context',
      builder: (ctx, state) => const MeasurementContextScreen(),
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
      path: '/owner/catalogue/upload',
      builder: (context, state) => const OwnerCatalogueUploadScreen(),
    ),
    GoRoute(
      path: '/partner/designer/catalogue',
      builder: (context, state) => DesignerCatalogueScreen(
        accountId: state.uri.queryParameters['accountId'] ?? '',
        designerProfileId: state.uri.queryParameters['profileId'] ?? '',
      ),
    ),
    GoRoute(
      path: '/partner/designer/catalogue/upload',
      builder: (context, state) => DesignerCatalogueUploadScreen(
        accountId: state.uri.queryParameters['accountId'] ?? '',
        designerProfileId: state.uri.queryParameters['profileId'] ?? '',
      ),
    ),
    GoRoute(
      path: '/partner/designer/catalogue/:designId/correct',
      builder: (context, state) => DesignerCatalogueCorrectionScreen(
        accountId: state.uri.queryParameters['accountId'] ?? '',
        designerProfileId: state.uri.queryParameters['profileId'] ?? '',
        designId: state.pathParameters['designId'] ?? '',
      ),
    ),
    GoRoute(
      path: '/partner/designer/catalogue/:designId',
      builder: (context, state) => DesignerCatalogueDetailsScreen(
        accountId: state.uri.queryParameters['accountId'] ?? '',
        designerProfileId: state.uri.queryParameters['profileId'] ?? '',
        designId: state.pathParameters['designId'] ?? '',
      ),
    ),
    GoRoute(
      path: '/owner/catalogue',
      builder: (context, state) => const OwnerCatalogueScreen(),
    ),
    GoRoute(
      path: '/owner/catalogue/:designId/review',
      builder: (context, state) => OwnerCatalogueReviewScreen(
        designId: state.pathParameters['designId'] ?? '',
      ),
    ),
    GoRoute(
      path: '/owner/catalogue/:designId/correct',
      builder: (context, state) => CatalogueCorrectionScreen(
        designId: state.pathParameters['designId'] ?? '',
      ),
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

        final clientName = state.uri.queryParameters['clientName'];
        final personId = state.uri.queryParameters['personId'];
        final relationship = state.uri.queryParameters['relationship'];
        final draftId = state.uri.queryParameters['draftId'];
        final orderDraftId = state.uri.queryParameters['orderDraftId'];

        return DressDesignerScreen(
          initialOccasionId: occasion,
          isKidsFlow: kids,
          initialClientName: clientName,
          initialPersonId: personId,
          initialRelationship: relationship,
          initialMeasurementDraftId: draftId,
          initialOrderDraftId: orderDraftId,
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
    GoRoute(path: '/orders', builder: (ctx, state) => const OrdersScreen()),
  ],
);
