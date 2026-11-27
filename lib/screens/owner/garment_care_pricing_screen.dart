import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/garment_care_colors.dart';
import '../../core/metadata/garment_care_catalog_metadata.dart';
import '../../models/garment_care_domain.dart';
import '../../services/garment_care_service.dart';
import '../../widgets/common/pricing_input_decoration.dart';

class GarmentCarePricingScreen extends StatefulWidget {
  const GarmentCarePricingScreen({super.key});

  @override
  State<GarmentCarePricingScreen> createState() =>
      _GarmentCarePricingScreenState();
}

class _GarmentCarePricingScreenState extends State<GarmentCarePricingScreen> {
  final _commission = TextEditingController(text: '15');
  final _tax = TextEditingController(text: '6');
  final _other = TextEditingController(text: '0');
  final _logistics = TextEditingController(text: '0');
  final Map<String, TextEditingController> _customerPrices = {};
  final Map<String, TextEditingController> _partnerRates = {};
  final Map<String, TextEditingController> _itemCustomerPrices = {};
  final Map<String, TextEditingController> _itemPartnerRates = {};
  final Set<String> _manualCustomerPrices = {};
  bool _saving = false;
  bool _loading = true;
  bool _hydrating = false;
  String? _loadError;
  String? _activeVersion;

  List<String> get _serviceIds => GarmentCareServiceGroup.values
      .expand(
        (group) =>
            GarmentCareServiceCatalog.serviceIdsByGroup[group.code] ??
            const <String>[],
      )
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    for (final id in _serviceIds) {
      _customerPrices[id] = TextEditingController();
      _partnerRates[id] = TextEditingController();
      final group = GarmentCareServiceGroup.values.firstWhere(
        (candidate) =>
            (GarmentCareServiceCatalog.serviceIdsByGroup[candidate.code] ??
                    const <String>[])
                .contains(id),
      );
      for (final itemType in GarmentCareCatalogMetadata.itemTypesForGroup(
        group.code,
        serviceId: id,
      ).entries) {
        final key = _itemRateKey(id, itemType.key);
        _itemCustomerPrices[key] = TextEditingController();
        _itemPartnerRates[key] = TextEditingController();
      }
    }
    for (final key in _allRateKeys) {
      _partnerFor(key).addListener(() {
        if (_hydrating) return;
        _manualCustomerPrices.remove(key);
        _recalculate(key);
      });
      _customerFor(key).addListener(() {
        if (_hydrating) return;
        if (_customerFor(key).text.trim().isEmpty) {
          _manualCustomerPrices.remove(key);
        } else {
          _manualCustomerPrices.add(key);
        }
      });
    }
    _commission.addListener(_recalculateAll);
    _tax.addListener(_recalculateAll);
    _other.addListener(_recalculateAll);
    _loadPricing();
  }

  List<String> get _allRateKeys => [
    ..._customerPrices.keys,
    ..._itemCustomerPrices.keys,
  ];

  TextEditingController _customerFor(String key) =>
      _customerPrices[key] ?? _itemCustomerPrices[key]!;

  TextEditingController _partnerFor(String key) =>
      _partnerRates[key] ?? _itemPartnerRates[key]!;

  @override
  void dispose() {
    _commission.dispose();
    _tax.dispose();
    _other.dispose();
    _logistics.dispose();
    for (final controller in _customerPrices.values) {
      controller.dispose();
    }
    for (final controller in _partnerRates.values) {
      controller.dispose();
    }
    for (final controller in _itemCustomerPrices.values) {
      controller.dispose();
    }
    for (final controller in _itemPartnerRates.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadPricing() async {
    try {
      final pricing = await GarmentCareService.adminPricing();
      final serviceRates = Map<String, dynamic>.from(
        pricing['serviceRates'] as Map? ?? const {},
      );
      final itemRates = Map<String, dynamic>.from(
        pricing['itemTypeRates'] as Map? ?? const {},
      );
      final pricingModelVersion =
          (pricing['pricingModelVersion'] as num?)?.toInt() ?? 1;
      final legacyDeliveryPercent =
          (pricing['deliveryPercent'] as num?)?.toDouble() ?? 6;
      final legacyMeasurementFee =
          (pricing['legacyMeasurementFee'] as num?)?.toDouble() ?? 0;
      _hydrating = true;
      _commission.text = _format(
        (pricing['platformCommissionPercent'] as num?)?.toDouble() ?? 15,
      );
      _tax.text = _format((pricing['taxPercent'] as num?)?.toDouble() ?? 6);
      _other.text = _format((pricing['otherFee'] as num?)?.toDouble() ?? 0);
      _logistics.text = _format(
        (pricing['logisticsAmount'] as num?)?.toDouble() ?? 0,
      );
      _activeVersion = pricing['versionId']?.toString();
      _manualCustomerPrices.clear();
      for (final entry in serviceRates.entries) {
        if (!_customerPrices.containsKey(entry.key) || entry.value is! Map) {
          continue;
        }
        final rate = Map<String, dynamic>.from(entry.value as Map);
        _setRateText(entry.key, rate);
      }
      for (final serviceEntry in itemRates.entries) {
        if (serviceEntry.value is! Map) continue;
        for (final itemEntry in Map<String, dynamic>.from(
          serviceEntry.value as Map,
        ).entries) {
          final key = _itemRateKey(serviceEntry.key, itemEntry.key);
          if (!_itemCustomerPrices.containsKey(key) ||
              itemEntry.value is! Map) {
            continue;
          }
          _setRateText(key, Map<String, dynamic>.from(itemEntry.value as Map));
        }
      }
      _hydrating = false;
      if (pricingModelVersion >= 2) {
        for (final key in _allRateKeys) {
          final partner = double.tryParse(_partnerFor(key).text);
          final customer = double.tryParse(_customerFor(key).text);
          if (partner == null || customer == null) continue;
          final currentExpected = _calculatedCustomer(partner);
          final previousExpected = pricingModelVersion >= 3
              ? currentExpected + legacyMeasurementFee
              : _legacyCalculatedCustomer(partner, legacyDeliveryPercent) +
                    legacyMeasurementFee;
          final expected = pricingModelVersion >= 4
              ? currentExpected
              : previousExpected;
          if ((customer - expected).abs() > 0.01) {
            _manualCustomerPrices.add(key);
          }
        }
      }
      _recalculateAll();
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = null;
        });
      }
    } on FirebaseFunctionsException catch (error) {
      _hydrating = false;
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = error.code == 'not-found'
            ? 'Pricing service is not deployed to this app environment yet. Deploy the Garment Care Functions, then reopen this page.'
            : error.message ??
                  'Could not load the active Garment Care rate card.';
      });
    } catch (_) {
      _hydrating = false;
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Could not load the active Garment Care rate card.';
      });
    }
  }

  void _setRateText(String key, Map<String, dynamic> rate) {
    final customer = rate['customerAmount'];
    final partner = rate['partnerAmount'];
    _customerFor(key).text = customer is num
        ? _format(customer.toDouble())
        : '';
    _partnerFor(key).text = partner is num ? _format(partner.toDouble()) : '';
  }

  double _calculatedCustomer(double partner) {
    final commission = double.tryParse(_commission.text) ?? 15;
    final tax = double.tryParse(_tax.text) ?? 6;
    final other = double.tryParse(_other.text) ?? 0;
    return ((partner * (100 + commission + tax) / 100 + other) * 100).round() /
        100;
  }

  double _legacyCalculatedCustomer(double partner, double deliveryPercent) {
    final commission = double.tryParse(_commission.text) ?? 15;
    final tax = double.tryParse(_tax.text) ?? 6;
    return ((partner * (100 + commission + tax + deliveryPercent) / 100) * 100)
            .round() /
        100;
  }

  String _format(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);

  void _recalculate(String key) {
    if (_hydrating || _manualCustomerPrices.contains(key)) return;
    final partner = double.tryParse(_partnerFor(key).text.trim());
    final customer = _customerFor(key);
    final next = partner == null ? '' : _format(_calculatedCustomer(partner));
    if (customer.text == next) return;
    _hydrating = true;
    customer.text = next;
    _hydrating = false;
  }

  void _recalculateAll() {
    if (_hydrating) return;
    for (final key in _allRateKeys) {
      _recalculate(key);
    }
  }

  Future<void> _publish() async {
    if (_saving) return;
    final commission = double.tryParse(_commission.text.trim());
    final tax = double.tryParse(_tax.text.trim());
    final other = double.tryParse(_other.text.trim());
    final logistics = double.tryParse(_logistics.text.trim());
    if (commission == null ||
        tax == null ||
        other == null ||
        logistics == null) {
      _message('Enter valid percentages and non-negative fixed fees.');
      return;
    }
    if (commission < 0 ||
        commission > 100 ||
        tax < 0 ||
        tax > 100 ||
        other < 0 ||
        logistics < 0) {
      _message('Percentages must be 0–100 and fixed fees cannot be negative.');
      return;
    }
    final rates = <String, dynamic>{};
    final itemTypeRates = <String, dynamic>{};
    for (final id in _serviceIds) {
      final customer = double.tryParse(_customerPrices[id]!.text.trim());
      final partner = double.tryParse(_partnerRates[id]!.text.trim());
      if (customer == null || partner == null || customer < 0 || partner < 0) {
        _message(
          'Enter valid partner and customer prices for ${GarmentCareServiceCatalog.labelFor(id)}.',
        );
        return;
      }
      final minimumCustomer = partner * (100 + commission + tax) / 100 + other;
      if (customer + 0.01 < minimumCustomer) {
        _message(
          'Customer price for ${GarmentCareServiceCatalog.labelFor(id)} must cover the Partner rate, fees and tax.',
        );
        return;
      }
      rates[id] = {'customerAmount': customer, 'partnerAmount': partner};
      final group = GarmentCareServiceGroup.values.firstWhere(
        (candidate) =>
            (GarmentCareServiceCatalog.serviceIdsByGroup[candidate.code] ??
                    const <String>[])
                .contains(id),
      );
      final overrides = <String, dynamic>{};
      for (final itemType in GarmentCareCatalogMetadata.itemTypesForGroup(
        group.code,
        serviceId: id,
      ).entries) {
        final key = _itemRateKey(id, itemType.key);
        final customerText = _itemCustomerPrices[key]!.text.trim();
        final partnerText = _itemPartnerRates[key]!.text.trim();
        if (customerText.isEmpty && partnerText.isEmpty) continue;
        final itemCustomer = double.tryParse(customerText);
        final itemPartner = double.tryParse(partnerText);
        if (itemCustomer == null || itemPartner == null) {
          _message(
            'Complete both prices for ${itemType.value}, or leave both blank.',
          );
          return;
        }
        final minimumItemCustomer =
            itemPartner * (100 + commission + tax) / 100 + other;
        if (itemCustomer + 0.01 < minimumItemCustomer) {
          _message(
            'Customer price for ${itemType.value} must cover the Partner rate, fees and tax.',
          );
          return;
        }
        overrides[itemType.key] = {
          'customerAmount': itemCustomer,
          'partnerAmount': itemPartner,
        };
      }
      if (overrides.isNotEmpty) itemTypeRates[id] = overrides;
    }
    setState(() => _saving = true);
    try {
      final version = await GarmentCareService.publishPricing(
        serviceRates: rates,
        itemTypeRates: itemTypeRates,
        platformCommissionPercent: commission,
        taxPercent: tax,
        otherFee: other,
        logisticsAmount: logistics,
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _activeVersion = version;
      });
      _message(
        'Pricing version ${version.substring(0, version.length < 8 ? version.length : 8)} is active.',
      );
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _message(
        error.code == 'not-found'
            ? 'Pricing service is not deployed to this app environment. Deploy the Garment Care Functions before publishing.'
            : error.message ?? 'Could not publish Garment Care pricing.',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _message('Could not publish Garment Care pricing.');
    }
  }

  String _itemRateKey(String serviceId, String itemTypeCode) =>
      '$serviceId::$itemTypeCode';

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) => GarmentCareTheme(
    child: Scaffold(
      backgroundColor: GarmentCareColors.background,
      appBar: AppBar(title: const Text('Garment Care Pricing')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 18),
        children: [
          OutlinedButton.icon(
            onPressed: () =>
                context.push('/owner/garment-care/inspection-templates'),
            icon: const Icon(Icons.message_outlined),
            label: const Text('Manage inspection messages'),
          ),
          if (_loadError != null)
            Card(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Text(_loadError!, style: const TextStyle(fontSize: 12)),
              ),
            ),
          if (_loading) const LinearProgressIndicator(),
          if (_activeVersion != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text(
                'Active version: ${_activeVersion!.substring(0, _activeVersion!.length < 8 ? _activeVersion!.length : 8)} · Publishing creates a new version.',
                style: const TextStyle(fontSize: 11),
              ),
            ),
          Card(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Customer price = Partner rate + platform and tax percentages (on the Partner rate) + fixed other fees. Logistics is a separate fixed fee per order; customer prices remain editable.',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 3,
                    children: [
                      _settingField(_commission, 'Platform %'),
                      _settingField(_tax, 'Tax %'),
                      _settingField(_other, 'Other fee ₹'),
                      _settingField(_logistics, 'Logistics ₹ / order'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          for (
            var groupIndex = 0;
            groupIndex < GarmentCareServiceGroup.values.length;
            groupIndex++
          )
            _groupRates(GarmentCareServiceGroup.values[groupIndex], groupIndex),
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
    ),
  );

  Widget _settingField(TextEditingController controller, String label) =>
      SizedBox(
        width: 136,
        child: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: pricingInputDecoration(
            labelText: label,
            verticalPadding: 7,
          ),
          style: const TextStyle(fontSize: 12),
        ),
      );

  Widget _groupRates(GarmentCareServiceGroup group, int groupIndex) {
    final serviceIds =
        GarmentCareServiceCatalog.serviceIdsByGroup[group.code] ??
        const <String>[];
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 4),
      child: ExpansionTile(
        initiallyExpanded: groupIndex == 0,
        dense: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 8),
        childrenPadding: const EdgeInsets.fromLTRB(6, 0, 6, 5),
        title: Text(group.label, style: const TextStyle(fontSize: 14)),
        subtitle: Text(
          '${serviceIds.length} services',
          style: const TextStyle(fontSize: 11),
        ),
        children: [
          _tableHeader(),
          for (final id in serviceIds) ...[
            _rateRow(GarmentCareServiceCatalog.labelFor(id), id),
            ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 4),
              childrenPadding: const EdgeInsets.only(left: 12),
              dense: true,
              title: const Text(
                'Garment-type overrides',
                style: TextStyle(fontSize: 11),
              ),
              subtitle: const Text(
                'Optional · blank uses the service rate',
                style: TextStyle(fontSize: 10),
              ),
              children: [
                for (final itemType
                    in GarmentCareCatalogMetadata.itemTypesForGroup(
                      group.code,
                      serviceId: id,
                    ).entries)
                  _rateRow(
                    itemType.value,
                    _itemRateKey(id, itemType.key),
                    isOverride: true,
                  ),
              ],
            ),
            const Divider(height: 1),
          ],
        ],
      ),
    );
  }

  Widget _tableHeader() => const Padding(
    padding: EdgeInsets.fromLTRB(4, 2, 4, 4),
    child: Row(
      children: [
        Expanded(
          flex: 5,
          child: Text(
            'Service / garment',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            'Partner ₹',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ),
        SizedBox(width: 4),
        Expanded(
          flex: 2,
          child: Text(
            'Customer ₹',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );

  Widget _rateRow(String label, String key, {bool isOverride = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 3),
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: isOverride ? Colors.black87 : null,
                ),
              ),
            ),
            Expanded(flex: 2, child: _priceField(_partnerFor(key), '')),
            const SizedBox(width: 4),
            Expanded(flex: 2, child: _priceField(_customerFor(key), '')),
          ],
        ),
      );

  Widget _priceField(TextEditingController controller, String label) =>
      TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: pricingInputDecoration(
          labelText: label.isEmpty ? null : label,
          verticalPadding: 6,
          horizontalPadding: 6,
        ),
        style: const TextStyle(fontSize: 11),
      );
}
