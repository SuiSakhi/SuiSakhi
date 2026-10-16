import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_state.dart';
import '../../core/garment_care_guidance.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/dress.dart';
import '../../models/payment_models.dart';
import '../../models/user_profile.dart';
import '../../services/claude_smart_assistant_service.dart';
import '../../services/order_lifecycle_service.dart';
import '../../services/customer_fabric_asset_service.dart';
import '../../widgets/orders/delivery_pin_dialog.dart';
import '../../widgets/orders/order_tracking_tag.dart';
import '../../widgets/orders/order_design_references.dart';
import '../../widgets/orders/optional_pickup_photo_dialog.dart';
import '../../widgets/orders/pickup_photo_attachment_button.dart';

class TailorDashboardScreen extends StatefulWidget {
  const TailorDashboardScreen({
    super.key,
    this.accountId,
    this.tailorProfileId,
  });

  final String? accountId;
  final String? tailorProfileId;

  bool get hasApprovedPartnerContext {
    return accountId?.trim().isNotEmpty == true &&
        tailorProfileId?.trim().isNotEmpty == true;
  }

  @override
  State<TailorDashboardScreen> createState() => _TailorDashboardScreenState();
}

class _TailorDashboardScreenState extends State<TailorDashboardScreen> {
  int _tab = 0; // 0 = Offers, 1 = Orders, 2 = Rates
  List<DressOrder> _orders = [];
  bool _loadingOrders = true;
  bool _availabilityLoaded = false;
  bool _availabilityReady = false;
  bool _availableForOrders = false;
  bool _availabilitySaving = false;
  String? _availabilityError;
  String? _respondingOfferId;

  @override
  void initState() {
    super.initState();
    _loadOrders();
    _loadAvailability();
  }

  Future<void> _loadAvailability() async {
    if (!widget.hasApprovedPartnerContext) {
      if (mounted) setState(() => _availabilityLoaded = true);
      return;
    }

    try {
      final profile = await FirebaseFirestore.instance
          .collection('accounts')
          .doc(widget.accountId!.trim())
          .collection('profiles')
          .doc(widget.tailorProfileId!.trim())
          .get();
      final data = profile.data() ?? const <String, dynamic>{};
      final activeAndApproved =
          data['role'] == 'partner' &&
          data['partnerType'] == 'tailor' &&
          data['status'] == 'active' &&
          data['operationalStatus'] == 'active' &&
          data['activationStatus'] == 'active' &&
          data['approvalStatus'] == 'approved' &&
          data['kycStatus'] == 'verified';
      if (!mounted) return;
      setState(() {
        _availabilityReady = activeAndApproved;
        _availableForOrders =
            activeAndApproved && data['availabilityStatus'] == 'available';
        _availabilityLoaded = true;
        _availabilityError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _availabilityLoaded = true;
        _availabilityError = 'Could not load availability. Tap to retry.';
      });
    }
  }

  Future<void> _setAvailability(bool available) async {
    if (_availabilitySaving || (available && !_availabilityReady)) return;
    setState(() {
      _availabilitySaving = true;
      _availabilityError = null;
    });
    try {
      await FirebaseFunctions.instance
          .httpsCallable('setTailorAvailability')
          .call({
            'accountId': widget.accountId!.trim(),
            'profileId': widget.tailorProfileId!.trim(),
            'available': available,
          });
      if (!mounted) return;
      setState(() {
        _availableForOrders = available;
        _availabilitySaving = false;
      });
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      final rawMessage = error.message?.trim();
      final message =
          error.code == 'not-found' &&
              (rawMessage == null || rawMessage.toUpperCase() == 'NOT_FOUND')
          ? 'Availability service is not deployed to this Firebase project yet.'
          : rawMessage ?? 'Could not update availability. Please retry.';
      setState(() => _availabilitySaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _availabilitySaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update availability. Please retry.'),
        ),
      );
    }
  }

  Future<void> _loadOrders() async {
    final accountId = widget.accountId?.trim();
    final profileId = widget.tailorProfileId?.trim();
    if (accountId == null ||
        accountId.isEmpty ||
        profileId == null ||
        profileId.isEmpty) {
      if (mounted) {
        setState(() {
          _orders = [];
          _loadingOrders = false;
        });
      }
      return;
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection('orders')
          .where('assignedTailorAccountId', isEqualTo: accountId)
          .where('assignedTailorProfileId', isEqualTo: profileId)
          .get();
      if (mounted) {
        setState(() {
          _orders =
              snap.docs
                  .where((doc) {
                    final data = doc.data();
                    return data['assignmentVersion'] == 'v1' &&
                        data['assignmentStatus'] == 'finalized';
                  })
                  .map((d) => DressOrder.fromFirestore(d.id, d.data()))
                  .toList()
                ..sort((a, b) => b.orderDate.compareTo(a.orderDate));
          _loadingOrders = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingOrders = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            _buildAvailabilityControl(),
            _buildTabBar(),
            Expanded(
              child: _tab == 0
                  ? _buildOffersList()
                  : _tab == 1
                  ? _buildOrdersList()
                  : _buildRatesList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailabilityControl() {
    if (!widget.hasApprovedPartnerContext) return const SizedBox.shrink();

    final title = !_availabilityLoaded && _availabilityError == null
        ? 'Checking availability'
        : _availabilityError != null
        ? 'Availability unavailable'
        : !_availabilityReady
        ? 'Partner profile not active'
        : _availableForOrders
        ? 'Available for orders'
        : 'Not taking new orders';
    final subtitle = !_availabilityLoaded && _availabilityError == null
        ? 'One moment…'
        : _availabilityError ??
              (!_availabilityReady
                  ? 'An approved, active Tailor profile is required.'
                  : _availableForOrders
                  ? 'Eligible order offers can be sent to you.'
                  : 'Turn this on when you are ready to receive work.');

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Icon(
              _availableForOrders
                  ? Icons.check_circle_outline_rounded
                  : Icons.pause_circle_outline_rounded,
              color: _availableForOrders
                  ? AppColors.success
                  : AppColors.textHint,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.labelMedium),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textHint,
                    ),
                  ),
                ],
              ),
            ),
            if (_availabilityError != null)
              IconButton(
                tooltip: 'Retry',
                onPressed: _loadAvailability,
                icon: const Icon(Icons.refresh_rounded),
              )
            else if (!_availabilityLoaded || _availabilitySaving)
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Switch.adaptive(
                value: _availableForOrders,
                onChanged: _availabilityReady ? _setAvailability : null,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _showTailorContactDialog(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 2,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tailor Portal', style: AppTextStyles.bodyMedium),
                      ListenableBuilder(
                        listenable: AppState.instance,
                        builder: (context2, child) => Text(
                          AppState.instance.displayName,
                          style: AppTextStyles.displayMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        'Tap to update email',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textHint,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.content_cut_rounded,
                  color: Color(0xFF4CAF50),
                  size: 15,
                ),
                const SizedBox(width: 6),
                Text(
                  'Tailor',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: const Color(0xFF4CAF50),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () {
              final accountId = widget.accountId?.trim() ?? '';
              final profileId = widget.tailorProfileId?.trim() ?? '';

              if (accountId.isNotEmpty && profileId.isNotEmpty) {
                context.push(
                  '/partner/account'
                  '?accountId=${Uri.encodeQueryComponent(accountId)}'
                  '&profileId=${Uri.encodeQueryComponent(profileId)}'
                  '&category=tailor',
                );
                return;
              }

              context.push('/tailor-account');
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.account_circle_outlined,
                color: AppColors.textSecondary,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTailorContactDialog(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final p = AppState.instance.profile;
    final fullName = (p?.name ?? user?.displayName ?? '').trim();
    final parts = fullName.split(RegExp(r'\s+'));
    final firstName = parts.isNotEmpty ? parts.first : '—';
    final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '—';
    final phone = (user?.phoneNumber ?? '').trim();
    final emailCtrl = TextEditingController(
      text: (p?.email ?? user?.email ?? '').trim(),
    );
    final formKey = GlobalKey<FormState>();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('My details'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Phone and name are set at sign-up. You can change your email for shop messages.',
                  style: TextStyle(fontSize: 13, height: 1.35),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: firstName,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'First name',
                    border: OutlineInputBorder(),
                    filled: true,
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: lastName,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Last name',
                    border: OutlineInputBorder(),
                    filled: true,
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: phone.isEmpty ? '—' : phone,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Mobile number',
                    border: OutlineInputBorder(),
                    filled: true,
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email address',
                    hintText: 'you@example.com',
                    border: OutlineInputBorder(),
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                  ),
                  validator: (v) {
                    final t = v?.trim() ?? '';
                    if (t.isEmpty) return null;
                    if (!t.contains('@') || t.length < 5) {
                      return 'Enter a valid email or leave blank';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final existing = AppState.instance.profile;
              final em = emailCtrl.text.trim();
              if (existing != null) {
                AppState.instance.setProfile(
                  UserProfile(
                    name: existing.name,
                    gender: existing.gender,
                    age: existing.age,
                    role: existing.role,
                    avatarPath: existing.avatarPath,
                    email: em.isEmpty ? null : em,
                    photoUrl: existing.photoUrl,
                    notifyWhatsApp: existing.notifyWhatsApp,
                    payoutUpiId: existing.payoutUpiId,
                    deliveryAddress: existing.deliveryAddress,
                  ),
                );
              } else {
                AppState.instance.setProfile(
                  UserProfile(
                    name: fullName.isEmpty ? 'Tailor' : fullName,
                    role: UserRole.tailor,
                    email: em.isEmpty ? null : em,
                  ),
                );
              }
              await AppState.instance.saveUserProfile();
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (!context.mounted) return;
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Email saved'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ).then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) => emailCtrl.dispose());
    });
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          _TabBtn(
            label: 'Offers',
            selected: _tab == 0,
            onTap: () => setState(() => _tab = 0),
          ),
          const SizedBox(width: 10),
          _TabBtn(
            label: 'My Orders',
            selected: _tab == 1,
            onTap: () {
              setState(() => _tab = 1);
              _loadOrders();
            },
          ),
          const SizedBox(width: 10),
          _TabBtn(
            label: 'Rate Card',
            selected: _tab == 2,
            onTap: () => setState(() => _tab = 2),
          ),
        ],
      ),
    );
  }

  Widget _buildOffersList() {
    if (!widget.hasApprovedPartnerContext) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Active Tailor profile required to receive order offers.',
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final offers = FirebaseFirestore.instance
        .collection('accounts')
        .doc(widget.accountId!.trim())
        .collection('profiles')
        .doc(widget.tailorProfileId!.trim())
        .collection('order_offers')
        .where('status', isEqualTo: 'offered')
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: offers,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Could not load order offers. Please retry later.',
              style: AppTextStyles.bodyMedium,
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs.toList()
          ..sort((a, b) {
            final aDate = a.data()['expiresAt'];
            final bDate = b.data()['expiresAt'];
            final aValue = aDate is Timestamp ? aDate.toDate() : DateTime.now();
            final bValue = bDate is Timestamp ? bDate.toDate() : DateTime.now();
            return aValue.compareTo(bValue);
          });
        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.inbox_outlined,
                    size: 54,
                    color: AppColors.textHint,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No order requests right now',
                    style: AppTextStyles.headlineMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Keep your availability on when you are ready for new work.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textHint,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          itemCount: docs.length,
          itemBuilder: (context, index) => _buildOfferCard(docs[index]),
        );
      },
    );
  }

  Widget _buildOfferCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final expires = data['expiresAt'];
    final expiryText = expires is Timestamp
        ? 'Reply by ${TimeOfDay.fromDateTime(expires.toDate().toLocal()).format(context)}'
        : 'Reply before the offer expires';
    final imageUrl = data['designImageUrl']?.toString() ?? '';
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      imageUrl,
                      width: 66,
                      height: 78,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const SizedBox.shrink(),
                    ),
                  ),
                if (imageUrl.isNotEmpty) const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['dressType']?.toString() ?? 'Stitching request',
                        style: AppTextStyles.headlineSmall,
                      ),
                      if ((data['designTemplateTitle']?.toString() ?? '')
                          .isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Design: ${data['designTemplateTitle']}',
                            style: AppTextStyles.bodySmall,
                          ),
                        ),
                      if ((data['fabricChoice']?.toString() ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            'Fabric: ${data['fabricChoice']}',
                            style: AppTextStyles.bodySmall,
                          ),
                        ),
                      if ((data['fabricDescription']?.toString() ?? '')
                          .isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            'Material: ${data['fabricDescription']}',
                            style: AppTextStyles.bodySmall,
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Service area: ${data['deliveryPincode'] ?? '—'}',
                          style: AppTextStyles.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Choose an expected completion date when you accept.',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              expiryText,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textHint,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _respondingOfferId == doc.id
                        ? null
                        : () => _respondToOffer(doc, 'decline'),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _respondingOfferId == doc.id
                        ? null
                        : () => _respondToOffer(doc, 'accept'),
                    child: _respondingOfferId == doc.id
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _respondToOffer(
    QueryDocumentSnapshot<Map<String, dynamic>> offer,
    String decision,
  ) async {
    DateTime? expectedReadyAt;
    if (decision == 'accept') {
      final now = DateTime.now();
      expectedReadyAt = await showDatePicker(
        context: context,
        initialDate: DateUtils.dateOnly(now.add(const Duration(days: 14))),
        firstDate: DateUtils.dateOnly(now.add(const Duration(days: 1))),
        lastDate: DateUtils.dateOnly(now.add(const Duration(days: 366))),
        helpText: 'Expected order completion',
        confirmText: 'Continue',
      );
      if (expectedReadyAt == null || !mounted) return;
    }
    setState(() => _respondingOfferId = offer.id);
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('respondToTailorOrderOffer')
          .call({
            'accountId': widget.accountId!.trim(),
            'profileId': widget.tailorProfileId!.trim(),
            'orderId': offer.data()['orderId'],
            'decision': decision,
            if (expectedReadyAt != null)
              'expectedReadyAtMillis': DateTime(
                expectedReadyAt.year,
                expectedReadyAt.month,
                expectedReadyAt.day,
                23,
                59,
              ).millisecondsSinceEpoch,
          });
      final response = result.data is Map
          ? Map<String, dynamic>.from(result.data as Map)
          : const <String, dynamic>{};
      final accepted = response['status'] == 'accepted';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accepted
                ? 'Accepted. The Customer can review the design, material, total and expected completion date before paying the 50% advance.'
                : response['status'] == 'expired'
                ? 'This offer expired. SuiSakhi is contacting the next eligible Tailor.'
                : 'Request declined. SuiSakhi will offer it to the next eligible Tailor.',
          ),
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message ?? 'Could not update this offer.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update this offer. Please retry.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _respondingOfferId = null);
    }
  }

  Widget _buildOrdersList() {
    if (_loadingOrders) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadOrders,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: 420,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.inbox_outlined,
                      size: 64,
                      color: AppColors.textHint,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No active orders',
                      style: AppTextStyles.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Orders assigned to this Tailor profile will appear here. '
                      'New offers are in the Offers tab.',
                      style: AppTextStyles.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final ordersByMonth = <String, List<DressOrder>>{};
    for (final order in _orders) {
      final date = order.orderDate;
      final key = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      ordersByMonth.putIfAbsent(key, () => <DressOrder>[]).add(order);
    }

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'My Orders (${_orders.length})',
            style: AppTextStyles.headlineMedium,
          ),
          const SizedBox(height: 16),
          for (final monthOrders in ordersByMonth.values) ...[
            Text(
              '${_monthLabel(monthOrders.first.orderDate)} (${monthOrders.length})',
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            ...monthOrders.map(
              (order) => _OrderCard(
                order: order,
                onStatusUpdate: () => _updateStatus(order),
                onArrangeMeasurement: () => _arrangeMeasurement(order),
                onConfirmMeasurement: () =>
                    _confirmProductionTask(order, 'confirmMeasurement'),
                onReopenMeasurement: () =>
                    _confirmProductionTask(order, 'reopenMeasurement'),
                onReceivePickup: () =>
                    _confirmProductionTask(order, 'receivePickup'),
                onAssignPickupPartner:
                    order.usesProductionAssignment &&
                        [
                          PaymentStatus.advancePaid,
                          PaymentStatus.fullyPaid,
                        ].contains(order.paymentStatus) &&
                        [
                          'awaiting_assignment',
                          'assigned',
                        ].contains(order.inboundPickupStatus)
                    ? () => _assignInboundPickupPartner(order)
                    : null,
                onAssignOutboundPartner:
                    order.usesProductionAssignment &&
                        order.status == OrderStatus.readyForPickup &&
                        order.paymentStatus == PaymentStatus.fullyPaid &&
                        order.outboundHandoverAcceptedAt == null &&
                        [
                          "awaiting_assignment",
                          "assigned",
                        ].contains(order.outboundHandoverStatus)
                    ? () => _assignOutboundHandoverPartner(order)
                    : null,
                onCollectPickup:
                    order.inboundPickupStatus == 'assigned' &&
                        order.inboundPickupPartnerType == 'tailor' &&
                        order.inboundPickupPartnerAccountId ==
                            widget.accountId?.trim() &&
                        order.inboundPickupPartnerProfileId ==
                            widget.tailorProfileId?.trim()
                    ? () => _advancePartnerHandover(order, 'collectInbound')
                    : null,
                onDeclinePickup:
                    order.inboundPickupStatus == 'assigned' &&
                        order.inboundPickupPartnerType == 'tailor' &&
                        order.inboundPickupPartnerAccountId ==
                            widget.accountId?.trim() &&
                        order.inboundPickupPartnerProfileId ==
                            widget.tailorProfileId?.trim()
                    ? () => _advancePartnerHandover(order, 'declineInbound')
                    : null,
                onAcceptDelivery:
                    order.outboundHandoverStatus == 'assigned' &&
                        order.outboundHandoverPartnerType == 'tailor' &&
                        order.outboundHandoverPartnerAccountId ==
                            widget.accountId?.trim() &&
                        order.outboundHandoverPartnerProfileId ==
                            widget.tailorProfileId?.trim() &&
                        order.status == OrderStatus.readyForPickup &&
                        order.paymentStatus == PaymentStatus.fullyPaid
                    ? () => _advancePartnerHandover(order, 'accept')
                    : null,
                onDeclineDelivery:
                    order.outboundHandoverStatus == 'assigned' &&
                        order.outboundHandoverPartnerType == 'tailor' &&
                        order.outboundHandoverPartnerAccountId ==
                            widget.accountId?.trim() &&
                        order.outboundHandoverPartnerProfileId ==
                            widget.tailorProfileId?.trim()
                    ? () => _advancePartnerHandover(order, 'declineOutbound')
                    : null,
                onMarkDelivered:
                    order.status == OrderStatus.outForDelivery &&
                        order.deliveryPartnerType == 'tailor' &&
                        order.deliveryPartnerAccountId ==
                            widget.accountId?.trim() &&
                        order.deliveryPartnerProfileId ==
                            widget.tailorProfileId?.trim()
                    ? () => _advancePartnerHandover(order, 'delivered')
                    : null,
                onResolveWarranty:
                    order.status == OrderStatus.delivered &&
                        order.warrantyClaimStatus == 'open'
                    ? () => _resolveWarrantyIssue(order)
                    : null,
                onEditGarmentRecord:
                    order.usesProductionAssignment &&
                        [
                          OrderStatus.qcPending,
                          OrderStatus.qcPassed,
                          OrderStatus.readyForPickup,
                        ].contains(order.status) &&
                        order.outboundHandoverAcceptedAt == null
                    ? () => _editGarmentRecord(order)
                    : null,
                onCallWarrantyCustomer:
                    (order.customerPhone?.trim().isNotEmpty == true)
                    ? () => _callWarrantyCustomer(order.customerPhone!)
                    : null,
                onAiChecklist: () => _showTailorAiChecklist(context, order),
              ),
            ),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }

  String _monthLabel(DateTime date) {
    const monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${monthNames[date.month - 1]} ${date.year}';
  }

  void _showTailorAiChecklist(BuildContext context, DressOrder order) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _TailorChecklistDialog(order: order),
    );
  }

  Future<void> _updateStatus(DressOrder order) async {
    final next = order.status.nextForTailor;
    if (next == null) return;
    if (order.usesProductionAssignment &&
        next == OrderStatus.inStitching &&
        order.fabricPurchaseEstimate?['estimatedMeters'] is num) {
      final review = order.fabricRequirementReview ?? const <String, dynamic>{};
      final reviewStatus = review['status']?.toString();
      if (reviewStatus == 'shortfall_pending_customer') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Waiting for the Customer to confirm the extra fabric before cutting.'),
        ));
        return;
      }
      if (!['verified_no_shortfall', 'customer_confirmed'].contains(reviewStatus)) {
        final result = await showDialog<Map<String, String>>(
          context: context,
          builder: (_) => _FabricRequirementDialog(
            estimateMeters: (order.fabricPurchaseEstimate!['estimatedMeters'] as num).toDouble(),
          ),
        );
        if (result == null || !mounted) return;
        try {
          final response = await OrderLifecycleService.saveTailorFabricRequirementReview(
            orderId: order.id,
            accountId: widget.accountId!.trim(),
            profileId: widget.tailorProfileId!.trim(),
            actualRequiredMeters: double.parse(result['actualMeters']!),
            note: result['note'] ?? '',
          );
          await _loadOrders();
          if (!mounted) return;
          if (response['status'] == 'shortfall_pending_customer') {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Fabric shortfall sent to the Customer. Cutting is held until they confirm.'),
            ));
            return;
          }
        } on FirebaseFunctionsException catch (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(error.message ?? 'Could not save the fabric check.'),
            ));
          }
          return;
        }
      }
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Advance to “${next.label}”?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      if (order.usesProductionAssignment) {
        try {
          await OrderLifecycleService.advanceTailorOrder(
            orderId: order.id,
            accountId: widget.accountId!.trim(),
            profileId: widget.tailorProfileId!.trim(),
            nextStatus: next.name,
          );
        } on FirebaseFunctionsException catch (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(error.message ?? 'Could not update the order.'),
              ),
            );
          }
          return;
        }
      } else {
        await AppState.instance.updateOrderStatus(order.id, next.name);
      }
      _loadOrders();
    }
  }

  Future<void> _confirmProductionTask(DressOrder order, String action) async {
    if (action == 'reopenMeasurement') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Re-initiate measurement?'),
          content: const Text(
            'The existing measurement plan will be cleared. You can arrange the method again and confirm the measurements when ready.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep current measurements'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Re-initiate'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    final trackingId = order.orderTrackingId?.trim() ?? '';
    if (!RegExp(r'^\d{12}$').hasMatch(trackingId)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'The order tag is still being generated. Refresh and try again.',
            ),
          ),
        );
      }
      return;
    }
    try {
      await OrderLifecycleService.confirmTailorProductionTask(
        orderId: order.id,
        accountId: widget.accountId!.trim(),
        profileId: widget.tailorProfileId!.trim(),
        action: action,
        orderTrackingId: trackingId,
      );
      await _loadOrders();
      if (mounted) {
        final message = switch (action) {
          'confirmMeasurement' => 'Measurements confirmed.',
          'reopenMeasurement' =>
            'Measurement has been re-initiated. Arrange the next step when ready.',
          _ => 'Item received.',
        };
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } on FirebaseFunctionsException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message ?? 'Could not confirm this task.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not confirm this task. Please retry.'),
          ),
        );
      }
    }
  }

  Future<void> _editGarmentRecord(DressOrder order) async {
    final draft = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _GarmentRecordEditorDialog(order: order),
    );
    if (draft == null || !mounted) return;
    final accountId = widget.accountId?.trim() ?? '';
    final profileId = widget.tailorProfileId?.trim() ?? '';
    if (accountId.isEmpty || profileId.isEmpty) return;
    try {
      await OrderLifecycleService.saveTailorGarmentRecord(
        orderId: order.id,
        accountId: accountId,
        profileId: profileId,
        fiberComposition: draft['fiberComposition'] ?? '',
        compositionSource: draft['compositionSource'] ?? 'not_provided',
        careInstructions: draft['careInstructions'] ?? '',
        constructionNotes: draft['constructionNotes'] ?? '',
        qualityCheckNotes: draft['qualityCheckNotes'] ?? '',
      );
      await _loadOrders();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Garment record saved.')));
      }
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      final message = error.code == 'not-found'
          ? 'Garment record saving is not deployed to this Firebase project yet.'
          : error.message ?? 'Could not save the garment record.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save the garment record. Please retry.'),
          ),
        );
      }
    }
  }

  Future<void> _advancePartnerHandover(DressOrder order, String action) async {
    final accountId = widget.accountId?.trim();
    final profileId = widget.tailorProfileId?.trim();
    if (accountId == null ||
        accountId.isEmpty ||
        profileId == null ||
        profileId.isEmpty) {
      return;
    }
    String? deliveryPin;
    String? pickupPhotoPath;
    if (action == 'collectInbound') {
      final photoResult = await showOptionalPickupPhotoDialog(
        context: context,
        orderId: order.id,
      );
      if (photoResult.cancelled) return;
      pickupPhotoPath = photoResult.storagePath;
    }
    if (action == 'delivered' && order.usesProductionAssignment) {
      if (!mounted) return;
      deliveryPin = await showDeliveryPinDialog(context);
      if (deliveryPin == null) return;
      if (!RegExp(r'^\d{4}$').hasMatch(deliveryPin)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Enter the 4-digit customer delivery PIN.'),
            ),
          );
        }
        return;
      }
    }
    try {
      await OrderLifecycleService.advanceDeliveryOrder(
        orderId: order.id,
        accountId: accountId,
        profileId: profileId,
        action: action,
        deliveryPin: deliveryPin,
        pickupPhotoPath: pickupPhotoPath,
      );
      await _loadOrders();
      if (!mounted) return;
      final message = switch (action) {
        'collectInbound' => 'Pickup recorded at the Tailor.',
        'declineInbound' => 'Pickup task passed to the next eligible Partner.',
        'accept' => 'Return handover started.',
        'declineOutbound' =>
          'Delivery task passed to the next eligible Partner.',
        _ => 'Order delivered to the Customer.',
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } on FirebaseFunctionsException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message ?? 'Could not update handover.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update handover. Please retry.'),
          ),
        );
      }
    }
  }

  Future<void> _callWarrantyCustomer(String phone) async {
    try {
      final launched = await launchUrl(Uri(scheme: 'tel', path: phone.trim()));
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the phone app.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the phone app.')),
        );
      }
    }
  }

  Future<void> _resolveWarrantyIssue(DressOrder order) async {
    final resolution = await showDialog<String>(
      context: context,
      builder: (_) => const _WarrantyResolutionDialog(),
    );
    if (resolution == null || resolution.trim().length < 3 || !mounted) return;
    try {
      await OrderLifecycleService.resolveTailorWarrantyIssue(
        orderId: order.id,
        accountId: widget.accountId!.trim(),
        profileId: widget.tailorProfileId!.trim(),
        resolution: resolution.trim(),
      );
      await _loadOrders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Warranty follow-up recorded.')),
        );
      }
    } on FirebaseFunctionsException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message ?? 'Could not update the request.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not save the warranty follow-up. Please retry.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _assignInboundPickupPartner(DressOrder order) async {
    final tailorAccountId = widget.accountId?.trim() ?? '';
    final tailorProfileId = widget.tailorProfileId?.trim() ?? '';
    if (tailorAccountId.isEmpty || tailorProfileId.isEmpty) return;
    try {
      final candidates =
          await OrderLifecycleService.getTailorInboundPickupCandidates(
            orderId: order.id,
            accountId: tailorAccountId,
            profileId: tailorProfileId,
          );
      if (!mounted) return;
      final selected = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Assign pickup partner'),
          content: SizedBox(
            width: double.maxFinite,
            child: candidates.isEmpty
                ? const Text(
                    'No active Tailor, Measurement Partner, or Delivery Partner can collect from this order’s PIN.',
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: candidates.length,
                    itemBuilder: (_, index) {
                      final candidate = candidates[index];
                      final phone = (candidate['contactPhone'] ?? '')
                          .toString();
                      final partnerType =
                          (candidate['partnerType'] ?? 'deliveryPartner')
                              .toString();
                      final role = switch (partnerType) {
                        'tailor' => 'Tailor Partner',
                        'measurementPartner' => 'Measurement Partner',
                        _ => 'Delivery Partner',
                      };
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          (candidate['displayName'] ?? role).toString(),
                        ),
                        subtitle: Text(phone.isEmpty ? role : '$role · $phone'),
                        onTap: () => Navigator.pop(dialogContext, candidate),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
      if (selected == null) return;
      await OrderLifecycleService.assignTailorInboundPickupPartner(
        orderId: order.id,
        tailorAccountId: tailorAccountId,
        tailorProfileId: tailorProfileId,
        accountId: (selected['accountId'] ?? '').toString(),
        profileId: (selected['profileId'] ?? '').toString(),
        partnerType: (selected['partnerType'] ?? 'deliveryPartner').toString(),
      );
      await _loadOrders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Pickup assigned to ${(selected['displayName'] ?? 'Partner').toString()}.',
            ),
          ),
        );
      }
    } on FirebaseFunctionsException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message ?? 'Could not assign pickup.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not assign pickup. Please retry.'),
          ),
        );
      }
    }
  }

  Future<void> _assignOutboundHandoverPartner(DressOrder order) async {
    final tailorAccountId = widget.accountId?.trim() ?? '';
    final tailorProfileId = widget.tailorProfileId?.trim() ?? '';
    if (tailorAccountId.isEmpty || tailorProfileId.isEmpty) return;
    try {
      final candidates =
          await OrderLifecycleService.getTailorOutboundHandoverCandidates(
            orderId: order.id,
            accountId: tailorAccountId,
            profileId: tailorProfileId,
          );
      if (!mounted) return;
      final selected = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Assign delivery partner'),
          content: SizedBox(
            width: double.maxFinite,
            child: candidates.isEmpty
                ? const Text(
                    'No active Tailor, Measurement Partner, or Delivery Partner can deliver to this order’s PIN.',
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: candidates.length,
                    itemBuilder: (_, index) {
                      final candidate = candidates[index];
                      final phone = (candidate['contactPhone'] ?? '')
                          .toString();
                      final partnerType =
                          (candidate['partnerType'] ?? 'deliveryPartner')
                              .toString();
                      final role = switch (partnerType) {
                        'tailor' => 'Tailor Partner',
                        'measurementPartner' => 'Measurement Partner',
                        _ => 'Delivery Partner',
                      };
                      final samePickup =
                          candidate['accountId'] ==
                              order.inboundPickupPartnerAccountId &&
                          candidate['profileId'] ==
                              order.inboundPickupPartnerProfileId;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '${(candidate['displayName'] ?? role).toString()}${samePickup ? ' · Pickup partner' : ''}',
                        ),
                        subtitle: Text(phone.isEmpty ? role : '$role · $phone'),
                        onTap: () => Navigator.pop(dialogContext, candidate),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
      if (selected == null) return;
      await OrderLifecycleService.assignTailorOutboundHandoverPartner(
        orderId: order.id,
        tailorAccountId: tailorAccountId,
        tailorProfileId: tailorProfileId,
        accountId: (selected['accountId'] ?? '').toString(),
        profileId: (selected['profileId'] ?? '').toString(),
        partnerType: (selected['partnerType'] ?? 'deliveryPartner').toString(),
      );
      await _loadOrders();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Delivery assigned to ${(selected['displayName'] ?? 'Partner').toString()}. Customer delivery PIN is ready.',
          ),
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      if (mounted) {
        final message = error.code == 'not-found'
            ? 'Return-delivery assignment Functions are not deployed to this Firebase project yet. Deploy the latest Functions and retry.'
            : error.message ?? 'Could not assign delivery.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not load delivery partners. Please retry.'),
          ),
        );
      }
    }
  }

  Future<void> _arrangeMeasurement(DressOrder order) async {
    final plan = await showDialog<_MeasurementPlanDraft>(
      context: context,
      builder: (_) => _MeasurementPlanDialog(
        order: order,
        accountId: widget.accountId!.trim(),
        profileId: widget.tailorProfileId!.trim(),
      ),
    );
    if (plan == null || !mounted) return;

    try {
      await OrderLifecycleService.saveTailorMeasurementPlan(
        orderId: order.id,
        accountId: widget.accountId!.trim(),
        profileId: widget.tailorProfileId!.trim(),
        method: plan.method,
        measurementPartnerAccountId: plan.measurementPartnerAccountId,
        measurementPartnerProfileId: plan.measurementPartnerProfileId,
        notes: plan.notes,
      );
      await _loadOrders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Measurement plan shared with the Customer.'),
          ),
        );
      }
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      final message = error.code == 'not-found'
          ? 'Measurement planning service is not deployed yet.'
          : error.message ?? 'Could not save the measurement plan.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save the measurement plan. Please retry.'),
        ),
      );
    }
  }

  Widget _buildRatesList() {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final rates = AppState.instance.rates;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Current Stitching Rates',
              style: AppTextStyles.headlineMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Set by shop owner — for your reference',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: 16),
            ...rates.map(
              (r) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.cardShadow,
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.checkroom_rounded,
                        color: AppColors.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.dressType, style: AppTextStyles.titleMedium),
                          if (r.notes != null && r.notes!.isNotEmpty)
                            Text(
                              r.notes!,
                              style: AppTextStyles.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    Text(
                      '₹${r.basePrice.toStringAsFixed(0)}',
                      style: AppTextStyles.headlineMedium.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Normalizes odd heading markers so [MarkdownBody] shows a clear title.
String _sanitizeChecklistMarkdown(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return s;
  final lines = s.split('\n');
  if (lines.isNotEmpty && RegExp(r'^#\s+').hasMatch(lines.first)) {
    lines[0] = lines[0].replaceFirst(RegExp(r'^#+\s*'), '## ');
    s = lines.join('\n');
  }
  return s;
}

class _TailorChecklistDialog extends StatefulWidget {
  final DressOrder order;

  const _TailorChecklistDialog({required this.order});

  @override
  State<_TailorChecklistDialog> createState() => _TailorChecklistDialogState();
}

class _TailorChecklistDialogState extends State<_TailorChecklistDialog> {
  TailorChecklistLanguage _lang = TailorChecklistLanguage.english;
  late Future<SmartAssistantResult> _future;

  @override
  void initState() {
    super.initState();
    _future = ClaudeSmartAssistantService.tailorStitchingChecklist(
      widget.order,
      language: _lang,
    );
  }

  void _pickLang(TailorChecklistLanguage lang) {
    if (lang == _lang) return;
    setState(() {
      _lang = lang;
      _future = ClaudeSmartAssistantService.tailorStitchingChecklist(
        widget.order,
        language: lang,
      );
    });
  }

  MarkdownStyleSheet _markdownStyles() {
    final useDeva =
        _lang == TailorChecklistLanguage.hindi ||
        _lang == TailorChecklistLanguage.marathi;
    final body = useDeva
        ? GoogleFonts.notoSansDevanagari(
            fontSize: 17,
            height: 1.5,
            color: const Color(0xFF0D0D0D),
            fontWeight: FontWeight.w500,
          )
        : GoogleFonts.notoSans(
            fontSize: 17,
            height: 1.5,
            color: const Color(0xFF0D0D0D),
            fontWeight: FontWeight.w600,
          );
    return MarkdownStyleSheet(
      p: body,
      h1: body.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        height: 1.25,
      ),
      h2: body.copyWith(fontSize: 20, fontWeight: FontWeight.w800, height: 1.3),
      h3: body.copyWith(fontSize: 18, fontWeight: FontWeight.w800),
      listBullet: body,
      listIndent: 28,
      blockSpacing: 12,
      strong: body.copyWith(
        fontWeight: FontWeight.w800,
        color: const Color(0xFF000000),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * 0.78;
    return Dialog(
      backgroundColor: const Color(0xFFF0F0F0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 440, maxHeight: maxH),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    color: AppColors.primary,
                    size: 26,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'AI stitching checklist',
                      style: AppTextStyles.headlineMedium.copyWith(
                        fontSize: 19,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Choose simple language · सरल भाषा निवडा',
                style: AppTextStyles.bodySmall.copyWith(
                  color: const Color(0xFF424242),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  FilterChip(
                    label: const Text('English'),
                    selected: _lang == TailorChecklistLanguage.english,
                    onSelected: (_) =>
                        _pickLang(TailorChecklistLanguage.english),
                  ),
                  FilterChip(
                    label: const Text('हिंदी'),
                    selected: _lang == TailorChecklistLanguage.hindi,
                    onSelected: (_) => _pickLang(TailorChecklistLanguage.hindi),
                  ),
                  FilterChip(
                    label: const Text('मराठी'),
                    selected: _lang == TailorChecklistLanguage.marathi,
                    onSelected: (_) =>
                        _pickLang(TailorChecklistLanguage.marathi),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBDBDBD)),
                  ),
                  padding: const EdgeInsets.all(14),
                  child: FutureBuilder<SmartAssistantResult>(
                    future: _future,
                    builder: (context, snap) {
                      if (snap.connectionState != ConnectionState.done) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      final r = snap.data!;
                      if (!r.success) {
                        return SelectableText(
                          r.text,
                          style: GoogleFonts.notoSans(
                            color: Colors.red.shade900,
                            fontSize: 15,
                            height: 1.4,
                          ),
                        );
                      }
                      return SelectionArea(
                        child: SingleChildScrollView(
                          child: MarkdownBody(
                            data: _sanitizeChecklistMarkdown(r.text),
                            styleSheet: _markdownStyles(),
                            shrinkWrap: true,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _measurementMethodLabel(String method) {
  return switch (method) {
    'tailor_home_visit' => 'Tailor home visit',
    'measurement_partner_home_visit' => 'Measurement partner home visit',
    'previous_measurement' => 'Previous measurements',
    'old_garment_reference' => 'Old dress reference',
    'video_appointment' => 'Video appointment',
    _ => 'Measurement to be arranged',
  };
}

String _measurementStatusLabel(String? status) {
  if (status == null || status.isEmpty) return 'not started';
  return switch (status) {
    'awaiting_appointment' => 'awaiting appointment',
    'appointment_scheduled' => 'appointment scheduled',
    'partner_completed' => 'Partner collected; awaiting Tailor review',
    'completed' => 'confirmed by Tailor',
    _ => status.replaceAll('_', ' '),
  };
}

String _inboundPickupStatusLabel(DressOrder order) {
  final status = order.inboundPickupStatus ?? 'not started';
  if (status == 'assigned') {
    final partner = switch (order.inboundPickupPartnerType) {
      'tailor' => 'Tailor',
      'measurementPartner' => 'Measurement Partner',
      'deliveryPartner' => 'Delivery Partner',
      _ => 'Partner',
    };
    return 'assigned to $partner · awaiting collection';
  }
  return switch (status) {
    'collectedFromCustomer' => 'collected from Customer · on the way to Tailor',
    'receivedAtTailor' => 'received at Tailor',
    _ => status.replaceAll('_', ' '),
  };
}

class _MeasurementPlanDraft {
  const _MeasurementPlanDraft({
    required this.method,
    this.measurementPartnerAccountId,
    this.measurementPartnerProfileId,
    this.notes,
  });

  final String method;
  final String? measurementPartnerAccountId;
  final String? measurementPartnerProfileId;
  final String? notes;
}

class _MeasurementPlanDialog extends StatefulWidget {
  const _MeasurementPlanDialog({
    required this.order,
    required this.accountId,
    required this.profileId,
  });

  final DressOrder order;
  final String accountId;
  final String profileId;

  @override
  State<_MeasurementPlanDialog> createState() => _MeasurementPlanDialogState();
}

class _MeasurementPlanDialogState extends State<_MeasurementPlanDialog> {
  static const _methods = <(String, String, String, IconData)>[
    (
      'measurement_partner_home_visit',
      'Request a measurement partner',
      'Choose an approved Partner. They will arrange a home visit slot.',
      Icons.people_outline_rounded,
    ),
    (
      'previous_measurement',
      'Use previous measurements',
      'Use the Customer’s existing measurement record as a starting point.',
      Icons.history_rounded,
    ),
    (
      'old_garment_reference',
      'Use an old dress as reference',
      'Ask the Customer to keep the reference dress ready.',
      Icons.checkroom_outlined,
    ),
    (
      'video_appointment',
      'Video measurement appointment',
      'Choose an approved Partner to schedule the video session and share its link.',
      Icons.video_call_outlined,
    ),
  ];

  late String _method;
  String _notes = '';
  List<Map<String, dynamic>> _measurementPartners = const [];
  bool _loadingPartners = false;
  String? _partnerLoadError;
  String? _selectedPartnerKey;

  bool get _needsPartner => const {
    'measurement_partner_home_visit',
    'video_appointment',
  }.contains(_method);

  Map<String, dynamic>? get _selectedPartner {
    for (final partner in _measurementPartners) {
      final key = '${partner['accountId']}|${partner['profileId']}';
      if (key == _selectedPartnerKey) return partner;
    }
    return null;
  }

  bool get _canSave {
    return !_needsPartner || (!_loadingPartners && _selectedPartner != null);
  }

  @override
  void initState() {
    super.initState();
    final savedMethod = widget.order.measurementMethod;
    _method = savedMethod == 'tailor_home_visit'
        ? 'measurement_partner_home_visit'
        : _methods.any((option) => option.$1 == savedMethod)
        ? savedMethod!
        : 'measurement_partner_home_visit';
    _notes = widget.order.measurementNotes ?? '';
    final assignedAccountId = widget.order.measurementPartnerAccountId;
    final assignedProfileId = widget.order.measurementPartnerProfileId;
    if (assignedAccountId != null && assignedProfileId != null) {
      _selectedPartnerKey = '$assignedAccountId|$assignedProfileId';
    }
    if (_needsPartner) _loadMeasurementPartners(_method);
  }

  Future<void> _loadMeasurementPartners(String method) async {
    setState(() {
      _loadingPartners = true;
      _partnerLoadError = null;
      _measurementPartners = const [];
    });
    try {
      final partners =
          await OrderLifecycleService.getMeasurementPartnerCandidates(
            orderId: widget.order.id,
            accountId: widget.accountId,
            profileId: widget.profileId,
            method: method,
          );
      if (!mounted || method != _method) return;
      setState(() {
        _measurementPartners = partners;
        _loadingPartners = false;
        final hasCurrentSelection =
            _selectedPartnerKey != null &&
            partners.any(
              (partner) =>
                  '${partner['accountId']}|${partner['profileId']}' ==
                  _selectedPartnerKey,
            );
        if (!hasCurrentSelection) {
          Map<String, dynamic>? ownPartnerProfile;
          for (final partner in partners) {
            if (partner['accountId']?.toString() == widget.accountId) {
              ownPartnerProfile = partner;
              break;
            }
          }
          _selectedPartnerKey = ownPartnerProfile == null
              ? null
              : '${ownPartnerProfile['accountId']}|${ownPartnerProfile['profileId']}';
        }
      });
    } catch (error) {
      if (!mounted || method != _method) return;
      setState(() {
        _loadingPartners = false;
        _partnerLoadError = error.toString();
      });
    }
  }

  void _selectMethod(String method) {
    setState(() {
      _method = method;
      if (!_needsPartner) {
        _selectedPartnerKey = null;
        _measurementPartners = const [];
        _partnerLoadError = null;
        _loadingPartners = false;
      }
    });
    if (_needsPartner) _loadMeasurementPartners(method);
  }

  void _save() {
    if (!_canSave) return;
    Navigator.of(context).pop(
      _MeasurementPlanDraft(
        method: _method,
        measurementPartnerAccountId: _selectedPartner?['accountId']?.toString(),
        measurementPartnerProfileId: _selectedPartner?['profileId']?.toString(),
        notes: _notes.trim().isEmpty ? null : _notes.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Arrange measurement'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose the method that fits this order. You decide how the Customer’s measurements will be confirmed.',
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: 10),
              RadioGroup<String>(
                groupValue: _method,
                onChanged: (value) {
                  if (value != null) _selectMethod(value);
                },
                child: Column(
                  children: [
                    for (final option in _methods)
                      RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        value: option.$1,
                        selected: option.$1 == _method,
                        title: Text(option.$2, style: AppTextStyles.bodyMedium),
                        subtitle: Text(
                          option.$3,
                          style: AppTextStyles.bodySmall,
                        ),
                        secondary: Icon(option.$4, color: AppColors.primary),
                      ),
                  ],
                ),
              ),
              if (_needsPartner) ...[
                const SizedBox(height: 10),
                if (_loadingPartners)
                  const LinearProgressIndicator()
                else if (_partnerLoadError != null)
                  Text(
                    'Could not load approved Measurement Partners. Please retry after refreshing.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.error,
                    ),
                  )
                else if (_measurementPartners.isEmpty)
                  Text(
                    'No active approved Measurement Partner is eligible for this order yet.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textHint,
                    ),
                  )
                else
                  DropdownButtonFormField<String>(
                    key: ValueKey(_selectedPartnerKey),
                    initialValue: _selectedPartnerKey,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Measurement Partner',
                      prefixIcon: Icon(Icons.people_outline_rounded),
                    ),
                    items: [
                      for (final partner in _measurementPartners)
                        DropdownMenuItem<String>(
                          value:
                              '${partner['accountId']}|${partner['profileId']}',
                          child: Text(
                            [
                              '${partner['displayName']?.toString() ?? 'Measurement Partner'}${partner['accountId']?.toString() == widget.accountId ? ' · Your Partner profile' : ''}',
                              partner['mobileE164']?.toString() ?? '',
                            ].where((value) => value.trim().isNotEmpty).join(' · '),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) =>
                        setState(() => _selectedPartnerKey = value),
                  ),
                if (_selectedPartner?['accountId']?.toString() ==
                    widget.accountId) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Your approved Measurement Partner profile is selected. Choose another Partner if needed.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textHint,
                    ),
                  ),
                ],
                if (_measurementPartners.isNotEmpty &&
                    !_measurementPartners.any(
                      (partner) =>
                          partner['accountId']?.toString() == widget.accountId,
                    )) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Your Measurement Partner profile appears here when it is approved, supports this method, and covers this order’s PIN.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textHint,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  _method == 'video_appointment'
                      ? 'The selected Partner will schedule the video session and add the meeting link.'
                      : 'The selected Partner will contact the Customer and schedule the home visit.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textHint,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              TextFormField(
                initialValue: _notes,
                minLines: 2,
                maxLines: 4,
                maxLength: 1200,
                decoration: const InputDecoration(
                  labelText: 'Instructions for the Customer',
                  hintText:
                      'For example: please keep the reference dress ready.',
                  alignLabelWithHint: true,
                ),
                onChanged: (value) => _notes = value,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _canSave ? _save : null,
          child: const Text('Share plan'),
        ),
      ],
    );
  }
}

class _TailorPayoutBanner extends StatelessWidget {
  final List<OrderPayoutLine> ledger;

  const _TailorPayoutBanner({required this.ledger});

  @override
  Widget build(BuildContext context) {
    OrderPayoutLine? line;
    for (final l in ledger) {
      if (l.role == 'tailor') {
        line = l;
        break;
      }
    }
    if (line == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF4CAF50).withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Advance share (tailor)',
            style: AppTextStyles.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
              color: const Color(0xFF2E7D32),
            ),
          ),
          Text(
            '₹${line.amount.toStringAsFixed(2)}',
            style: AppTextStyles.titleMedium.copyWith(
              color: const Color(0xFF1B5E20),
            ),
          ),
          if (line.creditToUpi != null && line.creditToUpi!.isNotEmpty)
            Text(
              'Ledger UPI: ${line.creditToUpi}',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textHint,
              ),
            ),
        ],
      ),
    );
  }
}

class _TabBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TabBtn({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final DressOrder order;
  final VoidCallback onStatusUpdate;
  final VoidCallback onArrangeMeasurement;
  final VoidCallback onConfirmMeasurement;
  final VoidCallback onReopenMeasurement;
  final VoidCallback onReceivePickup;
  final VoidCallback? onAssignPickupPartner;
  final VoidCallback? onAssignOutboundPartner;
  final VoidCallback? onCollectPickup;
  final VoidCallback? onDeclinePickup;
  final VoidCallback? onAcceptDelivery;
  final VoidCallback? onDeclineDelivery;
  final VoidCallback? onMarkDelivered;
  final VoidCallback? onResolveWarranty;
  final VoidCallback? onCallWarrantyCustomer;
  final VoidCallback? onEditGarmentRecord;
  final VoidCallback onAiChecklist;

  const _OrderCard({
    required this.order,
    required this.onStatusUpdate,
    required this.onArrangeMeasurement,
    required this.onConfirmMeasurement,
    required this.onReopenMeasurement,
    required this.onReceivePickup,
    required this.onAssignPickupPartner,
    required this.onAssignOutboundPartner,
    required this.onCollectPickup,
    required this.onDeclinePickup,
    required this.onAcceptDelivery,
    required this.onDeclineDelivery,
    required this.onMarkDelivered,
    required this.onResolveWarranty,
    required this.onCallWarrantyCustomer,
    required this.onEditGarmentRecord,
    required this.onAiChecklist,
  });

  String get _nextActionLabel {
    final n = order.status.nextForTailor;
    if (n == null) return '';
    return 'Next: ${n.label}';
  }

  @override
  Widget build(BuildContext context) {
    final measurementUnit = order.measurementSubmittedUnit == 'cm'
        ? 'cm'
        : 'in';
    final fabricEstimateMeters =
        order.fabricPurchaseEstimate?['estimatedMeters'];
    final canUpdate =
        order.status.nextForTailor != null &&
        (!order.usesProductionAssignment ||
            ![
              OrderStatus.pending,
              OrderStatus.pickedUp,
            ].contains(order.status));
    final statusColor = order.usesProductionAssignment
        ? AppColors.success
        : order.status.color;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.checkroom_rounded,
                  color: statusColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.dressType,
                      style: AppTextStyles.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (order.orderTrackingId?.isNotEmpty == true)
                      Text(
                        'Order ID · ${order.orderTrackingId}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textHint,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    OrderTrackingTag.button(context, order.orderTrackingId),
                    if ((order.fabricDescription ?? '').isNotEmpty)
                      Text(
                        order.fabricDescription!,
                        style: AppTextStyles.bodySmall,
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
                    vertical: 4,
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
          if (order.usesProductionAssignment) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (order.customerFabricPreviewAssets.isNotEmpty ||
                          (order.designImageUrl ?? '').isNotEmpty)
                        OrderDesignReferences(
                          customerPreviews: order.customerFabricPreviewAssets,
                          originalCatalogueImageUrl: order.designImageUrl,
                        ),
                      if ((order.designTemplateTitle ?? '').isNotEmpty)
                        Text(
                          'Design: ${order.designTemplateTitle}',
                          style: AppTextStyles.bodySmall,
                        ),
                      if ((order.notes ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: .08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.accent.withValues(alpha: .24),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Customer instructions and references',
                                style: AppTextStyles.bodySmall.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(order.notes!, style: AppTextStyles.bodySmall),
                            ],
                          ),
                        ),
                      ],
                      if ((order.fabricChoice ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Fabric: ${order.fabricChoice}',
                            style: AppTextStyles.bodySmall,
                          ),
                        ),
                      if ((order.customerFabricPhotoPath ?? '').isNotEmpty)
                        _CustomerFabricAssetButton(
                          path: order.customerFabricPhotoPath!,
                          label: 'View customer fabric photo',
                        ),
                      if (fabricEstimateMeters is num)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Customer fabric estimate · ${fabricEstimateMeters.toStringAsFixed(1)} m · verify actual quantity before cutting',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      if (order.expectedReadyAt != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Expected completion: ${MaterialLocalizations.of(context).formatMediumDate(order.expectedReadyAt!.toLocal())}',
                            style: AppTextStyles.bodySmall.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      Text(
                        'For: ${order.orderForText}',
                        style: AppTextStyles.bodySmall,
                      ),
                      Text(
                        'Finalized after Customer paid the 50% advance.',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textHint,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Measurement · ${_measurementStatusLabel(order.measurementStatus)}',
                        style: AppTextStyles.bodySmall,
                      ),
                      if (order.measurementMethod != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            'Plan · ${_measurementMethodLabel(order.measurementMethod!)}',
                            style: AppTextStyles.bodySmall,
                          ),
                        ),
                      if ((order.measurementPartnerName ?? '')
                          .trim()
                          .isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            'Measurement Partner · ${order.measurementPartnerName}',
                            style: AppTextStyles.bodySmall,
                          ),
                        ),
                      if (order.measurementAppointmentAt != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            'Appointment · ${MaterialLocalizations.of(context).formatMediumDate(order.measurementAppointmentAt!.toLocal())} at ${TimeOfDay.fromDateTime(order.measurementAppointmentAt!.toLocal()).format(context)}',
                            style: AppTextStyles.bodySmall,
                          ),
                        ),
                      if ((order.measurementNotes ?? '').trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            'Note · ${order.measurementNotes}',
                            style: AppTextStyles.bodySmall,
                          ),
                        ),
                      if (order.measurementSubmittedValues?.isNotEmpty ==
                          true) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Measurements submitted by Partner (${measurementUnit == 'in' ? 'inches' : 'cm'})',
                          style: AppTextStyles.labelMedium,
                        ),
                        for (final entry
                            in order.measurementSubmittedValues!.entries)
                          Text(
                            '${entry.key} · ${entry.value} $measurementUnit',
                            style: AppTextStyles.bodySmall,
                          ),
                        if ((order.measurementPartnerCompletionNote ?? '')
                            .trim()
                            .isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              'Partner note · ${order.measurementPartnerCompletionNote}',
                              style: AppTextStyles.bodySmall,
                            ),
                          ),
                      ],
                      Text(
                        'Inbound pickup · ${_inboundPickupStatusLabel(order)}',
                        style: AppTextStyles.bodySmall,
                      ),
                      if ((order.inboundPickupPartnerName ?? '')
                          .trim()
                          .isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Collected by · ${order.inboundPickupPartnerName}',
                            style: AppTextStyles.bodySmall.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if ((order.inboundPickupPartnerPhone ?? '')
                          .trim()
                          .isNotEmpty)
                        TextButton.icon(
                          onPressed: () => launchUrl(
                            Uri(
                              scheme: 'tel',
                              path: order.inboundPickupPartnerPhone!.trim(),
                            ),
                          ),
                          icon: const Icon(Icons.call_outlined, size: 18),
                          label: Text(
                            'Call pickup partner · ${order.inboundPickupPartnerPhone}',
                          ),
                        ),
                      if ((order.deliveryPartnerName ?? '').trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Return delivery partner · ${order.deliveryPartnerName}',
                            style: AppTextStyles.bodySmall,
                          ),
                        ),
                      if ((order.deliveryPartnerPhone ?? '').trim().isNotEmpty)
                        TextButton.icon(
                          onPressed: () => launchUrl(
                            Uri(
                              scheme: 'tel',
                              path: order.deliveryPartnerPhone!.trim(),
                            ),
                          ),
                          icon: const Icon(Icons.call_outlined, size: 18),
                          label: Text(
                            'Call delivery partner · ${order.deliveryPartnerPhone}',
                          ),
                        ),
                      if ((order.inboundPickupPhotoPath ?? '').isNotEmpty)
                        PickupPhotoAttachmentButton(
                          storagePath: order.inboundPickupPhotoPath!,
                          label: 'View pickup material photo',
                        ),
                      if (onEditGarmentRecord != null) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: onEditGarmentRecord,
                            icon: const Icon(Icons.fact_check_outlined),
                            label: const Text(
                              'Review / edit Garment DNA report',
                            ),
                          ),
                        ),
                        Text(
                          'Editable during QC and before dispatch. Shared with the Customer after delivery.',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
          if (order.status == OrderStatus.delivered &&
              order.warrantyIssueReportedAt != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Warranty request · ${order.warrantyClaimStatus ?? 'open'}',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.warning,
                    ),
                  ),
                  if ((order.warrantyIssueDescription ?? '').trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        order.warrantyIssueDescription!,
                        style: AppTextStyles.bodySmall,
                      ),
                    ),
                  if (order.warrantyClaimStatus == 'open' &&
                      order.customerPhone?.trim().isNotEmpty == true)
                    TextButton.icon(
                      onPressed: onCallWarrantyCustomer,
                      icon: const Icon(Icons.call_outlined),
                      label: Text('Call Customer · ${order.customerPhone}'),
                    ),
                  if (order.warrantyClaimStatus == 'open')
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: onResolveWarranty,
                        icon: const Icon(Icons.check_circle_outline_rounded),
                        label: const Text('Record follow-up and resolve'),
                      ),
                    )
                  else if ((order.warrantyResolution ?? '').trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Follow-up · ${order.warrantyResolution}',
                        style: AppTextStyles.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (order.deliveryAddress != null &&
              order.deliveryAddress!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  size: 14,
                  color: AppColors.textHint,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    order.deliveryAddress!,
                    style: AppTextStyles.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          if (order.payoutLedger != null) ...[
            const SizedBox(height: 10),
            _TailorPayoutBanner(ledger: order.payoutLedger!),
          ],
          if (order.usesProductionAssignment &&
              order.status != OrderStatus.cancelled &&
              [
                PaymentStatus.advancePaid,
                PaymentStatus.fullyPaid,
              ].contains(order.paymentStatus)) ...[
            if (![
              OrderStatus.readyForPickup,
              OrderStatus.outForDelivery,
              OrderStatus.delivered,
            ].contains(order.status)) ...[
              if (order.measurementStatus == 'completed') ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onReopenMeasurement,
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: const Text('Re-initiate measurement'),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onArrangeMeasurement,
                    icon: const Icon(Icons.event_available_outlined),
                    label: Text(
                      order.measurementMethod == null
                          ? 'Arrange measurement'
                          : 'Update measurement plan',
                    ),
                  ),
                ),
                if (order.measurementStatus == 'partner_completed' ||
                    ![
                      'measurement_partner_home_visit',
                      'video_appointment',
                    ].contains(order.measurementMethod)) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onConfirmMeasurement,
                      icon: const Icon(Icons.straighten_rounded),
                      label: Text(
                        order.measurementStatus == 'partner_completed'
                            ? 'Review and confirm measurements'
                            : 'Confirm measurements completed',
                      ),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  Text(
                    'Waiting for the Measurement Partner to submit the collected measurements.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textHint,
                    ),
                  ),
                ],
              ],
            ],
            if (order.inboundPickupStatus == 'collectedFromCustomer') ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onReceivePickup,
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: const Text('Confirm item received at tailor'),
                ),
              ),
            ],
            if (onAssignPickupPartner != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onAssignPickupPartner,
                  icon: const Icon(Icons.local_shipping_outlined),
                  label: const Text('Assign / change pickup partner'),
                ),
              ),
            ],
            if (order.status == OrderStatus.readyForPickup &&
                order.paymentStatus == PaymentStatus.fullyPaid) ...[
              const SizedBox(height: 8),
              Text(
                'Return delivery · ${order.outboundHandoverStatus == 'assigned' ? 'partner assigned' : 'awaiting partner assignment'}',
                style: AppTextStyles.bodySmall,
              ),
            ],
            if (onAssignOutboundPartner != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onAssignOutboundPartner,
                  icon: const Icon(Icons.local_shipping_outlined),
                  label: Text(
                    order.outboundHandoverStatus == 'assigned'
                        ? 'Assign / change delivery partner'
                        : 'Assign delivery partner',
                  ),
                ),
              ),
            ],
            if (onCollectPickup != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onCollectPickup,
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: const Text('Confirm pickup at tailor'),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onDeclinePickup,
                  child: const Text('Can’t take this pickup'),
                ),
              ),
            ],
            if (onAcceptDelivery != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onAcceptDelivery,
                  icon: const Icon(Icons.local_shipping_outlined),
                  label: const Text('Start return delivery'),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onDeclineDelivery,
                  child: const Text('Can’t take this delivery'),
                ),
              ),
            ],
            if (onMarkDelivered != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onMarkDelivered,
                  icon: const Icon(Icons.done_all_rounded),
                  label: const Text('Confirm customer handover'),
                ),
              ),
            ],
          ],
          if (!order.usesProductionAssignment) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onAiChecklist,
                icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                label: const Text('AI stitching checklist'),
              ),
            ),
          ],
          if (canUpdate &&
              (!order.usesProductionAssignment ||
                  (order.assignmentStatus == 'finalized' &&
                      [
                        PaymentStatus.advancePaid,
                        PaymentStatus.fullyPaid,
                      ].contains(order.paymentStatus)))) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onStatusUpdate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: order.status == OrderStatus.qcPassed
                      ? const Color(0xFF9C27B0)
                      : AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                child: Text(
                  _nextActionLabel,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GarmentRecordEditorDialog extends StatefulWidget {
  const _GarmentRecordEditorDialog({required this.order});

  final DressOrder order;

  @override
  State<_GarmentRecordEditorDialog> createState() =>
      _GarmentRecordEditorDialogState();
}

class _GarmentRecordEditorDialogState
    extends State<_GarmentRecordEditorDialog> {
  late final TextEditingController _fiberComposition;
  late final TextEditingController _careInstructions;
  late final TextEditingController _constructionNotes;
  late final TextEditingController _qualityCheckNotes;
  String _compositionSource = 'not_provided';

  Map<String, dynamic> get _draft =>
      widget.order.garmentRecordDraft ?? const <String, dynamic>{};

  String _initial(String key) => (_draft[key] ?? '').toString();

  @override
  void initState() {
    super.initState();
    _fiberComposition = TextEditingController(
      text: _initial('fiberComposition'),
    );
    final careDraft = _initial('careInstructions');
    _careInstructions = TextEditingController(
      text: careDraft.isNotEmpty
          ? careDraft
          : GarmentCareGuidance.forMaterial(
              widget.order.fabricChoice ?? '',
              widget.order.fabricDescription ?? '',
            ),
    );
    _constructionNotes = TextEditingController(
      text: _initial('constructionNotes'),
    );
    _qualityCheckNotes = TextEditingController(
      text: _initial('qualityCheckNotes'),
    );
    final savedSource = _initial('compositionSource');
    if ([
      'not_provided',
      'supplier_label',
      'customer_label',
      'visual_only',
    ].contains(savedSource)) {
      _compositionSource = savedSource;
    }
  }

  @override
  void dispose() {
    _fiberComposition.dispose();
    _careInstructions.dispose();
    _constructionNotes.dispose();
    _qualityCheckNotes.dispose();
    super.dispose();
  }

  void _save() {
    final composition = _fiberComposition.text.trim();
    Navigator.pop(context, <String, String>{
      'fiberComposition': composition,
      'compositionSource': composition.isEmpty
          ? 'not_provided'
          : _compositionSource,
      'careInstructions': _careInstructions.text.trim(),
      'constructionNotes': _constructionNotes.text.trim(),
      'qualityCheckNotes': _qualityCheckNotes.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Garment DNA report · QC'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Order · ${widget.order.orderTrackingId ?? widget.order.id}',
                style: AppTextStyles.labelMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Design, fabric selection, and the optional pickup photo are added automatically. Enter only details you can support; leave unknown composition or care information blank.',
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _fiberComposition,
                maxLength: 240,
                decoration: const InputDecoration(
                  labelText: 'Fibre composition (optional)',
                  hintText: 'Example: 60% cotton, 40% silk',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _compositionSource,
                decoration: const InputDecoration(
                  labelText: 'Composition source',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'not_provided',
                    child: Text('Not provided'),
                  ),
                  DropdownMenuItem(
                    value: 'supplier_label',
                    child: Text('Supplier label'),
                  ),
                  DropdownMenuItem(
                    value: 'customer_label',
                    child: Text('Customer-provided label'),
                  ),
                  DropdownMenuItem(
                    value: 'visual_only',
                    child: Text('Visual estimate only'),
                  ),
                ],
                onChanged: (value) => setState(
                  () => _compositionSource = value ?? 'not_provided',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _careInstructions,
                maxLength: 600,
                minLines: 4,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Care guidance · review and edit if verified',
                  helperText:
                      'Prefilled from a conservative material guide. It is not a verified care label. Replace it only with supported label or specialist advice.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _constructionNotes,
                maxLength: 800,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Construction / finishing notes (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _qualityCheckNotes,
                maxLength: 1200,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Quality check notes (optional)',
                  hintText:
                      'Fit, seams, closures, finishing, or agreed alterations',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'The customer report will show the source of any composition entry. This record is not a laboratory certificate.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textHint,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save record')),
      ],
    );
  }
}

class _WarrantyResolutionDialog extends StatefulWidget {
  const _WarrantyResolutionDialog();

  @override
  State<_WarrantyResolutionDialog> createState() =>
      _WarrantyResolutionDialogState();
}

class _WarrantyResolutionDialogState extends State<_WarrantyResolutionDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Record warranty follow-up'),
    content: TextField(
      controller: _controller,
      maxLength: 1000,
      maxLines: 4,
      decoration: const InputDecoration(
        hintText:
            'Note the repair or pickup/drop arrangement agreed with the Customer.',
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _controller.text.trim().length < 3
            ? null
            : () => Navigator.pop(context, _controller.text.trim()),
        child: const Text('Resolve request'),
      ),
    ],
  );
}

class _FabricRequirementDialog extends StatefulWidget {
  const _FabricRequirementDialog({required this.estimateMeters});

  final double estimateMeters;

  @override
  State<_FabricRequirementDialog> createState() =>
      _FabricRequirementDialogState();
}

class _FabricRequirementDialogState extends State<_FabricRequirementDialog> {
  late final TextEditingController _actual;
  final TextEditingController _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    _actual = TextEditingController(text: widget.estimateMeters.toStringAsFixed(1));
  }

  @override
  void dispose() {
    _actual.dispose();
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = double.tryParse(_actual.text.trim());
    if (amount == null || !amount.isFinite || amount <= 0 || amount > 100) return;
    Navigator.pop(context, <String, String>{
      'actualMeters': amount.toStringAsFixed(1),
      'note': _note.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Check fabric before cutting'),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Customer estimate · ${widget.estimateMeters.toStringAsFixed(1)} m'),
          const SizedBox(height: 12),
          TextField(
            controller: _actual,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Actual fabric required (metres)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _note,
            maxLength: 600,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Note for the Customer (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const Text('If the actual requirement is higher, cutting waits for Customer confirmation.'),
        ],
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: _submit, child: const Text('Send fabric check')),
    ],
  );
}

class _CustomerFabricAssetButton extends StatelessWidget {
  const _CustomerFabricAssetButton({required this.path, required this.label});

  final String path;
  final String label;

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
    future: CustomerFabricAssetService.downloadUrl(path),
    builder: (context, snapshot) => TextButton.icon(
      onPressed: snapshot.hasData
          ? () => showDialog<void>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: Text(label),
                  content: SizedBox(
                    width: 360,
                    height: 420,
                    child: Image.network(
                      snapshot.data!,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Center(
                        child: Text('This image is unavailable.'),
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              )
          : null,
      icon: const Icon(Icons.image_outlined, size: 18),
      label: Text(snapshot.hasError ? '$label unavailable' : label),
    ),
  );
}
