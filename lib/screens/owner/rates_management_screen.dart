import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_state.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/stitching_rate.dart';
import '../../services/stitching_pricing_service.dart';
import '../../widgets/common/pricing_input_decoration.dart';

class RatesManagementScreen extends StatefulWidget {
  const RatesManagementScreen({super.key});

  @override
  State<RatesManagementScreen> createState() => _RatesManagementScreenState();
}

class _RatesManagementScreenState extends State<RatesManagementScreen> {
  final _platform = TextEditingController(text: '15');
  final _delivery = TextEditingController(text: '0');
  final _measurement = TextEditingController(text: '0');
  final _other = TextEditingController(text: '0');
  final _tax = TextEditingController(text: '6');
  final Map<String, TextEditingController> _partner = {};
  final Map<String, TextEditingController> _customer = {};
  final Set<String> _manualCustomerPrices = {};
  bool _loading = true;
  bool _saving = false;
  bool _hydrating = false;
  String? _loadError;
  String? _version;

  @override
  void initState() {
    super.initState();
    _platform.addListener(_recalculateAll);
    _delivery.addListener(_recalculateAll);
    _measurement.addListener(_recalculateAll);
    _other.addListener(_recalculateAll);
    _tax.addListener(_recalculateAll);
    unawaited(_load());
  }

  @override
  void dispose() {
    _platform.dispose();
    _delivery.dispose();
    _measurement.dispose();
    _other.dispose();
    _tax.dispose();
    for (final controller in _partner.values) {
      controller.dispose();
    }
    for (final controller in _customer.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      await AppState.instance.loadRates();
      final policy = await StitchingPricingService.loadPolicy();
      _hydrating = true;
      _platform.text = _format(
        (policy['platformPercent'] as num?)?.toDouble() ?? 15,
      );
      _delivery.text = _format(
        (policy['deliveryFee'] as num?)?.toDouble() ?? 0,
      );
      _measurement.text = _format(
        (policy['measurementFee'] as num?)?.toDouble() ?? 0,
      );
      _other.text = _format((policy['otherFee'] as num?)?.toDouble() ?? 0);
      _tax.text = _format((policy['taxPercent'] as num?)?.toDouble() ?? 6);
      _version = policy['versionId']?.toString();
      _manualCustomerPrices.clear();
      for (final controller in _partner.values) {
        controller.dispose();
      }
      for (final controller in _customer.values) {
        controller.dispose();
      }
      _partner.clear();
      _customer.clear();
      for (final rate in AppState.instance.rates) {
        _partner[rate.dressType] = TextEditingController(
          text: _format(rate.basePrice),
        );
        final initialCustomer = rate.customerPriceOverride
            ? (rate.customerPrice ?? _calculate(rate.basePrice))
            : _calculate(rate.basePrice);
        _customer[rate.dressType] = TextEditingController(
          text: _format(initialCustomer),
        );
        if (rate.customerPriceOverride) {
          _manualCustomerPrices.add(rate.dressType);
        }
      }
      _hydrating = false;
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = null;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Could not load stitching rates. Please retry.';
      });
    }
  }

  double _number(TextEditingController controller, double fallback) =>
      double.tryParse(controller.text.trim().replaceAll(',', '.')) ?? fallback;

  double _calculate(double partnerRate) =>
      StitchingPricingService.customerPrice(
        partnerRate: partnerRate,
        platformPercent: _number(_platform, 15),
        deliveryFee: _number(_delivery, 0),
        measurementFee: _number(_measurement, 0),
        otherFee: _number(_other, 0),
        taxPercent: _number(_tax, 6),
      );

  String _format(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);

  void _recalculateAll() {
    if (_hydrating) return;
    for (final name in _partner.keys) {
      _recalculate(name);
    }
  }

  void _recalculate(String name) {
    if (_hydrating || _manualCustomerPrices.contains(name)) return;
    final partner = double.tryParse(_partner[name]?.text.trim() ?? '');
    if (partner == null) return;
    final next = _format(_calculate(partner));
    if (_customer[name]?.text == next) return;
    _hydrating = true;
    _customer[name]?.text = next;
    _hydrating = false;
  }

  Future<void> _publish() async {
    if (_saving) return;
    final platform = double.tryParse(_platform.text.trim());
    final delivery = double.tryParse(_delivery.text.trim());
    final measurement = double.tryParse(_measurement.text.trim());
    final other = double.tryParse(_other.text.trim());
    final tax = double.tryParse(_tax.text.trim());
    if (platform == null ||
        delivery == null ||
        measurement == null ||
        other == null ||
        tax == null) {
      _message(
        'Enter valid percentages (0–100) and non-negative delivery, measurement and other fees.',
      );
      return;
    }
    if (platform < 0 ||
        platform > 100 ||
        delivery < 0 ||
        measurement < 0 ||
        other < 0 ||
        tax < 0 ||
        tax > 100) {
      _message(
        'Enter valid percentages (0–100) and non-negative delivery, measurement and other fees.',
      );
      return;
    }

    final rates = <StitchingRate>[];
    for (final existing in AppState.instance.rates) {
      final partner = double.tryParse(
        _partner[existing.dressType]?.text.trim() ?? '',
      );
      final customer = double.tryParse(
        _customer[existing.dressType]?.text.trim() ?? '',
      );
      if (partner == null ||
          customer == null ||
          partner < 0 ||
          customer < partner) {
        _message(
          'Check the partner and customer prices for ${existing.dressType}.',
        );
        return;
      }
      rates.add(
        StitchingRate(
          dressType: existing.dressType,
          basePrice: partner,
          customerPrice: customer,
          customerPriceOverride: _manualCustomerPrices.contains(
            existing.dressType,
          ),
          notes: existing.notes,
        ),
      );
    }

    setState(() => _saving = true);
    try {
      await StitchingPricingService.publish(
        rates: rates,
        platformPercent: platform,
        deliveryFee: delivery,
        measurementFee: measurement,
        otherFee: other,
        taxPercent: tax,
      );
      await AppState.instance.loadRates();
      if (!mounted) return;
      setState(() {
        _saving = false;
        _version = DateTime.now().microsecondsSinceEpoch.toString();
      });
      _message('Stitching pricing published. Customer rates are now active.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _message('Could not publish stitching pricing. Please retry.');
    }
  }

  Future<void> _addRate() async {
    final name = TextEditingController();
    final partner = TextEditingController();
    final notes = TextEditingController();
    final result = await showDialog<(String, double, String?)>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add stitching rate'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Dress type'),
            ),
            TextField(
              controller: partner,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Partner rate (₹)'),
            ),
            TextField(
              controller: notes,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = double.tryParse(partner.text.trim());
              if (name.text.trim().isEmpty || parsed == null || parsed < 0) {
                return;
              }
              Navigator.pop(dialogContext, (
                name.text.trim(),
                parsed,
                notes.text.trim().isEmpty ? null : notes.text.trim(),
              ));
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    name.dispose();
    partner.dispose();
    notes.dispose();
    if (result == null) return;
    final customer = _calculate(result.$2);
    await AppState.instance.updateRate(
      result.$1,
      result.$2,
      customerPrice: customer,
      notes: result.$3,
    );
    if (!mounted) return;
    setState(() {
      _partner[result.$1] = TextEditingController(text: _format(result.$2));
      _customer[result.$1] = TextEditingController(text: _format(customer));
    });
  }

  Future<void> _deleteRate(String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete "$name"?'),
        content: const Text(
          'This removes the rate from the active stitching list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await AppState.instance.deleteRate(name);
    _partner.remove(name)?.dispose();
    _customer.remove(name)?.dispose();
    _manualCustomerPrices.remove(name);
    if (mounted) setState(() {});
  }

  void _message(String value) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(value)));

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: const Text(
        'Stitching Rates Pricing',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded),
        onPressed: () => context.pop(),
      ),
      actions: [
        IconButton(
          tooltip: 'Add rate',
          icon: const Icon(Icons.add_rounded),
          onPressed: _loading ? null : _addRate,
        ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
            children: [
              if (_loadError != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(_loadError!),
                  ),
                ),
              _infoCard(),
              if (_version != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Text(
                    'Active pricing version: $_version',
                    style: AppTextStyles.bodySmall,
                  ),
                ),
              const SizedBox(height: 8),
              _feeCard(),
              const SizedBox(height: 6),
              for (final rate in AppState.instance.rates) _rateCard(rate),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _saving ? null : _publish,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.publish_rounded),
                label: Text(_saving ? 'Publishing…' : 'Publish rate card'),
              ),
            ],
          ),
  );

  Widget _infoCard() => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: AppColors.primary.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
    ),
    child: const Text(
      'Partner rates are shared with Tailors. Customer rates are calculated from the fee policy and can be edited before publishing.',
      style: TextStyle(fontSize: 13),
    ),
  );

  Widget _feeCard() => Card(
    color: AppColors.surface,
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Customer fee policy', style: AppTextStyles.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Customer price = partner rate + platform fee + tax + fixed delivery, measurement and other fees. Percentages apply to the partner rate; fixed fees are added as entered.',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _setting(_platform, 'Platform %'),
              _setting(_delivery, 'Delivery ₹'),
              _setting(_measurement, 'Measurement ₹'),
              _setting(_other, 'Other fee ₹'),
              _setting(_tax, 'Taxes %'),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _setting(TextEditingController controller, String label) => SizedBox(
    width: 132,
    child: TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: pricingInputDecoration(
        labelText: label,
        verticalPadding: 6,
        compact: true,
      ),
      style: const TextStyle(fontSize: 13),
    ),
  );

  Widget _rateCard(StitchingRate rate) => Card(
    color: AppColors.surface,
    margin: const EdgeInsets.only(bottom: 5),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 6, 8),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.checkroom_rounded, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(rate.dressType, style: AppTextStyles.headlineSmall),
              ),
              PopupMenuButton<String>(
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                onSelected: (value) {
                  if (value == 'delete') unawaited(_deleteRate(rate.dressType));
                  if (value == 'notes') unawaited(_editNotes(rate));
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'notes', child: Text('Edit notes')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
          if (rate.notes?.isNotEmpty == true)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(rate.notes!, style: AppTextStyles.bodySmall),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: _rateInput(_partner[rate.dressType]!, 'Partner ₹'),
              ),
              const SizedBox(width: 8),
              Expanded(child: _customerInput(rate.dressType)),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _rateInput(TextEditingController controller, String label) =>
      TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: pricingInputDecoration(
          labelText: label,
          prefixText: '₹ ',
          verticalPadding: 6,
          compact: true,
        ),
        style: const TextStyle(fontSize: 13),
        onChanged: (_) => _recalculateAll(),
      );

  Widget _customerInput(String name) => TextField(
    controller: _customer[name],
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: pricingInputDecoration(
      labelText:
          'Customer ₹${_manualCustomerPrices.contains(name) ? ' · edited' : ''}',
      prefixText: '₹ ',
      verticalPadding: 6,
      compact: true,
    ),
    style: const TextStyle(fontSize: 13),
    onChanged: (value) {
      if (_hydrating) return;
      final partner = double.tryParse(_partner[name]?.text.trim() ?? '');
      final customer = double.tryParse(value.trim());
      if (partner == null || customer == null) return;
      if ((customer - _calculate(partner)).abs() < 0.01) {
        _manualCustomerPrices.remove(name);
      } else {
        _manualCustomerPrices.add(name);
      }
      setState(() {});
    },
  );

  Future<void> _editNotes(StitchingRate rate) async {
    final notes = TextEditingController(text: rate.notes ?? '');
    final value = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${rate.dressType} notes'),
        content: TextField(
          controller: notes,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Notes (optional)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, notes.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    notes.dispose();
    if (value == null) return;
    await AppState.instance.updateRate(
      rate.dressType,
      double.tryParse(_partner[rate.dressType]?.text ?? '') ?? rate.basePrice,
      customerPrice:
          double.tryParse(_customer[rate.dressType]?.text ?? '') ??
          rate.customerPrice,
      customerPriceOverride: _manualCustomerPrices.contains(rate.dressType),
      notes: value.isEmpty ? null : value,
    );
    if (mounted) setState(() {});
  }
}
