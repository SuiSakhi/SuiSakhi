import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_state.dart';
import '../profile/profile_selection_screen.dart';

/// Service selector for delivery partners. Keep each service's availability
/// and work queue independent; `/delivery` remains the existing Tailoring flow.
class DeliveryServicesScreen extends StatefulWidget {
  const DeliveryServicesScreen({
    super.key,
    this.accountId = '',
    this.profileId = '',
  });

  final String accountId;
  final String profileId;

  @override
  State<DeliveryServicesScreen> createState() => _DeliveryServicesScreenState();
}

class _DeliveryServicesScreenState extends State<DeliveryServicesScreen> {
  String? _accountId;
  String? _profileId;
  String? _error;
  bool _loading = true;
  bool _eligible = false;
  bool _garmentCareAvailable = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      var accountId = widget.accountId.trim();
      if (accountId.isEmpty) {
        final phone = FirebaseAuth.instance.currentUser?.phoneNumber?.trim();
        if (phone == null || phone.isEmpty) {
          throw StateError('Sign in with your Delivery Partner account.');
        }
        accountId =
            await AppState.instance.fetchAccountIdForMobile(phone) ?? '';
      }
      if (accountId.isEmpty) {
        throw StateError('Your Delivery Partner profile could not be found.');
      }

      final profiles = await AppState.instance.fetchActiveProfilesForAccount(
        accountId,
      );
      final matches = profiles
          .where((profile) {
            final requestedProfile = widget.profileId.trim();
            return profile['partnerType'] == 'deliveryPartner' &&
                profile['role'] == 'partner' &&
                (requestedProfile.isEmpty ||
                    profile['profileId']?.toString() == requestedProfile);
          })
          .toList(growable: false);
      if (matches.isEmpty) {
        throw StateError(
          'An active Delivery Partner profile is required for delivery services.',
        );
      }
      final profile = matches.first;
      final profileId =
          profile['profileId']?.toString().trim().isNotEmpty == true
          ? profile['profileId'].toString().trim()
          : profile['docId']?.toString().trim() ?? '';
      if (profileId.isEmpty) {
        throw StateError('Your Delivery Partner profile could not be found.');
      }
      if (!mounted) return;
      setState(() {
        _accountId = accountId;
        _profileId = profileId;
        _eligible =
            profile['operationalStatus'] == 'active' &&
            profile['activationStatus'] == 'active' &&
            profile['approvalStatus'] == 'approved' &&
            profile['kycStatus'] == 'verified';
        _garmentCareAvailable = profile['garmentCareDeliveryAvailable'] == true;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Bad state: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _setGarmentCareAvailability(bool available) async {
    final accountId = _accountId;
    final profileId = _profileId;
    if (_saving || !_eligible || accountId == null || profileId == null) {
      return;
    }
    setState(() => _saving = true);
    try {
      await FirebaseFunctions.instance
          .httpsCallable('updateGarmentCareDeliveryPartnerAvailability')
          .call({
            'partnerAccountId': accountId,
            'partnerProfileId': profileId,
            'available': available,
          });
      if (!mounted) return;
      setState(() {
        _garmentCareAvailable = available;
        _saving = false;
      });
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message ?? 'Could not update Garment Care availability.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update Garment Care availability.'),
        ),
      );
    }
  }

  String get _profileQuery {
    final accountId = _accountId ?? widget.accountId;
    final profileId = _profileId ?? widget.profileId;
    if (accountId.isEmpty || profileId.isEmpty) return '';
    return '?accountId=${Uri.encodeQueryComponent(accountId)}'
        '&profileId=${Uri.encodeQueryComponent(profileId)}';
  }

  void _openGarmentCareDeliveries() {
    final query = _profileQuery;
    context.push('/delivery/garment-care-returns${query.isEmpty ? '' : query}');
  }

  void _openPartnerAccount() {
    final query = _profileQuery;
    if (query.isEmpty) return;
    context.push('/partner/account$query&category=deliveryPartner');
  }

  Future<void> _goBack() async {
    final accountId = (_accountId ?? widget.accountId).trim();
    if (accountId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your account could not be found.')),
      );
      return;
    }

    try {
      final profiles = await AppState.instance.fetchActiveProfilesForAccount(
        accountId,
      );
      if (!mounted) return;
      if (profiles.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No active profiles were found.')),
        );
        return;
      }

      final selectedProfile = await Navigator.of(
        context,
        rootNavigator: true,
      ).push<Map<String, dynamic>>(
        MaterialPageRoute<Map<String, dynamic>>(
          builder: (_) => ProfileSelectionScreen(profiles: profiles),
        ),
      );
      if (selectedProfile == null || !mounted) return;

      final profileId = (selectedProfile['profileId'] ??
              selectedProfile['docId'] ??
              selectedProfile['id'] ??
              '')
          .toString()
          .trim();
      if (profileId.isEmpty) return;

      await AppState.instance.setActiveProfileForAccount(
        accountId: accountId,
        profileId: profileId,
      );
      if (!mounted) return;
      context.go(_destinationForProfile(selectedProfile, accountId));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open profile selection.')),
      );
    }
  }

  String _destinationForProfile(
    Map<String, dynamic> profile,
    String accountId,
  ) {
    final role = (profile['role'] ?? 'customer')
        .toString()
        .trim()
        .toLowerCase();
    final profileId = (profile['profileId'] ?? profile['docId'] ?? profile['id'] ?? '')
        .toString()
        .trim();
    final encodedAccountId = Uri.encodeQueryComponent(accountId);
    final encodedProfileId = Uri.encodeQueryComponent(profileId);
    final partnerType = (profile['partnerType'] ?? '').toString().trim();

    if (role == 'customer') return '/home';
    if (role == 'owner') return '/owner';
    if (role == 'tailor') return '/tailor';
    if (role == 'delivery' || role == 'delivery_partner') {
      return '/delivery/services';
    }
    if (role != 'partner') return '/home';

    final profileQuery = '?accountId=$encodedAccountId&profileId=$encodedProfileId';
    switch (partnerType) {
      case 'tailor':
        return '/tailor$profileQuery';
      case 'deliveryPartner':
        return '/delivery/services$profileQuery';
      case 'designer':
        return '/partner/designer/catalogue$profileQuery';
      default:
        return '/partner/landing$profileQuery'
            '&category=${Uri.encodeQueryComponent(partnerType)}';
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading: false,
      leading: IconButton(
        tooltip: 'Back',
        onPressed: _goBack,
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      title: const Text('Delivery Services'),
      actions: [
        IconButton(
          tooltip: 'Partner profile',
          onPressed: _profileId == null ? null : _openPartnerAccount,
          icon: const Icon(Icons.account_circle_outlined),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Choose a delivery service. Each service keeps its own availability and work list.',
        ),
        const SizedBox(height: 16),
        _serviceCard(
          icon: Icons.checkroom_outlined,
          title: 'Tailoring deliveries',
          description:
              'Open the existing tailoring pickup and delivery work list.',
          action: OutlinedButton.icon(
            onPressed: () => context.push('/delivery'),
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Open Tailoring'),
          ),
        ),
        const SizedBox(height: 12),
        _serviceCard(
          icon: Icons.local_laundry_service_outlined,
          title: 'Garment Care deliveries',
          description: _loading
              ? 'Checking your Delivery Partner profile…'
              : !_eligible
              ? 'Your profile must be approved, active and verified to accept returns.'
              : _garmentCareAvailable
              ? 'Online · eligible for Customer returns in your service PIN codes.'
              : 'Offline · turn on when you can take Customer returns.',
          trailing: _loading || _saving
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Switch.adaptive(
                  value: _garmentCareAvailable,
                  onChanged: _eligible ? _setGarmentCareAvailability : null,
                ),
          action: OutlinedButton.icon(
            onPressed: _profileId == null ? null : _openGarmentCareDeliveries,
            icon: const Icon(Icons.assignment_return_outlined),
            label: const Text('Open Garment Care work'),
          ),
          footer: _error == null
              ? null
              : Text(_error!, style: const TextStyle(color: Colors.redAccent)),
        ),
        const SizedBox(height: 12),
        _serviceCard(
          icon: Icons.storefront_outlined,
          title: 'Brand, rental & other deliveries',
          description:
              'These services will have their own availability and work lists when their delivery workflows are connected.',
          trailing: const Chip(label: Text('Not connected yet')),
        ),
      ],
    ),
  );

  Widget _serviceCard({
    required IconData icon,
    required String title,
    required String description,
    Widget? trailing,
    Widget? action,
    Widget? footer,
  }) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              trailing ?? const SizedBox.shrink(),
            ],
          ),
          const SizedBox(height: 8),
          Text(description),
          if (footer case final footerWidget?) ...[
            const SizedBox(height: 8),
            footerWidget,
          ],
          if (action != null) ...[const SizedBox(height: 10), action],
        ],
      ),
    ),
  );
}
