import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_state.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/metadata/garment_care_catalog_metadata.dart';
import '../../models/garment_care_domain.dart';
import '../../models/prd_catalog.dart';
import '../../services/garment_care_service.dart';
import '../../services/quick_care_pricing_service.dart';

class CustomerRatesScreen extends StatefulWidget {
  const CustomerRatesScreen({super.key});

  @override
  State<CustomerRatesScreen> createState() => _CustomerRatesScreenState();
}

class _CustomerRatesScreenState extends State<CustomerRatesScreen> {
  Map<String, double> _garmentCareRates = const {};
  Map<String, Map<String, double>> _itemRates = const {};
  double _garmentCareLogistics = 0;
  bool _loadingGarmentCare = true;
  String? _garmentCareError;
  Map<String, double> _quickCareRates = const {};
  double _quickCareVisitFee = 49;
  double _quickCareExpressFee = 99;

  @override
  void initState() {
    super.initState();
    unawaited(AppState.instance.loadRates());
    unawaited(_loadGarmentCareRates());
    unawaited(_loadQuickCareRates());
  }

  Future<void> _loadQuickCareRates() async {
    try {
      final pricing = await QuickCarePricingService.load();
      final rawRates = Map<String, dynamic>.from(
        pricing['serviceRates'] as Map? ?? const {},
      );
      if (!mounted) return;
      setState(() {
        _quickCareRates = {
          for (final entry in rawRates.entries)
            if (entry.value is Map &&
                (entry.value as Map)['customerAmount'] is num)
              entry.key: ((entry.value as Map)['customerAmount'] as num)
                  .toDouble(),
        };
        _quickCareVisitFee =
            (pricing['homeVisitCustomerAmount'] as num?)?.toDouble() ?? 49;
        _quickCareExpressFee =
            (pricing['expressCustomerAmount'] as num?)?.toDouble() ?? 99;
      });
    } catch (_) {
      // Retain the published catalogue estimate if the policy cannot load.
    }
  }

  Future<void> _loadGarmentCareRates() async {
    try {
      final pricing = await GarmentCareService.customerPricing();
      final rawServices = Map<String, dynamic>.from(
        pricing['serviceRates'] as Map? ?? const {},
      );
      final rawItemRates = Map<String, dynamic>.from(
        pricing['itemTypeRates'] as Map? ?? const {},
      );
      if (!mounted) return;
      setState(() {
        _garmentCareRates = {
          for (final entry in rawServices.entries)
            if (entry.value is Map &&
                (entry.value as Map)['customerAmount'] is num)
              entry.key: ((entry.value as Map)['customerAmount'] as num)
                  .toDouble(),
        };
        _itemRates = {
          for (final serviceEntry in rawItemRates.entries)
            if (serviceEntry.value is Map)
              serviceEntry.key: {
                for (final itemEntry in Map<String, dynamic>.from(
                  serviceEntry.value as Map,
                ).entries)
                  if (itemEntry.value is Map &&
                      (itemEntry.value as Map)['customerAmount'] is num)
                    itemEntry.key:
                        ((itemEntry.value as Map)['customerAmount'] as num)
                            .toDouble(),
              },
        };
        _garmentCareLogistics =
            (pricing['logisticsAmount'] as num?)?.toDouble() ?? 0;
        _loadingGarmentCare = false;
        _garmentCareError = null;
      });
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingGarmentCare = false;
        _garmentCareError = error.code == 'failed-precondition'
            ? 'The approved Garment Care price list is being prepared.'
            : 'Garment Care prices are temporarily unavailable.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingGarmentCare = false;
        _garmentCareError = 'Garment Care prices are temporarily unavailable.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Service Rate List')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _introCard(),
          const SizedBox(height: 16),
          ListenableBuilder(
            listenable: AppState.instance,
            builder: (context, _) => _section(
              title: 'Tailoring',
              icon: Icons.checkroom_outlined,
              child: AppState.instance.rates.isEmpty
                  ? const Text('Current tailoring rates are unavailable.')
                  : Column(
                      children: [
                        for (final rate in AppState.instance.rates)
                          _rateRow(
                            rate.dressType,
                            '₹${(rate.customerPrice ?? rate.basePrice).toStringAsFixed(0)}',
                            note: rate.notes == null || rate.notes!.isEmpty
                                ? 'Partner rate ₹${rate.basePrice.toStringAsFixed(0)}'
                                : '${rate.notes} · Partner rate ₹${rate.basePrice.toStringAsFixed(0)}',
                          ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 12),
          _section(
            title: 'Garment care',
            icon: Icons.local_laundry_service_outlined,
            child: _garmentCareBody(),
          ),
          const SizedBox(height: 12),
          _section(
            title: 'Doorstep & quick services',
            icon: Icons.delivery_dining_outlined,
            child: _quickCareBody(),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.accent.withValues(alpha: .25),
              ),
            ),
            child: Text(
              'Prices are estimates or starting rates where shown. A Partner may inspect the garment and request your approval if the final service plan or price changes. Any applicable charges are shown before you confirm a booking.',
              style: AppTextStyles.bodySmall.copyWith(height: 1.4),
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => context.push('/customer-help-support'),
            icon: const Icon(Icons.support_agent_outlined),
            label: const Text('Ask SuiSakhi Helpdesk about prices'),
          ),
        ],
      ),
    );
  }

  Widget _garmentCareBody() {
    if (_loadingGarmentCare) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_garmentCareError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_garmentCareError!),
          TextButton.icon(
            onPressed: _loadGarmentCareRates,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      );
    }
    return Column(
      children: [
        for (final group in GarmentCareServiceGroup.values) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Text(group.label, style: AppTextStyles.titleMedium),
            ),
          ),
          for (final id
              in GarmentCareServiceCatalog.serviceIdsByGroup[group.code] ??
                  const <String>[]) ...[
            if (_garmentCareRates.containsKey(id))
              _rateRow(
                GarmentCareServiceCatalog.labelFor(id),
                '₹${_garmentCareRates[id]!.toStringAsFixed(0)} / item',
              )
            else if ((_itemRates[id] ?? const {}).isEmpty)
              _rateRow(
                GarmentCareServiceCatalog.labelFor(id),
                'Price after review',
                note: 'The Partner will confirm an estimate before starting.',
              ),
            for (final entry in (_itemRates[id] ?? const {}).entries)
              _rateRow(
                '  ${GarmentCareCatalogMetadata.itemLabel(group.code, entry.key, serviceId: id)}',
                '₹${entry.value.toStringAsFixed(0)} / item',
              ),
          ],
        ],
      ],
    );
  }

  Widget _quickCareBody() => Column(
    children: [
      for (final service in QuickFixService.catalog)
        _rateRow(
          service.title,
          service.requiresPartnerQuote
              ? 'Quote after review'
              : '₹${(_quickCareRates[service.id] ?? service.midEstimate).toStringAsFixed(0)}',
          note: service.subtitle,
        ),
      _rateRow('Home visit', '₹${_quickCareVisitFee.toStringAsFixed(0)}'),
      _rateRow(
        'Express scheduling',
        '+₹${_quickCareExpressFee.toStringAsFixed(0)}',
      ),
      if (_garmentCareLogistics > 0)
        _rateRow(
          'Garment Care pickup / logistics',
          '₹${_garmentCareLogistics.toStringAsFixed(0)}',
        ),
    ],
  );

  Widget _introCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.primary.withValues(alpha: .07),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.primary.withValues(alpha: .18)),
    ),
    child: Text(
      'Browse SuiSakhi customer rates for tailoring, garment care and doorstep services.',
      style: AppTextStyles.bodyMedium.copyWith(height: 1.4),
    ),
  );

  Widget _section({
    required String title,
    required IconData icon,
    required Widget child,
  }) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.divider),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(title, style: AppTextStyles.headlineMedium),
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );

  Widget _rateRow(String title, String amount, {String? note}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.bodyMedium),
              if (note?.trim().isNotEmpty == true)
                Text(
                  note!,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textHint,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          amount,
          textAlign: TextAlign.end,
          style: AppTextStyles.titleMedium.copyWith(color: AppColors.primary),
        ),
      ],
    ),
  );
}
