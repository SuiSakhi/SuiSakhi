import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/app_state.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/dress.dart';
import '../../models/user_profile.dart';

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  List<DressOrder> _recentOrders = [];
  bool _loadingOrders = true;
  int _totalOrders = 0;
  int _pendingOrders = 0;

  /// Rich enrollments (name + mobile + optional login email).
  List<Map<String, dynamic>> _tailorProfiles = [];
  /// Legacy: email in [tailorEmails] but not linked to a profile.
  List<String> _tailorOrphanEmails = [];
  /// Legacy: phone in [tailorPhones] but not linked to a profile.
  List<String> _tailorOrphanPhones = [];

  int get _tailorCount =>
      _tailorProfiles.length +
      _tailorOrphanEmails.length +
      _tailorOrphanPhones.length;

  @override
  void initState() {
    super.initState();
    _loadOrders();
    _loadTailors();
  }

  Future<void> _loadTailors() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('config').doc('admin').get();
      final data = doc.data() ?? {};
      final profiles = <Map<String, dynamic>>[];
      for (final e in List<dynamic>.from(data['tailorProfiles'] ?? [])) {
        if (e is Map) {
          profiles.add(Map<String, dynamic>.from(e));
        }
      }
      final emails = List<String>.from(data['tailorEmails'] ?? [])
          .map((e) => e.toString().toLowerCase())
          .toList();
      final rawPhones = List<String>.from(data['tailorPhones'] ?? []);
      final phones = rawPhones
          .map((p) => AppState.normalizePhoneE164(p) ?? p.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      final profileLoginEmails = profiles
          .map((p) => (p['loginEmail'] as String?)?.toLowerCase())
          .whereType<String>()
          .toSet();
      final profileMobiles =
          profiles.map((p) => p['mobile'] as String?).whereType<String>().toSet();

      final orphanEmails =
          emails.where((e) => !profileLoginEmails.contains(e)).toList();
      final orphanPhones =
          phones.where((p) => !profileMobiles.contains(p)).toList();

      if (mounted) {
        setState(() {
          _tailorProfiles = profiles;
          _tailorOrphanEmails = orphanEmails;
          _tailorOrphanPhones = orphanPhones;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadOrders() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('orders')
          .get();
      if (mounted) {
        final all = snap.docs
            .map((d) => DressOrder.fromFirestore(d.id, d.data()))
            .toList()
          ..sort((a, b) => b.orderDate.compareTo(a.orderDate));

        setState(() {
          _totalOrders = all.length;
          _pendingOrders =
              all.where((o) => o.status == OrderStatus.pending).length;
          _recentOrders = all.take(3).toList();
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
	      _buildTopBar(context),
              const SizedBox(height: 20),
              _buildHeader(context),
              const SizedBox(height: 28),
              Text('Admin Dashboard', style: AppTextStyles.headlineLarge),
              const SizedBox(height: 4),
              Text('Manage your shop, tailors and pricing',
                  style: AppTextStyles.bodyMedium),
              const SizedBox(height: 24),
              _buildStatRow(),
              const SizedBox(height: 28),
              Text('Quick Actions', style: AppTextStyles.headlineMedium),
              const SizedBox(height: 16),
              _buildActionGrid(context),
              const SizedBox(height: 28),
              Text('Recent Orders', style: AppTextStyles.headlineMedium),
              const SizedBox(height: 16),
              _buildRecentOrders(),
            ],
          ),
        ),
      ),
    );
  }

Widget _buildTopBar(BuildContext context) {
  return Row(
    children: [

      IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/home');
          }
        },
      ),

      const SizedBox(width: 8),

      Expanded(
        child: Center(
          child: Text(
            'SuiSakhi',
            style: AppTextStyles.headlineMedium.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),

      const SizedBox(width: 48),

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
              Text('Welcome, SuiSakhi Admin', style: AppTextStyles.bodyMedium),
              ListenableBuilder(
                listenable: AppState.instance,
                builder: (context2, child) => Text(
                  AppState.instance.displayName,
                  style: AppTextStyles.displayMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => _showOwnerDetailsDialog(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF5A623).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: const Color(0xFFF5A623).withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.store_rounded,
                    color: Color(0xFFF5A623), size: 16),
                const SizedBox(width: 6),
                Text('SuiSakhi Admin',
                    style: AppTextStyles.labelMedium
                        .copyWith(color: const Color(0xFFF5A623))),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: () {
            AppState.instance.signOut();
            context.go('/login');
          },
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.logout_rounded,
                color: AppColors.textSecondary, size: 20),
          ),
        ),
      ],
    );
  }

  void _showOwnerDetailsDialog(BuildContext context) {
    final p = AppState.instance.profile;
    final nameCtrl = TextEditingController(text: p?.name ?? '');
    final emailCtrl = TextEditingController(
      text: p?.email ?? FirebaseAuth.instance.currentUser?.email ?? '',
    );
    final upiCtrl = TextEditingController(text: p?.payoutUpiId ?? '');
    var notifyWa = p?.notifyWhatsApp ?? true;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Owner details'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Full name',
                      border: OutlineInputBorder(),
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: upiCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Payout UPI ID (optional)',
                      border: OutlineInputBorder(),
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Order updates via WhatsApp'),
                    value: notifyWa,
                    onChanged: (v) => setDialogState(() => notifyWa = v),
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
                AppState.instance.setProfile(UserProfile(
                  name: nameCtrl.text.trim(),
                  gender: existing?.gender ?? Gender.female,
                  age: existing?.age ?? 0,
                  role: existing?.role ?? UserRole.owner,
                  avatarPath: existing?.avatarPath,
                  email: emailCtrl.text.trim().isEmpty
                      ? null
                      : emailCtrl.text.trim(),
                  photoUrl: existing?.photoUrl,
                  notifyWhatsApp: notifyWa,
                  payoutUpiId: upiCtrl.text.trim().isEmpty
                      ? null
                      : upiCtrl.text.trim(),
                  deliveryAddress: existing?.deliveryAddress,
                ));
                await AppState.instance.saveUserProfile();
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (!context.mounted) return;
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Owner details saved'),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    ).then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        nameCtrl.dispose();
        emailCtrl.dispose();
        upiCtrl.dispose();
      });
    });
  }

  Widget _buildStatRow() {
    final stats = [
      (
        'Total Orders',
        '$_totalOrders',
        Icons.receipt_long_rounded,
        AppColors.primary,
        () => context.push('/orders'),
      ),
      (
        'Active Tailors',
        '$_tailorCount',
        Icons.content_cut_rounded,
        const Color(0xFF4CAF50),
        () => _showTailorsSheet(context),
      ),
      (
        'Pending',
        '$_pendingOrders',
        Icons.access_time_rounded,
        const Color(0xFFF5A623),
        () => context.push('/orders'),
      ),
    ];
    return Row(
      children: stats.map((s) {
        final card = Container(
          margin: EdgeInsets.only(right: s == stats.last ? 0 : 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: AppColors.cardShadow,
                  blurRadius: 6,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(s.$3, color: s.$4, size: 22),
              const SizedBox(height: 8),
              Text(s.$2,
                  style: AppTextStyles.displayMedium
                      .copyWith(color: s.$4, fontSize: 22)),
              Text(
                s.$1,
                style: AppTextStyles.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'tap to view',
                style: AppTextStyles.bodySmall
                    .copyWith(color: s.$4, fontSize: 10),
              ),
            ],
          ),
        );
        return Expanded(
          child: GestureDetector(
            onTap: s.$5,
            behavior: HitTestBehavior.opaque,
            child: card,
          ),
        );
      }).toList(),
    );
  }

  void _showTailorsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.content_cut_rounded,
                      color: Color(0xFF4CAF50), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Enrolled Tailors',
                      style: AppTextStyles.headlineMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '$_tailorCount total',
                    style: AppTextStyles.bodySmall,
                    maxLines: 1,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_tailorCount == 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('No tailors enrolled yet.',
                        style: AppTextStyles.bodyMedium),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _tailorCount,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final pc = _tailorProfiles.length;
                    final po = _tailorOrphanPhones.length;
                    if (i < pc) {
                      final p = _tailorProfiles[i];
                      final fn = (p['firstName'] as String? ?? '').trim();
                      final ln = (p['lastName'] as String? ?? '').trim();
                      final displayName = '$fn $ln'.trim();
                      final mob = p['mobile'] as String? ?? '';
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor:
                              const Color(0xFF4CAF50).withValues(alpha: 0.15),
                          child: const Icon(Icons.person_rounded,
                              color: Color(0xFF4CAF50), size: 20),
                        ),
                        title: Text(
                          displayName.isEmpty ? 'Tailor' : displayName,
                          style: AppTextStyles.titleMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          mob,
                          style:
                              AppTextStyles.bodySmall.copyWith(fontSize: 12),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle_outline_rounded,
                              color: Colors.red, size: 22),
                          tooltip: 'Remove tailor',
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);

                            await AppState.instance.removeTailorPhone(mob);
                            await _loadTailors();

                            if (!mounted) return;

                            setSheetState(() {});
                            setState(() {});

                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Tailor removed'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          },
                        ),
                      );
                    }
                    if (i < pc + po) {
                      final phone = _tailorOrphanPhones[i - pc];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor:
                              const Color(0xFF4CAF50).withValues(alpha: 0.15),
                          child: const Icon(Icons.phone_rounded,
                              color: Color(0xFF4CAF50), size: 20),
                        ),
                        title: Text('Tailor',
                            style: AppTextStyles.titleMedium),
                        subtitle: Text(
                          phone,
                          style:
                              AppTextStyles.bodySmall.copyWith(fontSize: 12),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle_outline_rounded,
                              color: Colors.red, size: 22),
                          tooltip: 'Remove tailor',
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);

                            await AppState.instance.removeTailorPhone(phone);
                            await _loadTailors();

                            if (!mounted) return;

                            setSheetState(() {});
                            setState(() {});

                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Tailor removed'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          },
                        ),
                      );
                    }
                    final email = _tailorOrphanEmails[i - pc - po];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor:
                            const Color(0xFF4CAF50).withValues(alpha: 0.15),
                        child: const Icon(Icons.history_rounded,
                            color: Color(0xFF4CAF50), size: 20),
                      ),
                      title: Text('Tailor (legacy)',
                          style: AppTextStyles.titleMedium),
                      subtitle: Text(
                        'Re-enroll with name & mobile',
                        style:
                            AppTextStyles.bodySmall.copyWith(fontSize: 11),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle_outline_rounded,
                            color: Colors.red, size: 22),
                        tooltip: 'Remove tailor',
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);

                          await AppState.instance.removeTailor(email);
                          await _loadTailors();

                          if (!mounted) return;

                          setSheetState(() {});
                          setState(() {});

                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Tailor removed'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.person_add_rounded),
                  label: const Text('Enroll New Tailor'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showEnrollTailorDialog(context);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionGrid(BuildContext context) {
    final actions = [
      (
        'Dress designs',
        Icons.checkroom_outlined,
        const Color(0xFFE91E63),
        () => context.push('/owner/designs'),
      ),
      (
        'Manage Rates',
        Icons.payments_rounded,
        AppColors.primary,
        () => context.push('/owner/rates'),
      ),
      (
        'Payments & payouts',
        Icons.account_balance_wallet_outlined,
        const Color(0xFF795548),
        () => context.push('/owner/payouts'),
      ),
      (
        'All Orders',
        Icons.receipt_long_rounded,
        const Color(0xFF4CAF50),
        () => context.push('/orders'),
      ),
      (
        'Add Fashion Partner',
        Icons.person_add_rounded,
        const Color(0xFF2196F3),
        () => _showEnrollTailorDialog(context),
      ),
      (
        'Delivery Partners',
        Icons.delivery_dining_rounded,
        const Color(0xFF00BCD4),
        () => _showDeliveryPartnersSheet(context),
      ),
      (
        'Delivery Settings',
        Icons.tune_rounded,
        const Color(0xFF9C27B0),
        () => _showDeliverySettingsDialog(context),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        // Taller cells: two-line labels (e.g. "Delivery Partners") were ~18px over limit at 1.6.
        childAspectRatio: 1.32,
      ),
      itemCount: actions.length,
      itemBuilder: (ctx, i) {
        final a = actions[i];
        return GestureDetector(
          onTap: a.$4,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: a.$3.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: a.$3.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(a.$2, color: a.$3, size: 26),
                const SizedBox(height: 6),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      a.$1,
                      style: AppTextStyles.titleMedium.copyWith(
                        color: a.$3,
                        fontSize: 13,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecentOrders() {
    if (_loadingOrders) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_recentOrders.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Center(
          child: Text('No orders yet', style: AppTextStyles.bodyMedium),
        ),
      );
    }

    return Column(
      children: _recentOrders.map((o) {
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
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: o.status.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.checkroom_rounded,
                    color: o.status.color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(o.dressType, style: AppTextStyles.titleMedium),
                    if (o.tailorName.isNotEmpty)
                      Text(o.tailorName, style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: o.status.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  o.status.label,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: o.status.color, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  void _showEnrollTailorDialog(BuildContext context) {
    final firstCtrl = TextEditingController();
    final lastCtrl = TextEditingController();
    final mobileCtrl = TextEditingController();
    final loginEmailCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enroll Tailor'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'First name, last name and mobile are required. '
                  'Optional Google sign-in email is stored for access only — it is not shown in the tailor list.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: firstCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'First name',
                    border: OutlineInputBorder(),
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: lastCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Last name',
                    border: OutlineInputBorder(),
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: mobileCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Mobile number',
                    hintText: '+91… or local digits',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone_rounded),
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (AppState.normalizePhoneE164(v.trim()) == null) {
                      return 'Enter a valid number with country code if needed';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: loginEmailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Google sign-in email (optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email_outlined),
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                  ),
                  validator: (v) {
                    final t = v?.trim() ?? '';
                    if (t.isEmpty) return null;
                    if (!t.contains('@')) return 'Invalid email';
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
              final login = loginEmailCtrl.text.trim();
              await AppState.instance.enrollTailorWithProfile(
                firstName: firstCtrl.text,
                lastName: lastCtrl.text,
                phoneRaw: mobileCtrl.text.trim(),
                loginEmail: login.isEmpty ? null : login,
              );
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              await _loadTailors();
              if (!context.mounted) return;
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Tailor enrolled'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            child: const Text('Enroll'),
          ),
        ],
      ),
    ).then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        firstCtrl.dispose();
        lastCtrl.dispose();
        mobileCtrl.dispose();
        loginEmailCtrl.dispose();
      });
    });
  }

  // ── Delivery Partners Sheet ──────────────────────────────────────────────
  List<String> _deliveryEmails = [];

  Future<void> _loadDeliveryPartners() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('config').doc('admin').get();
      final emails = List<String>.from(doc.data()?['deliveryEmails'] ?? []);
      if (mounted) setState(() => _deliveryEmails = emails);
    } catch (_) {}
  }

  void _showDeliveryPartnersSheet(BuildContext context) {
    _loadDeliveryPartners().then((_) {
      if (!mounted || !context.mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setSheetState) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.delivery_dining_rounded,
                        color: Color(0xFF00BCD4), size: 22),
                    const SizedBox(width: 10),
                    Text('Delivery Partners', style: AppTextStyles.headlineMedium),
                    const Spacer(),
                    Text('${_deliveryEmails.length} enrolled',
                        style: AppTextStyles.bodySmall),
                  ],
                ),
                const SizedBox(height: 16),
                if (_deliveryEmails.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('No delivery partners enrolled yet.',
                          style: AppTextStyles.bodyMedium),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _deliveryEmails.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final email = _deliveryEmails[i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor:
                              const Color(0xFF00BCD4).withValues(alpha: 0.15),
                          child: const Icon(Icons.delivery_dining_rounded,
                              color: Color(0xFF00BCD4), size: 20),
                        ),
                        title: Text(email, style: AppTextStyles.titleMedium),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle_outline_rounded,
                              color: Colors.red, size: 22),
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);

                            await AppState.instance.removeDeliveryPartner(email);

                            if (!mounted) return;

                            setSheetState(() => _deliveryEmails.remove(email));
                            setState(() {});

                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('$email removed'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.person_add_rounded),
                    label: const Text('Enroll Delivery Partner'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00BCD4)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showEnrollDeliveryDialog(context);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  void _showEnrollDeliveryDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enroll Delivery Partner'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the delivery partner\'s email (must match the email on their account / profile if they use email-based routing).\nThey get Delivery access when this email is in config.\nA 30-day subscription will be activated.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Partner\'s Email',
                hintText: 'partner@gmail.com',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = controller.text.trim();
              if (email.isEmpty || !email.contains('@')) return;

              final messenger = ScaffoldMessenger.of(context);

              Navigator.pop(ctx);

              await AppState.instance.enrollDeliveryPartner(email);
              await _loadDeliveryPartners();

              if (!mounted) return;

              messenger.showSnackBar(
                SnackBar(
                  content: Text('$email enrolled as Delivery Partner'),
                  backgroundColor: const Color(0xFF00BCD4),
                ),
              );
            },
            child: const Text('Enroll'),
          ),
        ],
      ),
    ).then((_) => WidgetsBinding.instance
        .addPostFrameCallback((_) => controller.dispose()));
  }

  // ── Delivery Settings Dialog ─────────────────────────────────────────────
  void _showDeliverySettingsDialog(BuildContext context) async {
    final settings = await AppState.instance.getDeliverySettings();
    if (!mounted || !context.mounted) return;
    final feeCtrl = TextEditingController(
        text: settings['feePerOrder']!.toStringAsFixed(0));
    final subCtrl = TextEditingController(
        text: settings['subscriptionFee']!.toStringAsFixed(0));
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delivery Settings'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Fee paid to delivery partner per order:',
                  style: TextStyle(fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: feeCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Per delivery fee',
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  prefixText: '₹ ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Monthly subscription fee charged to partner:',
                  style: TextStyle(fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: subCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Monthly subscription',
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  prefixText: '₹ ',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final fee = double.tryParse(feeCtrl.text.trim()) ?? 50;
              final sub = double.tryParse(subCtrl.text.trim()) ?? 500;
              Navigator.pop(ctx);
              await AppState.instance.saveDeliverySettings(
                feePerOrder: fee,
                subscriptionFee: sub,
              );
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Delivery settings saved'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      feeCtrl.dispose();
      subCtrl.dispose();
    });
  }
}
