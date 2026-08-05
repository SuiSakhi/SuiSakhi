import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_state.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/dress.dart';
import '../../models/payment_models.dart';
import '../../models/user_profile.dart';
import '../../services/claude_smart_assistant_service.dart';

class TailorDashboardScreen extends StatefulWidget {
  const TailorDashboardScreen({super.key});

  @override
  State<TailorDashboardScreen> createState() => _TailorDashboardScreenState();
}

class _TailorDashboardScreenState extends State<TailorDashboardScreen> {
  int _tab = 0; // 0 = Orders, 1 = Rates
  List<DressOrder> _orders = [];
  bool _loadingOrders = true;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('orders')
          .where('status', whereNotIn: ['delivered', 'cancelled'])
          .get();
      if (mounted) {
        setState(() {
          _orders = snap.docs
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
            _buildTabBar(),
            Expanded(
              child: _tab == 0 ? _buildOrdersList() : _buildRatesList(),
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
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
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
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.content_cut_rounded,
                    color: Color(0xFF4CAF50), size: 15),
                const SizedBox(width: 6),
                Text('Tailor',
                    style: AppTextStyles.labelMedium
                        .copyWith(color: const Color(0xFF4CAF50))),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () {
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
    final lastName =
        parts.length > 1 ? parts.sublist(1).join(' ') : '—';
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
                AppState.instance.setProfile(UserProfile(
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
                ));
              } else {
                AppState.instance.setProfile(UserProfile(
                  name: fullName.isEmpty ? 'Tailor' : fullName,
                  role: UserRole.tailor,
                  email: em.isEmpty ? null : em,
                ));
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
      WidgetsBinding.instance
          .addPostFrameCallback((_) => emailCtrl.dispose());
    });
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          _TabBtn(
              label: 'My Orders',
              selected: _tab == 0,
              onTap: () => setState(() => _tab = 0)),
          const SizedBox(width: 10),
          _TabBtn(
              label: 'Rate Card',
              selected: _tab == 1,
              onTap: () => setState(() => _tab = 1)),
        ],
      ),
    );
  }

  Widget _buildOrdersList() {
    if (_loadingOrders) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox_outlined, size: 64, color: AppColors.textHint),
            const SizedBox(height: 16),
            Text('No active orders', style: AppTextStyles.headlineMedium),
            const SizedBox(height: 8),
            Text('Orders placed by customers will appear here',
                style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Active Orders (${_orders.length})',
            style: AppTextStyles.headlineMedium),
        const SizedBox(height: 16),
        ..._orders.map((o) => _OrderCard(
              order: o,
              onStatusUpdate: () => _updateStatus(o),
              onAiChecklist: () => _showTailorAiChecklist(context, o),
            )),
      ],
    );
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Advance to “${next.label}”?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirm')),
        ],
      ),
    );
    if (confirmed == true) {
      await AppState.instance.updateOrderStatus(order.id, next.name);
      _loadOrders();
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
            Text('Current Stitching Rates',
                style: AppTextStyles.headlineMedium),
            const SizedBox(height: 4),
            Text('Set by shop owner — for your reference',
                style: AppTextStyles.bodySmall),
            const SizedBox(height: 16),
            ...rates.map(
              (r) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
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
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.checkroom_rounded,
                          color: AppColors.primary, size: 18),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.dressType,
                              style: AppTextStyles.titleMedium),
                          if (r.notes != null && r.notes!.isNotEmpty)
                            Text(r.notes!,
                                style: AppTextStyles.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    Text(
                      '₹${r.basePrice.toStringAsFixed(0)}',
                      style: AppTextStyles.headlineMedium
                          .copyWith(color: AppColors.primary),
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
    final useDeva = _lang == TailorChecklistLanguage.hindi ||
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
      h2: body.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        height: 1.3,
      ),
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
                  Icon(Icons.auto_awesome_rounded,
                      color: AppColors.primary, size: 26),
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
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
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
  const _TabBtn(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.divider),
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
  final VoidCallback onAiChecklist;

  const _OrderCard({
    required this.order,
    required this.onStatusUpdate,
    required this.onAiChecklist,
  });

  String get _nextActionLabel {
    final n = order.status.nextForTailor;
    if (n == null) return '';
    return 'Next: ${n.label}';
  }

  @override
  Widget build(BuildContext context) {
    final canUpdate = order.status.nextForTailor != null;
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: order.status.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.checkroom_rounded,
                    color: order.status.color, size: 22),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
          if (order.deliveryAddress != null &&
              order.deliveryAddress!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on_rounded,
                    size: 14, color: AppColors.textHint),
                const SizedBox(width: 4),
                Expanded(
                    child: Text(order.deliveryAddress!,
                        style: AppTextStyles.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis)),
              ],
            ),
          ],
          if (order.payoutLedger != null) ...[
            const SizedBox(height: 10),
            _TailorPayoutBanner(ledger: order.payoutLedger!),
          ],
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onAiChecklist,
              icon: const Icon(Icons.auto_awesome_outlined, size: 18),
              label: const Text('AI stitching checklist'),
            ),
          ),
          if (canUpdate) ...[
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
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                child: Text(_nextActionLabel,
                    style: AppTextStyles.labelMedium
                        .copyWith(color: Colors.white)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
