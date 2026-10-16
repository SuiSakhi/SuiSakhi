import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_state.dart';
import '../../core/constants/app_colors.dart';
import '../../models/partner_workspace_module.dart';
import '../../models/partner_workspace_profile.dart';
import '../../services/partner_workspace_registry.dart';
import '../../services/partner_workspace_service.dart';
import '../../widgets/partner_workspace/partner_status_banner.dart';
import '../../widgets/partner_workspace/partner_workspace_header.dart';
import '../../widgets/partner_workspace/partner_workspace_menu_tile.dart';
import '../../widgets/partner_workspace/partner_workspace_section.dart';
import '../profile/profile_selection_screen.dart';
import 'measurement_partner_assignments_screen.dart';
import 'store_product_management_screen.dart';

class PartnerWorkspaceScreen extends StatefulWidget {
  const PartnerWorkspaceScreen({
    super.key,
    required this.accountId,
    required this.partnerProfileId,
    this.partnerCategoryCode,
    this.showAccountCenter = false,
  });

  final String accountId;
  final String partnerProfileId;
  final String? partnerCategoryCode;
  final bool showAccountCenter;

  @override
  State<PartnerWorkspaceScreen> createState() => _PartnerWorkspaceScreenState();
}

class _PartnerWorkspaceScreenState extends State<PartnerWorkspaceScreen> {
  late Future<PartnerWorkspaceProfile> _profileFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _profileFuture = PartnerWorkspaceService.requirePartnerProfile(
      accountId: widget.accountId,
      profileId: widget.partnerProfileId,
    );
  }

  String get _query {
    return '?accountId=${Uri.encodeQueryComponent(widget.accountId)}'
        '&profileId=${Uri.encodeQueryComponent(widget.partnerProfileId)}';
  }

  Future<void> _changeProfile() async {
    final profiles = await AppState.instance.fetchActiveProfilesForAccount(
      widget.accountId,
    );

    if (!mounted) {
      return;
    }

    final selected = await Navigator.of(context, rootNavigator: true)
        .push<Map<String, dynamic>>(
          MaterialPageRoute<Map<String, dynamic>>(
            builder: (_) => ProfileSelectionScreen(profiles: profiles),
          ),
        );

    if (selected == null || !mounted) {
      return;
    }

    final profileId = (selected['profileId'] ?? selected['docId'] ?? '')
        .toString()
        .trim();
    if (profileId.isEmpty) {
      return;
    }

    await AppState.instance.setActiveProfileForAccount(
      accountId: widget.accountId,
      profileId: profileId,
    );

    if (!mounted) {
      return;
    }

    final role = (selected['role'] ?? 'customer').toString().trim();
    final partnerType = (selected['partnerType'] ?? '').toString().trim();

    switch (role) {
      case 'customer':
        context.go('/home');
        return;
      case 'owner':
        context.go('/owner');
        return;
      case 'tailor':
        context.go('/tailor');
        return;
      case 'delivery':
      case 'delivery_partner':
        context.go('/delivery');
        return;
      case 'partner':
        if (partnerType == 'tailor') {
          context.go(
            '/tailor'
            '?accountId=${Uri.encodeQueryComponent(widget.accountId)}'
            '&profileId=${Uri.encodeQueryComponent(profileId)}',
          );
          return;
        }

        if (partnerType == 'designer') {
          context.go(
            '/partner/designer/catalogue'
            '?accountId=${Uri.encodeQueryComponent(widget.accountId)}'
            '&profileId=${Uri.encodeQueryComponent(profileId)}',
          );
          return;
        }

        if (partnerType == 'deliveryPartner') {
          context.go('/delivery');
          return;
        }

        context.go(
          '/partner/workspace'
          '?accountId=${Uri.encodeQueryComponent(widget.accountId)}'
          '&profileId=${Uri.encodeQueryComponent(profileId)}'
          '&category=${Uri.encodeQueryComponent(partnerType)}',
        );
        return;
      default:
        context.go('/home');
        return;
    }
  }

  Future<void> _logout() async {
    await AppState.instance.signOut();
    if (mounted) {
      context.go('/');
    }
  }

  void _showComingSoon(PartnerWorkspaceModule module) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${module.label} is planned for the next Partner Workspace phase.',
        ),
      ),
    );
  }

  Future<void> _openModule(
    PartnerWorkspaceModule module,
    PartnerWorkspaceProfile profile,
  ) async {
    switch (module.route) {
      case 'profile':
        await context.push('/partner/profile$_query');
        return;
      case 'business-details':
        await context.push('/partner/business-details$_query');
        return;
      case 'partner-addresses':
        await context.push('/partner/addresses$_query');
        return;
      case 'designer-catalogue':
        await context.push('/partner/designer/catalogue$_query');
        return;
      case 'measurement-assignments':
        await context.push('/partner/measurement/assignments$_query');
        return;
      case 'store-products':
        await context.push(
          '/partner/store$_query'
          '&partnerType=${Uri.encodeQueryComponent(profile.partnerType)}'
          '&sellerName=${Uri.encodeQueryComponent(profile.businessDisplayName)}',
        );
        return;
      case 'change-profile':
        await _changeProfile();
        return;
      case 'logout':
        await _logout();
        return;
      default:
        _showComingSoon(module);
        return;
    }
  }

  Future<void> _refresh() async {
    setState(_reload);
    await _profileFuture;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PartnerWorkspaceProfile>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Partner Workspace')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${snapshot.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _changeProfile,
                      icon: const Icon(Icons.switch_account_outlined),
                      label: const Text('Change Profile'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final profile = snapshot.data!;
        final definition = PartnerWorkspaceRegistry.definitionFor(
          profile.partnerType,
        );
        final isMeasurementPartner =
            profile.partnerType == 'measurementPartner';
        if (isMeasurementPartner && !widget.showAccountCenter) {
          return MeasurementPartnerAssignmentsScreen(
            accountId: widget.accountId,
            profileId: widget.partnerProfileId,
            partnerName: profile.businessDisplayName,
          );
        }
        if (!widget.showAccountCenter &&
            (profile.partnerType == 'brand' ||
                profile.partnerType == 'boutique')) {
          return StoreProductManagementScreen(
            accountId: widget.accountId,
            profileId: widget.partnerProfileId,
            partnerType: profile.partnerType,
            sellerName: profile.businessDisplayName,
          );
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            centerTitle: true,
            title: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.showAccountCenter
                      ? 'Partner Account'
                      : 'Partner Workspace',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                Text(
                  profile.businessDisplayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          body: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                PartnerWorkspaceHeader(profile: profile),
                const SizedBox(height: 12),
                PartnerStatusBanner(profile: profile),
                const SizedBox(height: 20),
                for (final section in PartnerWorkspaceRegistry.sections)
                  PartnerWorkspaceSection(
                    title: section,
                    children: [
                      for (final module in definition.modulesFor(section))
                        PartnerWorkspaceMenuTile(
                          module: module,
                          onTap: module.isEnabled
                              ? () => _openModule(module, profile)
                              : () => _showComingSoon(module),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
