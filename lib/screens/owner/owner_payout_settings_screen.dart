import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/payment_models.dart';
import '../../services/payout_config_service.dart';
import '../../widgets/common/custom_button.dart';
import 'owner_partner_payouts_section.dart';

/// Owner payment settings and Partner payout tracking.
class OwnerPayoutSettingsScreen extends StatefulWidget {
  const OwnerPayoutSettingsScreen({super.key});

  @override
  State<OwnerPayoutSettingsScreen> createState() =>
      _OwnerPayoutSettingsScreenState();
}

class _OwnerPayoutSettingsScreenState extends State<OwnerPayoutSettingsScreen> {
  final _ownerUpi = TextEditingController();
  final _tailorUpi = TextEditingController();
  final _deliveryUpi = TextEditingController();
  final _rzpKey = TextEditingController();
  final _joiningDeposit = TextEditingController();
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
    _ownerUpi.dispose();
    _tailorUpi.dispose();
    _deliveryUpi.dispose();
    _rzpKey.dispose();
    _joiningDeposit.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final c = await PayoutConfigService.fetch();
    if (!mounted) return;
    _ownerUpi.text = c.ownerUpiId;
    _tailorUpi.text = c.tailorUpiId;
    _deliveryUpi.text = c.deliveryUpiId;
    _rzpKey.text = c.razorpayKeyId ?? '';
    _joiningDeposit.text = c.partnerJoiningSecurityDeposit.toStringAsFixed(2);
    setState(() {
      _sandbox = c.sandboxMode;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final joiningDeposit = double.tryParse(_joiningDeposit.text.trim());
    if (joiningDeposit == null ||
        !joiningDeposit.isFinite ||
        joiningDeposit < 0 ||
        joiningDeposit > 100000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a joining deposit from ₹0 to ₹1,00,000.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    final cfg = ShopPayoutConfig(
      sandboxMode: _sandbox,
      razorpayKeyId: _rzpKey.text.trim().isEmpty ? null : _rzpKey.text.trim(),
      ownerUpiId: _ownerUpi.text.trim(),
      tailorUpiId: _tailorUpi.text.trim(),
      deliveryUpiId: _deliveryUpi.text.trim(),
      partnerJoiningSecurityDeposit: joiningDeposit,
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
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
                    'Partner payouts use the Partner rate from the applicable '
                    'price list. Record the full payable after work is complete; '
                    'any deductions must include a reason and are shown in the payout record.',
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
                  const SizedBox(height: 20),
                  Text(
                    'UPI ids (for payout records)',
                    style: AppTextStyles.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Reference UPI details for external settlements. Partner '
                    'payouts are recorded from the Partner rate, with any approved deductions itemized.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textHint,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _upiField('Owner UPI', _ownerUpi),
                  _upiField('Tailor UPI', _tailorUpi),
                  _upiField('Delivery UPI', _deliveryUpi),
                  const SizedBox(height: 12),
                  Text('Partner onboarding', style: AppTextStyles.titleMedium),
                  const SizedBox(height: 6),
                  Text(
                    'Optional one-time refundable joining security deposit. '
                    'Applicants see the amount and accept the terms before '
                    'submitting. Set 0 to keep onboarding free. This setting '
                    'does not collect or refund the amount; those payments '
                    'are not automated in the current build.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textHint,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _joiningDeposit,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Refundable joining deposit (₹)',
                      hintText: '0',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Live gateway (optional)',
                    style: AppTextStyles.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Razorpay Key Id (publishable) for a future native checkout. '
                    'The secret key must live only in Cloud Functions, not in the app.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textHint,
                      height: 1.4,
                    ),
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
                  const OwnerPartnerPayoutsSection(),
                ],
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
