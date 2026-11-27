import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/prd_catalog.dart';
import '../../services/quick_care_pricing_service.dart';
import '../../widgets/common/pricing_input_decoration.dart';

class QuickCarePricingScreen extends StatefulWidget {
  const QuickCarePricingScreen({super.key});

  @override
  State<QuickCarePricingScreen> createState() => _QuickCarePricingScreenState();
}

class _QuickCarePricingScreenState extends State<QuickCarePricingScreen> {
  final _platform = TextEditingController(text: '15');
  final _tax = TextEditingController(text: '6');
  final _homePartner = TextEditingController(text: '49');
  final _homeCustomer = TextEditingController(text: '59.29');
  final _expressPartner = TextEditingController(text: '99');
  final _expressCustomer = TextEditingController(text: '119.79');
  final Map<String, TextEditingController> _partner = {};
  final Map<String, TextEditingController> _customer = {};
  final Set<String> _manual = {};
  bool _loading = true;
  bool _saving = false;
  bool _hydrating = false;
  bool _homeManual = false;
  bool _expressManual = false;
  String? _error;
  String? _version;

  @override
  void initState() {
    super.initState();
    _platform.addListener(_recalculateAll);
    _tax.addListener(_recalculateAll);
    unawaited(_load());
  }

  @override
  void dispose() {
    _platform.dispose();
    _tax.dispose();
    _homePartner.dispose();
    _homeCustomer.dispose();
    _expressPartner.dispose();
    _expressCustomer.dispose();
    for (final controller in _partner.values) {
      controller.dispose();
    }
    for (final controller in _customer.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _format(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);

  double _number(TextEditingController c, double fallback) =>
      double.tryParse(c.text.trim().replaceAll(',', '.')) ?? fallback;

  double _calculate(double partner) => QuickCarePricingService.customerPrice(
    partnerAmount: partner,
    platformPercent: _number(_platform, 15),
    taxPercent: _number(_tax, 6),
  );

  Future<void> _load() async {
    try {
      final pricing = await QuickCarePricingService.load();
      final rawRates = Map<String, dynamic>.from(
        pricing['serviceRates'] as Map? ?? const {},
      );
      _hydrating = true;
      _platform.text = _format(
        (pricing['platformPercent'] as num?)?.toDouble() ?? 15,
      );
      _tax.text = _format((pricing['taxPercent'] as num?)?.toDouble() ?? 6);
      _homePartner.text = _format(
        (pricing['homeVisitPartnerAmount'] as num?)?.toDouble() ?? 49,
      );
      _homeCustomer.text = _format(
        (pricing['homeVisitCustomerAmount'] as num?)?.toDouble() ??
            _calculate(49),
      );
      _expressPartner.text = _format(
        (pricing['expressPartnerAmount'] as num?)?.toDouble() ?? 99,
      );
      _expressCustomer.text = _format(
        (pricing['expressCustomerAmount'] as num?)?.toDouble() ??
            _calculate(99),
      );
      _homeManual = pricing['homeVisitCustomerPriceOverride'] == true;
      _expressManual = pricing['expressCustomerPriceOverride'] == true;
      _version = pricing['versionId']?.toString();
      _manual.clear();
      for (final service in QuickFixService.catalog) {
        final stored = Map<String, dynamic>.from(
          rawRates[service.id] as Map? ?? const {},
        );
        final partnerValue =
            (stored['partnerAmount'] as num?)?.toDouble() ??
            service.midEstimate;
        final customerValue =
            (stored['customerAmount'] as num?)?.toDouble() ??
            _calculate(partnerValue);
        _partner[service.id]?.dispose();
        _customer[service.id]?.dispose();
        _partner[service.id] = TextEditingController(
          text: _format(partnerValue),
        );
        _customer[service.id] = TextEditingController(
          text: _format(customerValue),
        );
        if (stored['customerPriceOverride'] == true) _manual.add(service.id);
      }
      _hydrating = false;
      if (mounted) {
        setState(() {
          _loading = false;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load Quick Care prices. Please retry.';
        });
      }
    }
  }

  void _recalculateAll() {
    if (_hydrating) return;
    for (final id in _partner.keys) {
      if (_manual.contains(id)) continue;
      final partner = double.tryParse(_partner[id]?.text.trim() ?? '');
      if (partner == null) continue;
      _hydrating = true;
      _customer[id]?.text = _format(_calculate(partner));
      _hydrating = false;
    }
    if (!_homeManual) _recalculateFixed(_homePartner, _homeCustomer);
    if (!_expressManual) _recalculateFixed(_expressPartner, _expressCustomer);
  }

  void _recalculateFixed(
    TextEditingController partner,
    TextEditingController customer,
  ) {
    final value = double.tryParse(partner.text.trim());
    if (value == null) return;
    _hydrating = true;
    customer.text = _format(_calculate(value));
    _hydrating = false;
  }

  Future<void> _publish() async {
    if (_saving) return;
    final platform = double.tryParse(_platform.text.trim());
    final tax = double.tryParse(_tax.text.trim());
    final homePartner = double.tryParse(_homePartner.text.trim());
    final homeCustomer = double.tryParse(_homeCustomer.text.trim());
    final expressPartner = double.tryParse(_expressPartner.text.trim());
    final expressCustomer = double.tryParse(_expressCustomer.text.trim());
    if (platform == null ||
        tax == null ||
        homePartner == null ||
        homeCustomer == null ||
        expressPartner == null ||
        expressCustomer == null) {
      _message(
        'Enter valid fee percentages and customer rates at least equal to partner rates.',
      );
      return;
    }
    if (platform < 0 ||
        platform > 100 ||
        tax < 0 ||
        tax > 100 ||
        homePartner < 0 ||
        homeCustomer < homePartner ||
        expressPartner < 0 ||
        expressCustomer < expressPartner) {
      _message(
        'Enter valid fee percentages and customer rates at least equal to partner rates.',
      );
      return;
    }

    final serviceRates = <String, dynamic>{};
    for (final service in QuickFixService.catalog) {
      final partner = double.tryParse(_partner[service.id]?.text.trim() ?? '');
      final customer = double.tryParse(
        _customer[service.id]?.text.trim() ?? '',
      );
      if (partner == null ||
          customer == null ||
          partner < 0 ||
          customer < partner) {
        _message('Check the Partner and Customer rates for ${service.title}.');
        return;
      }
      serviceRates[service.id] = {
        'partnerAmount': partner,
        'customerAmount': customer,
        'customerPriceOverride': _manual.contains(service.id),
      };
    }

    setState(() => _saving = true);
    try {
      await QuickCarePricingService.publish({
        'platformPercent': platform,
        'taxPercent': tax,
        'homeVisitPartnerAmount': homePartner,
        'homeVisitCustomerAmount': homeCustomer,
        'homeVisitCustomerPriceOverride': _homeManual,
        'expressPartnerAmount': expressPartner,
        'expressCustomerAmount': expressCustomer,
        'expressCustomerPriceOverride': _expressManual,
        'serviceRates': serviceRates,
      });
      if (!mounted) return;
      setState(() {
        _saving = false;
        _version = DateTime.now().microsecondsSinceEpoch.toString();
      });
      _message('Quick Care & Home Services pricing is active.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _message('Could not publish Quick Care pricing. Please retry.');
    }
  }

  void _message(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: const Text(
        'Quick Care & Home Services Pricing',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded),
        onPressed: () => context.pop(),
      ),
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
            children: [
              if (_error != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(_error!),
                  ),
                ),
              _policyCard(),
              if (_version != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Text(
                    'Active pricing version: $_version',
                    style: AppTextStyles.bodySmall,
                  ),
                ),
              for (final service in QuickFixService.catalog)
                _serviceCard(service),
              _fixedCard('Home visit fee', _homePartner, _homeCustomer),
              _fixedCard(
                'Express scheduling fee',
                _expressPartner,
                _expressCustomer,
              ),
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

  Widget _policyCard() => Card(
    color: AppColors.surface,
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Customer fee policy',
            style: AppTextStyles.titleMedium.copyWith(fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            'Customer price = Partner rate + Platform fee + Taxes. Both percentages apply to the Partner rate; the Customer price remains editable.',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _setting(_platform, 'Platform %'),
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
        verticalPadding: 5,
        compact: true,
      ),
      style: const TextStyle(fontSize: 13),
    ),
  );

  Widget _serviceCard(QuickFixService service) => Card(
    color: AppColors.surface,
    margin: const EdgeInsets.only(bottom: 4),
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(service.title, style: AppTextStyles.headlineSmall),
          if (service.requiresPartnerQuote)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 5),
              child: Text(
                'Partner quote after assessment',
                style: AppTextStyles.bodySmall,
              ),
            ),
          Row(
            children: [
              Expanded(
                child: _priceField(
                  _partner[service.id]!,
                  'Partner ₹',
                  onChanged: (_) => _recalculate(service.id),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _priceField(
                  _customer[service.id]!,
                  'Customer ₹',
                  onChanged: (value) => _markManual(service.id, value),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _fixedCard(
    String title,
    TextEditingController partner,
    TextEditingController customer,
  ) => Card(
    color: AppColors.surface,
    margin: const EdgeInsets.only(bottom: 4),
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.headlineSmall),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: _priceField(
                  partner,
                  'Partner ₹',
                  onChanged: (_) {
                    if ((title.startsWith('Home') && !_homeManual) ||
                        (title.startsWith('Express') && !_expressManual)) {
                      _recalculateFixed(partner, customer);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _priceField(
                  customer,
                  'Customer ₹',
                  onChanged: (value) {
                    if (_hydrating) return;
                    final parsed = double.tryParse(value.trim());
                    final partnerAmount = double.tryParse(partner.text.trim());
                    if (parsed == null || partnerAmount == null) return;
                    final isManual =
                        (parsed - _calculate(partnerAmount)).abs() >= 0.01;
                    setState(() {
                      if (title.startsWith('Home')) {
                        _homeManual = isManual;
                      } else {
                        _expressManual = isManual;
                      }
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _priceField(
    TextEditingController controller,
    String label, {
    required ValueChanged<String> onChanged,
  }) => TextField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: pricingInputDecoration(
      labelText: label,
      prefixText: '₹ ',
      verticalPadding: 5,
      compact: true,
    ),
    style: const TextStyle(fontSize: 13),
    onChanged: onChanged,
  );

  void _recalculate(String id) {
    if (_hydrating || _manual.contains(id)) return;
    final partner = double.tryParse(_partner[id]?.text.trim() ?? '');
    if (partner == null) return;
    _hydrating = true;
    _customer[id]?.text = _format(_calculate(partner));
    _hydrating = false;
  }

  void _markManual(String id, String value) {
    if (_hydrating) return;
    final partner = double.tryParse(_partner[id]?.text.trim() ?? '');
    final customer = double.tryParse(value.trim());
    if (partner == null || customer == null) return;
    if ((customer - _calculate(partner)).abs() < 0.01) {
      _manual.remove(id);
    } else {
      _manual.add(id);
    }
    setState(() {});
  }
}
