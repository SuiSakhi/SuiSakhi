import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/payment_models.dart';
import '../../services/payout_config_service.dart';
import '../../widgets/common/custom_button.dart';

/// Owner: split percents (of customer **advance**), UPI ids for ledger display,
/// sandbox toggle, optional Razorpay publishable key for future live checkout.
class OwnerPayoutSettingsScreen extends StatefulWidget {
  const OwnerPayoutSettingsScreen({super.key});

  @override
  State<OwnerPayoutSettingsScreen> createState() =>
      _OwnerPayoutSettingsScreenState();
}

class _OwnerPayoutSettingsScreenState extends State<OwnerPayoutSettingsScreen> {
  final _ownerPct = TextEditingController();
  final _tailorPct = TextEditingController();
  final _deliveryPct = TextEditingController();
  final _platformPct = TextEditingController();
  final _ownerUpi = TextEditingController();
  final _tailorUpi = TextEditingController();
  final _deliveryUpi = TextEditingController();
  final _rzpKey = TextEditingController();
  bool _sandbox = true;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ownerPct.dispose();
    _tailorPct.dispose();
    _deliveryPct.dispose();
    _platformPct.dispose();
    _ownerUpi.dispose();
    _tailorUpi.dispose();
    _deliveryUpi.dispose();
    _rzpKey.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final c = await PayoutConfigService.fetch();
    if (!mounted) return;
    _ownerPct.text = c.ownerPercent.toStringAsFixed(0);
    _tailorPct.text = c.tailorPercent.toStringAsFixed(0);
    _deliveryPct.text = c.deliveryPercent.toStringAsFixed(0);
    _platformPct.text = c.platformPercent.toStringAsFixed(0);
    _ownerUpi.text = c.ownerUpiId;
    _tailorUpi.text = c.tailorUpiId;
    _deliveryUpi.text = c.deliveryUpiId;
    _rzpKey.text = c.razorpayKeyId ?? '';
    setState(() {
      _sandbox = c.sandboxMode;
      _loading = false;
    });
  }

  Future<void> _save() async {
    double p(TextEditingController t) =>
        double.tryParse(t.text.trim().replaceAll(',', '.')) ?? 0;
    final o = p(_ownerPct);
    final t = p(_tailorPct);
    final d = p(_deliveryPct);
    final pl = p(_platformPct);
    final sum = o + t + d + pl;
    if ((sum - 100).abs() > 0.5) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Percents should add up to 100 (currently ${sum.toStringAsFixed(1)}).',
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    final cfg = ShopPayoutConfig(
      ownerPercent: o,
      tailorPercent: t,
      deliveryPercent: d,
      platformPercent: pl,
      sandboxMode: _sandbox,
      razorpayKeyId: _rzpKey.text.trim().isEmpty ? null : _rzpKey.text.trim(),
      ownerUpiId: _ownerUpi.text.trim(),
      tailorUpiId: _tailorUpi.text.trim(),
      deliveryUpiId: _deliveryUpi.text.trim(),
    );
    try {
      await PayoutConfigService.save(cfg);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payments settings saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Payments & payouts'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'When a customer pays the order advance online, shares below '
                    'are recorded on the order (test mode settles instantly in-app). '
                    'Real bank/UPI settlement needs your payment provider dashboard.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textHint,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Test (dummy) payments'),
                    subtitle: const Text(
                      'Customers complete checkout without a live gateway. Turn off '
                      'only after Razorpay (or similar) is deployed on a server.',
                    ),
                    value: _sandbox,
                    activeThumbColor: AppColors.primary,
                    onChanged: (v) => setState(() => _sandbox = v),
                  ),
                  const SizedBox(height: 16),
                  Text('Split of advance %', style: AppTextStyles.titleMedium),
                  const SizedBox(height: 8),
                  _pctRow('Owner', _ownerPct),
                  _pctRow('Tailor', _tailorPct),
                  _pctRow('Delivery', _deliveryPct),
                  _pctRow('Platform', _platformPct),
                  const SizedBox(height: 20),
                  Text('UPI ids (for payout records)',
                      style: AppTextStyles.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Shown on each order’s ledger. Tailors/delivery can also save '
                    'UPI under Profile for their own reference.',
                    style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textHint),
                  ),
                  const SizedBox(height: 12),
                  _upiField('Owner UPI', _ownerUpi),
                  _upiField('Tailor UPI', _tailorUpi),
                  _upiField('Delivery UPI', _deliveryUpi),
                  const SizedBox(height: 20),
                  Text('Live gateway (optional)',
                      style: AppTextStyles.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Razorpay Key Id (publishable) for a future native checkout. '
                    'The secret key must live only in Cloud Functions, not in the app.',
                    style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textHint, height: 1.4),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _rzpKey,
                    decoration: const InputDecoration(
                      labelText: 'Razorpay Key Id',
                      hintText: 'rzp_test_...',
                      border: OutlineInputBorder(),
                    ),
                    autocorrect: false,
                  ),
                  const SizedBox(height: 28),
                  PrimaryButton(
                    label: _saving ? 'Saving…' : 'Save',
                    onTap: _saving ? () {} : _save,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _pctRow(String label, TextEditingController c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          suffixText: '%',
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _upiField(String label, TextEditingController c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        decoration: InputDecoration(
          labelText: label,
          hintText: 'name@upi',
          border: const OutlineInputBorder(),
        ),
        autocorrect: false,
      ),
    );
  }
}
