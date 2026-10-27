import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/garment_care_colors.dart';
import '../../core/garment_care_guidance.dart';
import '../../core/metadata/garment_care_catalog_metadata.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/garment_care_domain.dart';
import '../../models/payment_models.dart';
import '../../services/garment_care_service.dart';
import '../../services/payout_config_service.dart';
import '../../widgets/orders/order_tracking_tag.dart';

class GarmentCareScreen extends StatefulWidget {
  const GarmentCareScreen({super.key});

  @override
  State<GarmentCareScreen> createState() => _GarmentCareScreenState();
}

class _GarmentCareScreenState extends State<GarmentCareScreen> {
  static const _pickupSlots = <String>['9:00 AM–1:00 PM', '4:00 PM–8:00 PM'];
  static const _maxQuantity = 20;

  final _name = TextEditingController();
  final _itemType = TextEditingController();
  final _material = TextEditingController();
  final _condition = TextEditingController();
  final _careNotes = TextEditingController();
  String? _starchLevel;
  final List<Map<String, dynamic>> _items = [];
  final List<Map<String, String>> _serviceSteps = [];
  String? _selectedServiceId;
  bool _includeHygieneWash = false;
  String? _savedGarmentId;
  bool _previousDnaCopied = false;
  GarmentCareServiceGroup? _group;
  bool _saving = false;
  bool _loadingAddresses = true;
  List<Map<String, dynamic>> _addresses = [];
  String? _pickupAddressId;
  final Map<String, String> _pickupSlotsByGroup = {};
  final Map<String, DateTime> _pickupDatesByGroup = {};
  Map<String, double> _customerRates = {};
  Map<String, Map<String, double>> _customerItemRates = {};
  double _taxPercent = 0;
  int _pricingModelVersion = 1;
  double _logisticsAmount = 0;
  int _quantity = 1;
  bool _cartOpen = false;
  bool _pricingLoading = true;
  String? _pricingError;
  bool _cartDraftLoading = true;
  bool _cartDraftLoadFailed = false;
  Future<void> _cartDraftWriteQueue = Future<void>.value();
  Timer? _pickupAvailabilityTimer;

  @override
  void initState() {
    super.initState();
    _loadPricing();
    unawaited(_initializeCartDraft());
    _pickupAvailabilityTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _initializeCartDraft() async {
    if (mounted) {
      setState(() {
        _cartDraftLoading = true;
        _cartDraftLoadFailed = false;
      });
    }
    await _loadAddresses();
    await _restoreCartDraft();
  }

  Future<void> _restoreCartDraft() async {
    try {
      var draft = await GarmentCareService.customerCartDraft();
      final removedSubmittedDraft =
          draft != null &&
          await GarmentCareService.clearCustomerCartDraftIfAlreadySubmitted(
            draft,
          );
      if (removedSubmittedDraft) draft = null;
      if (!mounted) return;
      final restoredItems = <Map<String, dynamic>>[];
      for (final raw in draft?['items'] as List<dynamic>? ?? const []) {
        if (raw is! Map) continue;
        final item = Map<String, dynamic>.from(raw);
        // Older drafts linked a previous tailoring order as if it were the
        // same physical garment. It is now a copyable DNA reference; only a
        // saved Garment ID represents the same physical item.
        if (item['garmentId'] == null) item.remove('sourceOrderId');
        final rawSteps = item['serviceSteps'] as List<dynamic>? ?? const [];
        item['serviceSteps'] = rawSteps
            .whereType<Map>()
            .map((step) => Map<String, dynamic>.from(step))
            .toList(growable: false);
        item['serviceIds'] = (item['serviceIds'] as List<dynamic>? ?? const [])
            .map((id) => id.toString())
            .toList(growable: false);
        item['conditionPhotoPaths'] =
            (item['conditionPhotoPaths'] as List<dynamic>? ?? const [])
                .map((path) => path.toString())
                .toList(growable: false);
        item['quantity'] = (item['quantity'] as num?)?.toInt() ?? 1;
        if ((item['serviceSteps'] as List).isNotEmpty &&
            (item['quantity'] as int) > 0) {
          restoredItems.add(item);
        }
      }
      final restoredSlots = <String, String>{};
      final rawSlots = draft?['pickupSlotsByGroup'];
      if (rawSlots is Map) {
        for (final entry in rawSlots.entries) {
          final slot = entry.value?.toString();
          if (_pickupSlots.contains(slot)) {
            restoredSlots[entry.key.toString()] = slot!;
          }
        }
      }
      final restoredDates = <String, DateTime>{};
      final rawDates = draft?['pickupDatesByGroup'];
      if (rawDates is Map) {
        for (final entry in rawDates.entries) {
          if (entry.value is num) {
            restoredDates[entry.key
                .toString()] = DateTime.fromMillisecondsSinceEpoch(
              (entry.value as num).toInt(),
            );
          }
        }
      }
      final savedAddressId = draft?['pickupAddressId']?.toString();
      final addressStillAvailable = _addresses.any(
        (address) => address['addressId']?.toString() == savedAddressId,
      );
      setState(() {
        _items
          ..clear()
          ..addAll(restoredItems);
        _pickupSlotsByGroup
          ..clear()
          ..addAll(restoredSlots);
        _pickupDatesByGroup
          ..clear()
          ..addAll(restoredDates);
        if (addressStillAvailable) _pickupAddressId = savedAddressId;
        _cartDraftLoading = false;
        _cartDraftLoadFailed = false;
      });
      if (restoredItems.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Restored your saved care cart · $_cartCount pieces.',
            ),
          ),
        );
      } else if (removedSubmittedDraft) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Removed the previously submitted items from your saved cart.',
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cartDraftLoading = false;
        _cartDraftLoadFailed = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not restore your saved care cart. Retry before editing it.',
          ),
        ),
      );
    }
  }

  void _queueCartDraftSave() {
    if (_cartDraftLoading || _cartDraftLoadFailed) return;
    final items = _items
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
    final addressId = _pickupAddressId;
    final slots = Map<String, String>.from(_pickupSlotsByGroup);
    final dates = {
      for (final entry in _pickupDatesByGroup.entries)
        entry.key: entry.value.millisecondsSinceEpoch,
    };
    final operation = _cartDraftWriteQueue.catchError((_) {}).then((_) async {
      if (items.isEmpty) {
        await GarmentCareService.clearCustomerCartDraft();
      } else {
        await GarmentCareService.saveCustomerCartDraft(
          items: items,
          pickupAddressId: addressId,
          pickupSlotsByGroup: slots,
          pickupDatesByGroup: dates,
        );
      }
    });
    _cartDraftWriteQueue = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Your care cart could not be saved. Check your connection before signing out.',
            ),
          ),
        );
      },
    );
  }

  bool get _hasStarchService => _selectedServiceId == 'fabric_starching';

  static const _hygieneCompatibleServices = <String>{
    'wash_fold',
    'wash_iron',
    'premium_wet_cleaning',
  };

  DateTime get _defaultPickupDate {
    final now = DateTime.now();
    final today = _dateOnly(now);
    return _availablePickupSlotsForDate(today, now: now).isNotEmpty
        ? today
        : today.add(const Duration(days: 1));
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  int? _pickupSlotStartMinutes(String slot) {
    if (slot == '9:00 AM–1:00 PM') return 9 * 60;
    if (slot == '4:00 PM–8:00 PM') return 16 * 60;
    return null;
  }

  List<String> _availablePickupSlotsForDate(DateTime date, {DateTime? now}) {
    final currentTime = now ?? DateTime.now();
    final pickupDay = _dateOnly(date);
    final today = _dateOnly(currentTime);
    if (pickupDay.isBefore(today)) return const [];
    if (pickupDay.isAfter(today)) return _pickupSlots;
    return _pickupSlots
        .where((slot) {
          final startMinutes = _pickupSlotStartMinutes(slot);
          return startMinutes != null &&
              pickupDay
                  .add(Duration(minutes: startMinutes))
                  .isAfter(currentTime);
        })
        .toList(growable: false);
  }

  DateTime _pickupDateForGroup(String groupCode) {
    final selected = _dateOnly(
      _pickupDatesByGroup[groupCode] ?? _defaultPickupDate,
    );
    final firstAvailable = _dateOnly(_defaultPickupDate);
    return selected.isBefore(firstAvailable) ? firstAvailable : selected;
  }

  String _pickupSlotForGroup(String groupCode, DateTime date) {
    final available = _availablePickupSlotsForDate(date);
    final selected = _pickupSlotsByGroup[groupCode];
    if (selected != null && available.contains(selected)) return selected;
    return available.isNotEmpty ? available.first : _pickupSlots.first;
  }

  int _scheduledPickupAtMillis(DateTime date, String slot) {
    final startMinutes = _pickupSlotStartMinutes(slot);
    if (startMinutes == null) {
      throw StateError('Choose a supported pickup window.');
    }
    // The app schedules pickups in India Standard Time, independent of the
    // phone's configured timezone.
    return DateTime.utc(date.year, date.month, date.day)
        .add(Duration(minutes: startMinutes))
        .subtract(const Duration(hours: 5, minutes: 30))
        .millisecondsSinceEpoch;
  }

  Map<String, dynamic> _pickupScheduleForGroup(String groupCode) {
    final date = _pickupDateForGroup(groupCode);
    final slot = _pickupSlotForGroup(groupCode, date);
    return {
      'preferredPickupAtMillis': _scheduledPickupAtMillis(date, slot),
      'pickupSlot': slot,
    };
  }

  Future<void> _loadPricing() async {
    if (mounted && (!_pricingLoading || _pricingError != null)) {
      setState(() {
        _pricingLoading = true;
        _pricingError = null;
      });
    }
    try {
      final pricing = await GarmentCareService.customerPricing();
      final rates = Map<String, dynamic>.from(
        pricing['serviceRates'] as Map? ?? const {},
      );
      final itemRates = Map<String, dynamic>.from(
        pricing['itemTypeRates'] as Map? ?? const {},
      );
      if (!mounted) return;
      setState(() {
        _customerRates = {
          for (final entry in rates.entries)
            entry.key: (entry.value['customerAmount'] as num).toDouble(),
        };
        _customerItemRates = {
          for (final serviceEntry in itemRates.entries)
            serviceEntry.key: {
              for (final itemEntry in Map<String, dynamic>.from(
                serviceEntry.value as Map,
              ).entries)
                itemEntry.key: (itemEntry.value['customerAmount'] as num)
                    .toDouble(),
            },
        };
        _taxPercent = (pricing['taxPercent'] as num?)?.toDouble() ?? 0;
        _pricingModelVersion =
            (pricing['pricingModelVersion'] as num?)?.toInt() ?? 1;
        _logisticsAmount =
            (pricing['logisticsAmount'] as num?)?.toDouble() ?? 0;
        _pricingLoading = false;
        _pricingError = null;
      });
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      setState(() {
        _pricingLoading = false;
        _pricingError = switch (error.code) {
          'failed-precondition' =>
            'SuiSakhi is preparing the approved Garment Care price list.',
          'not-found' =>
            'Garment Care pricing is not connected to this app environment yet. Please contact support.',
          _ =>
            'Could not load the current Garment Care estimate. Please retry.',
        };
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pricingLoading = false;
        _pricingError = 'Could not load the current Garment Care estimate.';
      });
    }
  }

  Future<void> _loadAddresses() async {
    try {
      final addresses = await GarmentCareService.customerAddresses();
      if (!mounted) return;
      setState(() {
        _addresses = addresses;
        _pickupAddressId = addresses.isEmpty
            ? null
            : addresses.first['addressId']?.toString();
        _loadingAddresses = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingAddresses = false);
    }
  }

  Future<void> _openGroupSelection(GarmentCareServiceGroup group) async {
    if (_cartDraftLoading || _cartDraftLoadFailed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _cartDraftLoading
                ? 'Checking for your saved care cart. Please wait a moment.'
                : 'Could not load your saved cart. Open My Care Cart and tap Retry.',
          ),
        ),
      );
      return;
    }
    final selection = await Navigator.of(context).push<_CareGroupSelection>(
      MaterialPageRoute(
        builder: (_) => _GarmentCareGroupSelectionScreen(
          group: group,
          cartCount: _items.length,
          onCartTap: () {
            Navigator.of(context).pop();
            setState(() => _cartOpen = true);
          },
        ),
      ),
    );
    if (selection == null || !mounted) return;
    _group = group;
    _selectedServiceId = selection.serviceId;
    _includeHygieneWash = selection.includeHygieneWash;
    _savedGarmentId = selection.garmentId;
    _previousDnaCopied = selection.previousDnaCopied;
    _name.text = selection.displayName;
    _itemType.text = selection.itemTypeCode;
    _material.text = selection.material;
    _condition.text = selection.conditionNotes;
    _careNotes.text = selection.careNotes;
    _quantity = selection.quantity;
    _starchLevel = selection.starchLevel;
    _addToCart();
  }

  @override
  void dispose() {
    _pickupAvailabilityTimer?.cancel();
    _name.dispose();
    _itemType.dispose();
    _material.dispose();
    _condition.dispose();
    _careNotes.dispose();
    super.dispose();
  }

  void _addServiceStep() {
    final group = _group;
    final serviceId = _selectedServiceId;
    if (group == null || serviceId == null) return;
    if (_serviceSteps.any((step) => step['serviceId'] == serviceId)) return;
    setState(() {
      _serviceSteps.add({'groupCode': group.code, 'serviceId': serviceId});
      _selectedServiceId = null;
    });
  }

  void _removeServiceStep(int index) =>
      setState(() => _serviceSteps.removeAt(index));

  Future<void> _chooseSavedGarment() async {
    try {
      final garments = await GarmentCareService.savedGarments();
      if (!mounted) return;
      final selected = await showModalBottomSheet<GarmentCareIdentity>(
        context: context,
        builder: (context) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Use a saved garment',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (garments.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No saved Garment DNA records yet.'),
                ),
              for (final garment in garments)
                ListTile(
                  leading: const Icon(Icons.checkroom_outlined),
                  title: Text(garment.displayName),
                  subtitle: Text(
                    [
                      garment.itemTypeCode,
                      garment.material,
                    ].where((value) => value?.isNotEmpty == true).join(' · '),
                  ),
                  onTap: () => Navigator.pop(context, garment),
                ),
            ],
          ),
        ),
      );
      if (selected == null || !mounted) return;
      setState(() {
        _savedGarmentId = selected.garmentId;
        _previousDnaCopied = false;
        _name.text = selected.displayName;
        _itemType.text = selected.itemTypeCode;
        _material.text = selected.material ?? '';
        _condition.clear();
        _careNotes.text = selected.careLabel ?? '';
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not load saved garment records.'),
          ),
        );
      }
    }
  }

  Future<void> _choosePreviousTailoringOrder() async {
    try {
      final records = await GarmentCareService.legacyGarmentReferences();
      if (!mounted) return;
      final selected = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        builder: (context) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Use a previous SuiSakhi garment',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (records.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No published Garment DNA reports are available yet.',
                  ),
                ),
              for (final record in records)
                ListTile(
                  leading: const Icon(Icons.history_rounded),
                  title: Text(
                    record['dressType']?.toString() ?? 'Previous garment',
                  ),
                  subtitle: Text(
                    'Order ${record['orderTrackingId'] ?? record['id']}',
                  ),
                  onTap: () => Navigator.pop(context, record),
                ),
            ],
          ),
        ),
      );
      if (selected == null || !mounted) return;
      final prefill = _careDnaPrefillFromPreviousOrder(
        selected,
        groupCode: _group?.code ?? '',
        serviceId: _selectedServiceId,
      );
      setState(() {
        _savedGarmentId = null;
        _previousDnaCopied = true;
        _name.text = prefill.displayName;
        _itemType.text = prefill.itemTypeCode;
        _material.text = prefill.material;
        _condition.text = prefill.conditionNotes;
        _careNotes.text = prefill.careNotes;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not load previous garment reports.'),
          ),
        );
      }
    }
  }

  void _addToCart() {
    if (_cartDraftLoading || _cartDraftLoadFailed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _cartDraftLoading
                ? 'Checking for your saved care cart. Please wait a moment.'
                : 'Could not load your saved cart. Open My Care Cart and tap Retry.',
          ),
        ),
      );
      return;
    }
    final group = _group;
    final serviceId = _selectedServiceId;
    if (group == null || serviceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose one care service before adding this item.'),
        ),
      );
      return;
    }
    final serviceIds = <String>[serviceId];
    final steps = serviceIds
        .map((id) => {'groupCode': group.code, 'serviceId': id})
        .toList(growable: false);
    if (_savedGarmentId != null && _quantity != 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A saved physical garment can only be added once.'),
        ),
      );
      return;
    }
    final displayName = _name.text.trim().isNotEmpty
        ? _name.text.trim()
        : _itemType.text.trim().isNotEmpty && _itemType.text != 'other'
        ? _itemType.text.trim()
        : 'Other garment';
    setState(() {
      _items.add({
        'displayName': displayName,
        if (_savedGarmentId != null) 'garmentId': _savedGarmentId,
        'itemTypeCode': _itemType.text.trim().isEmpty
            ? 'other'
            : _itemType.text.trim().toLowerCase().replaceAll(' ', '_'),
        'quantity': _quantity,
        'material': _material.text.trim(),
        'groupCode': group.code,
        'serviceIds': serviceIds,
        'serviceSteps': steps
            .map((step) => Map<String, String>.from(step))
            .toList(growable: false),
        'conditionNotes': _condition.text.trim(),
        'careNotes': _careNotes.text.trim(),
        'hygieneWashRequested':
            _includeHygieneWash &&
            _hygieneCompatibleServices.contains(serviceId),
        'starchLevel': _starchLevel,
        'conditionPhotoPaths': const <String>[],
      });
      _savedGarmentId = null;
      _previousDnaCopied = false;
      _name.clear();
      _itemType.clear();
      _material.clear();
      _condition.clear();
      _careNotes.clear();
      _starchLevel = null;
      _selectedServiceId = null;
      _group = null;
      _includeHygieneWash = false;
      _quantity = 1;
    });
    _queueCartDraftSave();
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Added $displayName × ${_items.last['quantity']} to cart.',
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }

  Future<void> _submitOrder() async {
    if (_items.isEmpty || _saving || _pricingLoading) return;
    if (_cartDraftLoading || _cartDraftLoadFailed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _cartDraftLoading
                ? 'Checking for your saved care cart. Please wait a moment.'
                : 'Could not load your saved cart. Open My Care Cart and tap Retry.',
          ),
        ),
      );
      return;
    }
    if (_pricingError != null || _customerRates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_pricingError ?? 'Pricing is unavailable.')),
      );
      return;
    }
    if (_pickupAddressId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a saved pickup address.')),
      );
      return;
    }
    final pickupAddress = _addresses.firstWhere(
      (address) => address['addressId'] == _pickupAddressId,
    );
    setState(() => _saving = true);
    try {
      await _cartDraftWriteQueue;
      final owner = await GarmentCareService.customerContext();
      final pickupSchedule = {
        for (final groupCode in _cartGroupCodes)
          groupCode: _pickupScheduleForGroup(groupCode),
      };
      final created = await GarmentCareService.createOrder(
        accountId: owner.accountId,
        profileId: owner.profileId,
        items: _items,
        pickupAddress: pickupAddress,
        pickupByServiceGroup: pickupSchedule,
      );
      var savedCartClearFailed = false;
      try {
        await GarmentCareService.clearCustomerCartDraft();
      } catch (_) {
        // Order creation has already succeeded. Keep that success distinct
        // from a draft cleanup failure so the Customer is not invited to
        // submit the same cart again.
        savedCartClearFailed = true;
      }
      if (!mounted) return;
      setState(() {
        _items.clear();
        _pickupSlotsByGroup.clear();
        _pickupDatesByGroup.clear();
        _saving = false;
        _cartOpen = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            savedCartClearFailed
                ? '${created.orderIds.length} service ${created.orderIds.length == 1 ? 'order was' : 'orders were'} created, but the saved cart could not be cleared. Do not submit those items again.'
                : '${created.orderIds.length} independent service ${created.orderIds.length == 1 ? 'order' : 'orders'} created.',
          ),
        ),
      );
      context.push('/garment-care/orders');
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.code == 'not-found'
                ? 'Garment Care is not connected to this app environment yet. Please contact support.'
                : error.message ?? 'Could not submit your request.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cartOpen) {
      return GarmentCareTheme(child: _buildCartScreen());
    }
    final group = _group;
    return GarmentCareTheme(
      child: Scaffold(
        backgroundColor: GarmentCareColors.background,
        appBar: AppBar(
          leadingWidth: 48,
          titleSpacing: 4,
          title: const Text(
            'Garment Care',
            maxLines: 1,
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          ),
          actions: [
            IconButton(
              tooltip: 'Shopping cart ($_cartCount items)',
              onPressed: () => setState(() => _cartOpen = true),
              icon: Badge(
                isLabelVisible: _cartCount > 0,
                label: Text('$_cartCount'),
                child: const Icon(Icons.shopping_cart_outlined),
              ),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 40, height: 44),
            ),
            IconButton(
              tooltip: 'My Garment DNA',
              onPressed: () => context.push('/garment-care/dna'),
              icon: const Icon(Icons.fingerprint_rounded),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 40, height: 44),
            ),
            IconButton(
              tooltip: 'My Garment Care orders',
              onPressed: () => context.push('/garment-care/orders'),
              icon: const Icon(Icons.receipt_long_outlined),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 40, height: 44),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            Text('Book your next service', style: AppTextStyles.headlineSmall),
            const SizedBox(height: 4),
            Text(
              'Choose a service to add your garments.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: GarmentCareColors.textHint,
              ),
            ),
            const SizedBox(height: 18),
            _activeOrderCard(),
            const SizedBox(height: 18),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: .68,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                for (final option in GarmentCareServiceGroup.values.take(4))
                  _GroupCard(
                    group: option,
                    selected: false,
                    image: _groupArtwork(option),
                    onTap: () => _openGroupSelection(option),
                  ),
              ],
            ),
            if (group != null) ...[
              const SizedBox(height: 12),
              _sectionTitle(
                _serviceSteps.isEmpty
                    ? 'Choose one ${group.label} service'
                    : 'Add another service for this item (optional)',
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedServiceId,
                decoration: InputDecoration(
                  labelText: 'Service',
                  hintText: 'Select one option',
                  filled: true,
                  fillColor: GarmentCareColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                items:
                    GarmentCareServiceCatalog.serviceIdsByGroup[group.code]
                        ?.map(
                          (serviceId) => DropdownMenuItem<String>(
                            value: serviceId,
                            child: Text(
                              GarmentCareServiceCatalog.labelFor(serviceId),
                            ),
                          ),
                        )
                        .toList() ??
                    const [],
                onChanged: (value) =>
                    setState(() => _selectedServiceId = value),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _addServiceStep,
                icon: const Icon(Icons.add_rounded),
                label: Text(
                  _serviceSteps.isEmpty
                      ? 'Add another service step'
                      : 'Add next service step',
                ),
              ),
              if (_serviceSteps.isNotEmpty) ...[
                const SizedBox(height: 8),
                _sectionTitle('Service steps, in order'),
                for (var index = 0; index < _serviceSteps.length; index++)
                  Card(
                    color: GarmentCareColors.surface,
                    child: ListTile(
                      leading: CircleAvatar(child: Text('${index + 1}')),
                      title: Text(
                        GarmentCareServiceCatalog.labelFor(
                          _serviceSteps[index]['serviceId']!,
                        ),
                      ),
                      subtitle: Text(
                        GarmentCareServiceGroup.fromCode(
                              _serviceSteps[index]['groupCode'],
                            )?.label ??
                            '',
                      ),
                      trailing: IconButton(
                        tooltip: 'Remove service step',
                        onPressed: () => _removeServiceStep(index),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ),
                  ),
              ],
            ],
            if (group != null) ...[
              const SizedBox(height: 12),
              _sectionTitle('Garment details (optional)'),
              const SizedBox(height: 6),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  TextButton.icon(
                    onPressed: _chooseSavedGarment,
                    icon: const Icon(Icons.checkroom_outlined),
                    label: const Text('Use saved garment'),
                  ),
                  TextButton.icon(
                    onPressed: _choosePreviousTailoringOrder,
                    icon: const Icon(Icons.history_rounded),
                    label: const Text('Use previous order DNA'),
                  ),
                ],
              ),
              if (_savedGarmentId != null)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'This saved physical garment is linked to this Care Order. Quantity stays at one.',
                  ),
                ),
              if (_previousDnaCopied)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Previous Garment DNA was copied into the editable fields. Review it and change the quantity as needed.',
                  ),
                ),
              _sectionTitle('Garment type (optional)'),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue:
                    GarmentCareCatalogMetadata.itemTypesForGroup(
                      group.code,
                      serviceId: _selectedServiceId,
                    ).containsKey(_itemType.text)
                    ? _itemType.text
                    : null,
                decoration: InputDecoration(
                  labelText: 'Choose garment type',
                  hintText: 'Optional — choose Other if not listed',
                  filled: true,
                  fillColor: GarmentCareColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                items:
                    GarmentCareCatalogMetadata.itemTypesForGroup(
                          group.code,
                          serviceId: _selectedServiceId,
                        ).entries
                        .map(
                          (entry) => DropdownMenuItem<String>(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                        )
                        .toList(),
                onChanged: (value) => setState(() {
                  _itemType.text = value ?? '';
                  if (value == 'other') {
                    _name.clear();
                  } else if (value != null) {
                    _name.text = GarmentCareCatalogMetadata.itemLabel(
                      group.code,
                      value,
                      serviceId: _selectedServiceId,
                    );
                  }
                }),
              ),
              if (_itemType.text == 'other')
                _field(
                  _name,
                  'Describe the item (optional)',
                  hint: 'e.g. embroidered dupatta',
                ),
              const SizedBox(height: 8),
              _quantityStepper(),
              DropdownButtonFormField<String>(
                initialValue:
                    GarmentCareCatalogMetadata.materialTypes.contains(
                      _material.text,
                    )
                    ? _material.text
                    : null,
                decoration: InputDecoration(
                  labelText: 'Fabric / material (optional)',
                  hintText: 'Select if known',
                  filled: true,
                  fillColor: GarmentCareColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                items: GarmentCareCatalogMetadata.materialTypes
                    .map(
                      (value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() {
                  if (value == 'Other') {
                    _material.clear();
                  } else {
                    _material.text = value ?? '';
                  }
                }),
              ),
              if (_material.text.isEmpty ||
                  !GarmentCareCatalogMetadata.materialTypes.contains(
                    _material.text,
                  ))
                _field(
                  _material,
                  'Other material (optional)',
                  hint: 'Enter material if not listed',
                ),
              if (_material.text.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    GarmentCareGuidance.forMaterial(_material.text.trim(), ''),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: GarmentCareColors.textHint,
                    ),
                  ),
                ),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Add a condition or care note (optional)'),
                children: [
                  _field(
                    _condition,
                    'Stain or damage (optional)',
                    hint: 'Only if there is something to report',
                    lines: 2,
                  ),
                  _field(
                    _careNotes,
                    'Care instructions (optional)',
                    hint: 'Anything you want the Partner to know',
                    lines: 2,
                  ),
                  if (_hasStarchService) ...[
                    DropdownButtonFormField<String>(
                      initialValue: _starchLevel,
                      decoration: const InputDecoration(
                        labelText: 'Starch level (optional)',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'none',
                          child: Text('No starch'),
                        ),
                        DropdownMenuItem(value: 'light', child: Text('Light')),
                        DropdownMenuItem(
                          value: 'medium',
                          child: Text('Medium'),
                        ),
                        DropdownMenuItem(value: 'heavy', child: Text('Heavy')),
                        DropdownMenuItem(
                          value: 'recommended',
                          child: Text('Recommended by care guide'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _starchLevel = value),
                    ),
                    if (_starchLevel == 'recommended')
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 8),
                        child: Text(
                          GarmentCareGuidance.starchingRecommendation(
                            _material.text.trim(),
                          ),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: GarmentCareColors.textHint,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
              FilledButton.icon(
                onPressed: _addToCart,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add to cart'),
              ),
            ],
          ],
        ),
        bottomNavigationBar: _items.isEmpty ? null : _cartBar(),
      ),
    );
  }

  int get _cartCount => _items.fold<int>(
    0,
    (total, item) => total + ((item['quantity'] as int?) ?? 1),
  );

  List<String> get _cartGroupCodes {
    final codes = <String>{};
    for (final item in _items) {
      for (final rawStep
          in item['serviceSteps'] as List<dynamic>? ?? const []) {
        codes.add((rawStep as Map)['groupCode'].toString());
      }
    }
    return codes.toList(growable: false);
  }

  List<Map<String, dynamic>> _itemsForGroup(String groupCode) => _items
      .where(
        (item) => (item['serviceSteps'] as List<dynamic>? ?? const []).any(
          (step) => (step as Map)['groupCode'] == groupCode,
        ),
      )
      .toList(growable: false);

  Map<String, double> _estimateForGroup(String groupCode) {
    var subtotal = 0.0;
    var tax = 0.0;
    for (final item in _items) {
      final quantity = (item['quantity'] as int?) ?? 1;
      for (final rawStep
          in item['serviceSteps'] as List<dynamic>? ?? const []) {
        final step = Map<String, dynamic>.from(rawStep as Map);
        if (step['groupCode'] != groupCode) continue;
        final serviceId = step['serviceId']?.toString() ?? '';
        final itemTypeCode = item['itemTypeCode']?.toString() ?? 'other';
        final rate =
            _customerItemRates[serviceId]?[itemTypeCode] ??
            _customerRates[serviceId] ??
            0;
        subtotal += rate * quantity;
        if (_pricingModelVersion < 2) {
          tax += ((rate * _taxPercent / 100) * 100).round() / 100 * quantity;
        }
      }
    }
    return {
      'subtotal': subtotal,
      'tax': tax,
      'logistics': _logisticsAmount,
      'total': subtotal + tax + _logisticsAmount,
    };
  }

  double get _estimatedTotal => _cartGroupCodes.fold<double>(
    0,
    (total, code) => total + (_estimateForGroup(code)['total'] ?? 0),
  );

  String _money(double amount) => '₹${amount.toStringAsFixed(2)}';

  void _changeQuantity(int index, int delta) {
    final item = _items[index];
    if (item['garmentId'] != null) return;
    final next = ((item['quantity'] as int?) ?? 1) + delta;
    if (next < 1 || next > _maxQuantity) return;
    item['quantity'] = next;
  }

  Widget _quantityStepper({int? cartIndex}) {
    final value = cartIndex == null
        ? _quantity
        : ((_items[cartIndex]['quantity'] as int?) ?? 1);
    final locked = cartIndex == null
        ? _savedGarmentId != null
        : _items[cartIndex]['garmentId'] != null;
    return Row(
      children: [
        Text(cartIndex == null ? 'Quantity' : 'Pieces'),
        const Spacer(),
        IconButton.filledTonal(
          tooltip: 'Decrease quantity',
          onPressed: value <= 1 || locked
              ? null
              : () {
                  setState(() {
                    if (cartIndex == null) {
                      _quantity--;
                    } else {
                      _changeQuantity(cartIndex, -1);
                    }
                  });
                  if (cartIndex != null) _queueCartDraftSave();
                },
          icon: const Icon(Icons.remove_rounded),
        ),
        SizedBox(width: 34, child: Text('$value', textAlign: TextAlign.center)),
        IconButton.filledTonal(
          tooltip: 'Increase quantity',
          onPressed: value >= _maxQuantity || locked
              ? null
              : () {
                  setState(() {
                    if (cartIndex == null) {
                      _quantity++;
                    } else {
                      _changeQuantity(cartIndex, 1);
                    }
                  });
                  if (cartIndex != null) _queueCartDraftSave();
                },
          icon: const Icon(Icons.add_rounded),
        ),
      ],
    );
  }

  Widget _cartBar() => SafeArea(
    top: false,
    child: Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: GarmentCareColors.surface,
        border: Border(top: BorderSide(color: GarmentCareColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_items.length} entries · $_cartCount pieces'),
                Text(
                  _pricingLoading || _pricingError != null
                      ? 'Estimate loading'
                      : 'Estimate ${_money(_estimatedTotal)}',
                  style: TextStyle(
                    color: GarmentCareColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: () => setState(() => _cartOpen = true),
            icon: const Icon(Icons.shopping_cart_checkout_rounded),
            label: const Text('Review cart'),
          ),
        ],
      ),
    ),
  );

  Widget _buildCartScreen() => Scaffold(
    backgroundColor: GarmentCareColors.background,
    appBar: AppBar(
      leading: IconButton(
        tooltip: 'Continue shopping',
        onPressed: () => setState(() => _cartOpen = false),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      title: const Text('My Care Cart'),
      actions: [
        IconButton(
          tooltip: 'My Garment Care orders',
          onPressed: () => context.push('/garment-care/orders'),
          icon: const Icon(Icons.receipt_long_outlined),
        ),
      ],
    ),
    body: _items.isEmpty
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.shopping_cart_outlined,
                  size: 52,
                  color: GarmentCareColors.primary,
                ),
                const SizedBox(height: 10),
                if (_cartDraftLoading) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 10),
                  const Text('Restoring your saved care cart…'),
                ] else if (_cartDraftLoadFailed) ...[
                  const Text('Your saved care cart could not be loaded.'),
                  TextButton(
                    onPressed: _initializeCartDraft,
                    child: const Text('Retry'),
                  ),
                ] else ...[
                  const Text('Your care cart is empty.'),
                  TextButton(
                    onPressed: () => setState(() => _cartOpen = false),
                    child: const Text('Browse services'),
                  ),
                ],
              ],
            ),
          )
        : ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              Text('Review your care', style: AppTextStyles.headlineSmall),
              const SizedBox(height: 5),
              Text(
                'Each service group becomes a separate service order. Quantity is the number of pieces in each garment entry.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: GarmentCareColors.textHint,
                ),
              ),
              const SizedBox(height: 14),
              _cartGroupSummary(),
              const SizedBox(height: 12),
              for (final code in _cartGroupCodes) _serviceOrderCard(code),
              const SizedBox(height: 4),
              _pickupSection(),
              const SizedBox(height: 12),
              _cartEstimateSummary(),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: GarmentCareColors.selected,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'This is an estimate from SuiSakhi’s active rate card. Each Partner will inspect the garments and request your approval if the final care plan or price changes.',
                ),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () => setState(() => _cartOpen = false),
                icon: const Icon(Icons.add_shopping_cart_rounded),
                label: const Text('Continue shopping'),
              ),
            ],
          ),
    bottomNavigationBar: _items.isEmpty
        ? null
        : SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: FilledButton.icon(
                onPressed: _saving || _pricingLoading
                    ? null
                    : _pricingError != null
                    ? _loadPricing
                    : _submitOrder,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.local_laundry_service_outlined),
                label: Text(
                  _saving
                      ? 'Submitting…'
                      : _pricingError != null
                      ? 'Retry price estimate'
                      : 'Request pickups and inspection',
                ),
              ),
            ),
          ),
  );

  Widget _serviceOrderCard(String groupCode) {
    final group = GarmentCareServiceGroup.fromCode(groupCode);
    final items = _itemsForGroup(groupCode);
    final estimate = _estimateForGroup(groupCode);
    final pickupDate = _pickupDateForGroup(groupCode);
    final availablePickupSlots = _availablePickupSlotsForDate(pickupDate);
    final pickupSlot = _pickupSlotForGroup(groupCode, pickupDate);
    return Card(
      color: GarmentCareColors.surface,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${group?.label ?? 'Care service'} · ${items.length} garment entries',
              style: AppTextStyles.titleMedium.copyWith(
                color: GarmentCareColors.primaryDark,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            for (final item in items) ...[
              Builder(
                builder: (context) {
                  final index = _items.indexOf(item);
                  final services =
                      (item['serviceSteps'] as List<dynamic>? ?? const [])
                          .map((step) => Map<String, dynamic>.from(step as Map))
                          .where((step) => step['groupCode'] == groupCode)
                          .map(
                            (step) => GarmentCareServiceCatalog.labelFor(
                              step['serviceId'].toString(),
                            ),
                          )
                          .join(' → ');
                  return Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: GarmentCareColors.selected,
                          child: Icon(
                            Icons.checkroom_outlined,
                            color: GarmentCareColors.primary,
                          ),
                        ),
                        title: Text('${item['displayName']} · $services'),
                        subtitle: Text(_itemSummary(item)),
                        trailing: IconButton(
                          tooltip: 'Remove from cart',
                          onPressed: () {
                            setState(() => _items.removeAt(index));
                            _queueCartDraftSave();
                          },
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                      ),
                      _quantityStepper(cartIndex: index),
                    ],
                  );
                },
              ),
              const Divider(height: 12),
            ],
            Text(
              'Pickup for this service order',
              style: AppTextStyles.titleMedium,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final firstDate = _defaultPickupDate;
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: pickupDate.isBefore(firstDate)
                            ? firstDate
                            : pickupDate,
                        firstDate: firstDate,
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                      );
                      if (picked != null) {
                        final date = _dateOnly(picked);
                        final availableSlots = _availablePickupSlotsForDate(
                          date,
                        );
                        setState(() {
                          _pickupDatesByGroup[groupCode] = date;
                          final selectedSlot = _pickupSlotsByGroup[groupCode];
                          if (selectedSlot == null ||
                              !availableSlots.contains(selectedSlot)) {
                            if (availableSlots.isNotEmpty) {
                              _pickupSlotsByGroup[groupCode] =
                                  availableSlots.first;
                            } else {
                              _pickupSlotsByGroup.remove(groupCode);
                            }
                          }
                        });
                        _queueCartDraftSave();
                      }
                    },
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(
                      '${pickupDate.day}/${pickupDate.month}/${pickupDate.year}',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: pickupSlot,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Pickup window',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                    ),
                    items: availablePickupSlots
                        .map(
                          (slot) => DropdownMenuItem(
                            value: slot,
                            child: Text(
                              slot == '9:00 AM–1:00 PM'
                                  ? '9 AM–1 PM'
                                  : '4 PM–8 PM',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      final currentAvailable = _availablePickupSlotsForDate(
                        pickupDate,
                      );
                      if (!currentAvailable.contains(value)) {
                        final nextDate = _defaultPickupDate;
                        final nextSlots = _availablePickupSlotsForDate(
                          nextDate,
                        );
                        setState(() {
                          _pickupDatesByGroup[groupCode] = nextDate;
                          if (nextSlots.isNotEmpty) {
                            _pickupSlotsByGroup[groupCode] = nextSlots.first;
                          }
                        });
                        _queueCartDraftSave();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'That pickup window has started. Choose an available window.',
                            ),
                            duration: Duration(seconds: 2),
                          ),
                        );
                        return;
                      }
                      setState(() => _pickupSlotsByGroup[groupCode] = value);
                      _queueCartDraftSave();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (_pricingLoading)
              const LinearProgressIndicator()
            else if (_pricingError != null)
              Text(
                _pricingError!,
                style: TextStyle(color: GarmentCareColors.textSecondary),
              )
            else ...[
              _amountRow(
                _pricingModelVersion >= 2
                    ? 'Services (includes tax & delivery)'
                    : 'Services',
                estimate['subtotal'] ?? 0,
              ),
              if (_pricingModelVersion < 2)
                _amountRow('Tax', estimate['tax'] ?? 0),
              if (_logisticsAmount > 0)
                _amountRow('Additional pickup fee', estimate['logistics'] ?? 0),
              const Divider(height: 12),
              _amountRow(
                'Estimated total for ${group?.label ?? 'service group'}',
                estimate['total'] ?? 0,
                strong: true,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _cartGroupSummary() {
    final supportedGroups = GarmentCareServiceGroup.values.take(4).toList();
    final missingGroups = supportedGroups
        .where((group) => !_cartGroupCodes.contains(group.code))
        .map((group) => group.label)
        .toList(growable: false);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GarmentCareColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GarmentCareColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_items.length} garment entries · $_cartCount pieces · ${_cartGroupCodes.length} service groups',
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (missingGroups.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              'Not added yet: ${missingGroups.join(', ')}',
              style: AppTextStyles.bodySmall.copyWith(
                color: GarmentCareColors.textHint,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _amountRow(String label, double amount, {bool strong = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: strong
                    ? const TextStyle(fontWeight: FontWeight.w700)
                    : null,
              ),
            ),
            Text(
              _money(amount),
              style: strong
                  ? TextStyle(
                      color: GarmentCareColors.primary,
                      fontWeight: FontWeight.w700,
                    )
                  : null,
            ),
          ],
        ),
      );

  Widget _cartEstimateSummary() => Card(
    color: GarmentCareColors.surface,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Estimated total', style: AppTextStyles.titleMedium),
          const SizedBox(height: 8),
          if (_pricingLoading)
            const LinearProgressIndicator()
          else if (_pricingError != null) ...[
            Text(_pricingError!),
            TextButton.icon(
              onPressed: _loadPricing,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry estimate'),
            ),
          ] else ...[
            for (final code in _cartGroupCodes)
              _amountRow(
                GarmentCareServiceGroup.fromCode(code)?.label ??
                    'Service order',
                _estimateForGroup(code)['total'] ?? 0,
              ),
            const Divider(height: 16),
            _amountRow('Cart estimate', _estimatedTotal, strong: true),
          ],
        ],
      ),
    ),
  );

  Widget _pickupSection() {
    if (_loadingAddresses) return const LinearProgressIndicator();
    if (_addresses.isEmpty) {
      return Card(
        color: GarmentCareColors.surface,
        child: ListTile(
          leading: const Icon(
            Icons.location_on_outlined,
            color: GarmentCareColors.primary,
          ),
          title: const Text('Add a pickup address'),
          subtitle: const Text(
            'Choose a saved address before requesting pickup.',
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () async {
            await context.push('/customer-addresses');
            if (mounted) _loadAddresses();
          },
        ),
      );
    }
    Map<String, dynamic>? selected;
    for (final address in _addresses) {
      if (address['addressId'] == _pickupAddressId) selected = address;
    }
    return Card(
      color: GarmentCareColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pickup address', style: AppTextStyles.titleMedium),
            Text(
              'Pickup time is selected separately for each service order above.',
              style: AppTextStyles.bodySmall.copyWith(
                color: GarmentCareColors.textHint,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _pickupAddressId,
              decoration: const InputDecoration(labelText: 'Saved address'),
              items: _addresses
                  .map(
                    (address) => DropdownMenuItem<String>(
                      value: address['addressId']?.toString(),
                      child: Text(
                        address['addressType']?.toString() ?? 'Address',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() => _pickupAddressId = value);
                _queueCartDraftSave();
              },
            ),
            if (selected != null) ...[
              const SizedBox(height: 8),
              Text(selected['formattedAddress']?.toString() ?? ''),
            ],
            const Divider(height: 20),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.add_location_alt_outlined),
              title: const Text('Use a different or new address'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                await context.push('/customer-addresses');
                if (mounted) await _loadAddresses();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _activeOrderCard() => StreamBuilder(
    stream: GarmentCareService.customerOrders(),
    builder: (context, snapshot) {
      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
        return const SizedBox.shrink();
      }
      final order = snapshot.data!.docs.first;
      final data = order.data();
      final serviceCount = data['serviceCount'] ?? 0;
      final orderNumber = data['orderNumber']?.toString().trim() ?? '';
      final activeOrders = snapshot.data!.docs.where((doc) {
        final orderData = doc.data();
        final status = orderData['statusProjection']?.toString();
        return status != 'cancelled' &&
            (status != 'completed' ||
                orderData['paymentActionRequired'] == true);
      });
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final activeOrder in activeOrders)
            _CustomerOrderActionNotice(
              orderId: activeOrder.id,
              data: activeOrder.data(),
            ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: GarmentCareColors.divider),
            ),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Your latest Care request',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        color: GarmentCareColors.selected,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.local_laundry_service_outlined,
                        color: GarmentCareColors.primary,
                        size: 21,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${orderNumber.isEmpty ? 'Order number pending' : 'Order $orderNumber'} · $serviceCount service steps',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: GarmentCareColors.textSecondary,
                  ),
                ),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 4,
                  children: [
                    TextButton.icon(
                      onPressed: () => context.push('/garment-care/orders'),
                      icon: const Icon(Icons.receipt_long_outlined),
                      label: const Text('All orders'),
                    ),
                    TextButton.icon(
                      onPressed: () =>
                          context.push('/garment-care/orders?filter=active'),
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: const Text('View progress'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    },
  );

  String _itemSummary(Map<String, dynamic> item) {
    final serviceIds = (item['serviceIds'] as List<dynamic>? ?? const [])
        .map((id) => GarmentCareServiceCatalog.labelFor(id.toString()))
        .toList(growable: false);
    final group = GarmentCareServiceGroup.fromCode(
      item['groupCode']?.toString(),
    );
    return [
      if (group != null) group.label,
      serviceIds.join(' → '),
      if (item['hygieneWashRequested'] == true)
        'Hygiene wash requested if suitable',
    ].where((part) => part.isNotEmpty).join(' · ');
  }

  Widget _sectionTitle(String value) =>
      Text(value, style: AppTextStyles.titleMedium);

  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: controller,
      onChanged: (_) => setState(() {}),
      maxLines: lines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    required this.selected,
    required this.image,
    required this.onTap,
  });
  final GarmentCareServiceGroup group;
  final bool selected;
  final String image;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? GarmentCareColors.selected : Colors.white,
    borderRadius: BorderRadius.circular(24),
    child: InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? GarmentCareColors.primary : Colors.transparent,
            width: selected ? 1.5 : 1,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(11, 10, 11, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 91,
              width: double.infinity,
              child: Image.asset(image, fit: BoxFit.contain),
            ),
            const SizedBox(height: 7),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    _title(group),
                    maxLines: 3,
                    style: AppTextStyles.titleMedium.copyWith(
                      fontSize: 17,
                      height: 1.16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 3),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.arrow_forward_rounded,
                  color: GarmentCareColors.primary,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              _subtitle(group),
              maxLines: 2,
              style: AppTextStyles.bodySmall.copyWith(
                height: 1.18,
                color: GarmentCareColors.textHint,
              ),
            ),
            const Spacer(),
            Text(
              '${_serviceCount(group)} services',
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w500,
                color: GarmentCareColors.primary,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  String _title(GarmentCareServiceGroup value) => switch (value) {
    _ => value.label,
  };

  String _subtitle(GarmentCareServiceGroup value) => switch (value) {
    GarmentCareServiceGroup.specialTreatments =>
      'Stain removal, restoration & advanced care',
    GarmentCareServiceGroup.washingCleaning => 'Wash, dry clean & refresh',
    GarmentCareServiceGroup.pressingFinishing => 'Perfect press & neat finish',
    GarmentCareServiceGroup.designerLuxury =>
      'Sarees, bridal wear & delicate garments',
    _ => '',
  };

  int _serviceCount(GarmentCareServiceGroup value) => switch (value) {
    GarmentCareServiceGroup.washingCleaning => 4,
    GarmentCareServiceGroup.pressingFinishing => 3,
    GarmentCareServiceGroup.specialTreatments => 4,
    GarmentCareServiceGroup.designerLuxury => 4,
    _ => 0,
  };
}

String _groupArtwork(GarmentCareServiceGroup group) => switch (group) {
  GarmentCareServiceGroup.washingCleaning =>
    'assets/images/garment_care_group_laundry.png',
  GarmentCareServiceGroup.pressingFinishing =>
    'assets/images/garment_care_group_ironing.png',
  GarmentCareServiceGroup.specialTreatments =>
    'assets/images/garment_care_group_special.png',
  GarmentCareServiceGroup.designerLuxury =>
    'assets/images/garment_care_group_luxury.png',
  _ => 'assets/images/garment_care_group_laundry.png',
};

class _CareGroupSelection {
  const _CareGroupSelection({
    required this.serviceId,
    required this.itemTypeCode,
    required this.quantity,
    required this.includeHygieneWash,
    required this.displayName,
    required this.material,
    required this.conditionNotes,
    required this.careNotes,
    required this.starchLevel,
    this.previousDnaCopied = false,
    this.garmentId,
  });

  final String serviceId;
  final String itemTypeCode;
  final int quantity;
  final bool includeHygieneWash;
  final String displayName;
  final String material;
  final String conditionNotes;
  final String careNotes;
  final String? starchLevel;
  final bool previousDnaCopied;
  final String? garmentId;
}

class _CareDnaPrefill {
  const _CareDnaPrefill({
    required this.displayName,
    required this.itemTypeCode,
    required this.material,
    required this.conditionNotes,
    required this.careNotes,
  });

  final String displayName;
  final String itemTypeCode;
  final String material;
  final String conditionNotes;
  final String careNotes;
}

_CareDnaPrefill _careDnaPrefillFromPreviousOrder(
  Map<String, dynamic> order, {
  required String groupCode,
  String? serviceId,
}) {
  final rawRecord = order['garmentRecord'];
  final record = rawRecord is Map
      ? Map<String, dynamic>.from(rawRecord)
      : <String, dynamic>{};
  final rawMaterial = record['material'];
  final materialData = rawMaterial is Map
      ? Map<String, dynamic>.from(rawMaterial)
      : <String, dynamic>{};
  final displayName = (record['garmentType'] ?? order['dressType'] ?? '')
      .toString()
      .trim();
  final normalizedName = displayName.toLowerCase();
  final itemTypes = GarmentCareCatalogMetadata.itemTypesForGroup(
    groupCode,
    serviceId: serviceId,
  );
  String? itemTypeCode;
  for (final entry in itemTypes.entries) {
    if (entry.value.toLowerCase() == normalizedName ||
        entry.key.replaceAll('_', ' ') == normalizedName) {
      itemTypeCode = entry.key;
      break;
    }
  }
  if (serviceId == 'leather_suede_fur_care') {
    if (normalizedName.contains('rexine') ||
        normalizedName.contains('faux leather')) {
      itemTypeCode = 'rexine_faux_leather';
    } else if (normalizedName.contains('suede')) {
      itemTypeCode = 'suede';
    } else if (normalizedName.contains('leather')) {
      itemTypeCode = 'leather';
    } else if (normalizedName.contains('fur')) {
      itemTypeCode = 'fur';
    }
  }

  final materialParts = <String>[
    materialData['customerSelection']?.toString() ?? '',
    materialData['customerDescription']?.toString() ?? '',
    materialData['fiberComposition']?.toString() ?? '',
  ].map((value) => value.trim()).where((value) => value.isNotEmpty).toList();
  final material = materialParts.join(' · ');
  final qualityNotes = record['qualityCheckNotes']?.toString().trim() ?? '';
  final conditionNotes = qualityNotes.isEmpty
      ? ''
      : 'Previous quality check (please verify current condition): $qualityNotes';
  final careNotes = (materialData['careInstructions']?.toString() ?? '').trim();

  return _CareDnaPrefill(
    displayName: displayName.isEmpty ? 'Previous garment' : displayName,
    itemTypeCode: itemTypeCode ?? 'other',
    material: material.length > 120 ? material.substring(0, 120) : material,
    conditionNotes: conditionNotes.length > 1000
        ? conditionNotes.substring(0, 1000)
        : conditionNotes,
    careNotes: careNotes.length > 1000
        ? careNotes.substring(0, 1000)
        : careNotes,
  );
}

class _GarmentCareGroupSelectionScreen extends StatefulWidget {
  const _GarmentCareGroupSelectionScreen({
    required this.group,
    required this.cartCount,
    required this.onCartTap,
  });

  final GarmentCareServiceGroup group;
  final int cartCount;
  final VoidCallback onCartTap;

  @override
  State<_GarmentCareGroupSelectionScreen> createState() =>
      _GarmentCareGroupSelectionScreenState();
}

class _GarmentCareGroupSelectionScreenState
    extends State<_GarmentCareGroupSelectionScreen> {
  static const _hygieneCompatibleServices = <String>{
    'wash_fold',
    'wash_iron',
    'premium_wet_cleaning',
  };
  static const _maxQuantity = 20;

  final _displayName = TextEditingController();
  final _material = TextEditingController();
  final _condition = TextEditingController();
  final _careNotes = TextEditingController();
  String? _serviceId;
  String? _starchLevel;
  String? _garmentId;
  bool _previousDnaCopied = false;
  String _itemTypeCode = '';
  int _quantity = 1;
  bool _includeHygieneWash = false;

  @override
  void dispose() {
    _displayName.dispose();
    _material.dispose();
    _condition.dispose();
    _careNotes.dispose();
    super.dispose();
  }

  List<String> get _serviceIds => switch (widget.group) {
    GarmentCareServiceGroup.washingCleaning => const [
      'wash_fold',
      'wash_iron',
      'premium_wet_cleaning',
      'dry_cleaning',
    ],
    GarmentCareServiceGroup.pressingFinishing => const [
      'steam_ironing',
      'roll_pressing',
      'form_pressing',
    ],
    GarmentCareServiceGroup.specialTreatments => const [
      'advanced_stain_removal',
      'fabric_starching',
      'saree_polishing',
      'fabric_conditioning',
    ],
    GarmentCareServiceGroup.designerLuxury => const [
      'couture_care',
      'bridal_care',
      'embellishment_protection',
      'leather_suede_fur_care',
    ],
    _ => const [],
  };

  Map<String, String> get _itemTypes =>
      GarmentCareCatalogMetadata.itemTypesForGroup(
        widget.group.code,
        serviceId: _serviceId,
      );

  String get _selectedServiceTitle => _serviceTitle(_serviceId ?? '');

  Future<void> _useSavedGarment() async {
    try {
      final garments = await GarmentCareService.savedGarments();
      if (!mounted) return;
      final selected = await showModalBottomSheet<GarmentCareIdentity>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(16),
            children: [
              Text('Use a saved garment', style: AppTextStyles.titleMedium),
              if (garments.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No saved Garment DNA records yet.'),
                ),
              for (final garment in garments)
                ListTile(
                  leading: const Icon(Icons.checkroom_outlined),
                  title: Text(garment.displayName),
                  subtitle: Text(
                    [
                      garment.itemTypeCode,
                      garment.material,
                    ].where((value) => value?.isNotEmpty == true).join(' · '),
                  ),
                  onTap: () => Navigator.pop(sheetContext, garment),
                ),
            ],
          ),
        ),
      );
      if (selected == null || !mounted) return;
      setState(() {
        _garmentId = selected.garmentId;
        _previousDnaCopied = false;
        _displayName.text = selected.displayName;
        _itemTypeCode = _itemTypes.containsKey(selected.itemTypeCode)
            ? selected.itemTypeCode
            : 'other';
        _material.text = selected.material ?? '';
        _condition.clear();
        _careNotes.text = selected.careLabel ?? '';
        _quantity = 1;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load saved garments.')),
        );
      }
    }
  }

  Future<void> _usePreviousGarment() async {
    try {
      final records = await GarmentCareService.legacyGarmentReferences();
      if (!mounted) return;
      final selected = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Use a previous SuiSakhi garment',
                style: AppTextStyles.titleMedium,
              ),
              if (records.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No previous Garment DNA records are available.'),
                ),
              for (final record in records)
                ListTile(
                  leading: const Icon(Icons.history_rounded),
                  title: Text(record['dressType']?.toString() ?? 'Garment'),
                  subtitle: Text(
                    'Order ${record['orderTrackingId'] ?? record['id']}',
                  ),
                  onTap: () => Navigator.pop(sheetContext, record),
                ),
            ],
          ),
        ),
      );
      if (selected == null || !mounted) return;
      final prefill = _careDnaPrefillFromPreviousOrder(
        selected,
        groupCode: widget.group.code,
        serviceId: _serviceId,
      );
      setState(() {
        _garmentId = null;
        _previousDnaCopied = true;
        _displayName.text = prefill.displayName;
        _itemTypeCode = _itemTypes.containsKey(prefill.itemTypeCode)
            ? prefill.itemTypeCode
            : 'other';
        _material.text = prefill.material;
        _condition.text = prefill.conditionNotes;
        _careNotes.text = prefill.careNotes;
        _quantity = 1;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not load previous garment records.'),
          ),
        );
      }
    }
  }

  void _submitSelection() {
    final serviceId = _serviceId;
    if (serviceId == null || !_itemTypes.containsKey(_itemTypeCode)) return;
    Navigator.of(context).pop(
      _CareGroupSelection(
        serviceId: serviceId,
        itemTypeCode: _itemTypes.containsKey(_itemTypeCode)
            ? _itemTypeCode
            : 'other',
        quantity: _quantity,
        includeHygieneWash:
            _includeHygieneWash &&
            _hygieneCompatibleServices.contains(serviceId),
        displayName: _displayName.text.trim(),
        material: _material.text.trim(),
        conditionNotes: _condition.text.trim(),
        careNotes: _careNotes.text.trim(),
        starchLevel: _starchLevel,
        previousDnaCopied: _previousDnaCopied,
        garmentId: _garmentId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final serviceId = _serviceId;
    final canAddHygiene =
        serviceId != null && _hygieneCompatibleServices.contains(serviceId);
    return GarmentCareTheme(
      child: Scaffold(
        backgroundColor: GarmentCareColors.background,
        appBar: AppBar(
          toolbarHeight: 72,
          titleSpacing: 0,
          leading: IconButton(
            tooltip: 'Back to services',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SUISAKHI GARMENT CARE',
                style: AppTextStyles.labelMedium.copyWith(
                  color: GarmentCareColors.primary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: .7,
                ),
              ),
              Text(
                widget.group.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.titleMedium.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Shopping bag (${widget.cartCount} items)',
              onPressed: widget.onCartTap,
              icon: Badge(
                isLabelVisible: widget.cartCount > 0,
                label: Text('${widget.cartCount}'),
                child: const Icon(Icons.shopping_bag_outlined),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          children: [
            Text(
              _groupDescription(widget.group),
              style: AppTextStyles.bodyMedium.copyWith(
                color: GarmentCareColors.textHint,
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: [
                for (final id in _serviceIds)
                  _CareServiceOptionCard(
                    serviceId: id,
                    title: _serviceTitle(id),
                    description: _serviceDescription(id),
                    selected: _serviceId == id,
                    onTap: () => setState(() {
                      _serviceId = id;
                      if (!_hygieneCompatibleServices.contains(id)) {
                        _includeHygieneWash = false;
                      }
                      if (!_itemTypes.containsKey(_itemTypeCode)) {
                        _itemTypeCode = 'other';
                        _displayName.clear();
                      }
                    }),
                  ),
              ],
            ),
            if (serviceId != null) ...[
              const SizedBox(height: 18),
              const Divider(),
              const SizedBox(height: 12),
              Text(
                _garmentQuestion(widget.group),
                style: AppTextStyles.titleMedium,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _itemTypes.containsKey(_itemTypeCode)
                    ? _itemTypeCode
                    : null,
                decoration: InputDecoration(
                  labelText: 'Garment type',
                  hintText: 'Choose garment type',
                  filled: true,
                  fillColor: GarmentCareColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: const BorderSide(
                      color: GarmentCareColors.divider,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: const BorderSide(
                      color: GarmentCareColors.divider,
                    ),
                  ),
                ),
                items: _itemTypes.entries
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() {
                  _itemTypeCode = value ?? '';
                  if (value == 'other') {
                    _displayName.clear();
                  } else if (value != null) {
                    _displayName.text = GarmentCareCatalogMetadata.itemLabel(
                      widget.group.code,
                      value,
                      serviceId: _serviceId,
                    );
                  }
                }),
              ),
              if (_itemTypeCode == 'other') ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _displayName,
                  decoration: const InputDecoration(
                    labelText: 'Describe the garment (optional)',
                    hintText: 'e.g. embroidered dupatta',
                  ),
                ),
              ],
              const SizedBox(height: 8),
              _quantityControl(),
              const SizedBox(height: 8),
              if (canAddHygiene)
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(
                    () => _includeHygieneWash = !_includeHygieneWash,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _includeHygieneWash,
                          onChanged: (value) => setState(
                            () => _includeHygieneWash = value ?? false,
                          ),
                        ),
                        const Expanded(
                          child: Text('Add hygiene wash, if suitable'),
                        ),
                      ],
                    ),
                  ),
                ),
              if (canAddHygiene) const SizedBox(height: 8),
              Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: GarmentCareColors.surface,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: GarmentCareColors.divider),
                ),
                child: Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor: Colors.transparent,
                    inputDecorationTheme: Theme.of(context).inputDecorationTheme
                        .copyWith(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: const BorderSide(
                              color: GarmentCareColors.divider,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: const BorderSide(
                              color: GarmentCareColors.divider,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: const BorderSide(
                              color: GarmentCareColors.primary,
                              width: 1.5,
                            ),
                          ),
                        ),
                  ),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 14),
                    childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    iconColor: GarmentCareColors.primary,
                    collapsedIconColor: GarmentCareColors.primary,
                    shape: const Border(),
                    collapsedShape: const Border(),
                    leading: const Icon(Icons.notes_rounded),
                    title: Text(
                      'Fabric details or care instructions (optional)',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: GarmentCareColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'Share material, stains or care preferences',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: GarmentCareColors.textHint,
                      ),
                    ),
                    children: [
                      Text(
                        'These details help your Partner handle the garment with care.',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: GarmentCareColors.textHint,
                        ),
                      ),
                      Wrap(
                        spacing: 4,
                        children: [
                          TextButton.icon(
                            onPressed: _useSavedGarment,
                            icon: const Icon(Icons.checkroom_outlined),
                            label: const Text('Saved garment'),
                          ),
                          TextButton.icon(
                            onPressed: _usePreviousGarment,
                            icon: const Icon(Icons.history_rounded),
                            label: const Text('Previous Garment DNA'),
                          ),
                        ],
                      ),
                      if (_garmentId != null)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text(
                            'This saved physical garment is linked; quantity is limited to one.',
                          ),
                        ),
                      if (_previousDnaCopied)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Previous Garment DNA was copied into these editable fields. Check the current condition before ordering.',
                          ),
                        ),
                      DropdownButtonFormField<String>(
                        initialValue:
                            GarmentCareCatalogMetadata.materialTypes.contains(
                              _material.text,
                            )
                            ? _material.text
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Fabric / material (optional)',
                          hintText: 'Select if known',
                        ),
                        items: GarmentCareCatalogMetadata.materialTypes
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(() {
                          _material.text = value == 'Other' ? '' : value ?? '';
                        }),
                      ),
                      if (_material.text.isEmpty ||
                          !GarmentCareCatalogMetadata.materialTypes.contains(
                            _material.text,
                          ))
                        TextField(
                          controller: _material,
                          decoration: const InputDecoration(
                            labelText: 'Other material (optional)',
                          ),
                        ),
                      TextField(
                        controller: _condition,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Stain or damage (optional)',
                          hintText: 'Only if there is something to report',
                        ),
                      ),
                      TextField(
                        controller: _careNotes,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Care instructions (optional)',
                          hintText: 'Anything you want the Partner to know',
                        ),
                      ),
                      if (serviceId == 'fabric_starching') ...[
                        DropdownButtonFormField<String>(
                          initialValue: _starchLevel,
                          decoration: const InputDecoration(
                            labelText: 'Starch level (optional)',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'none',
                              child: Text('No starch'),
                            ),
                            DropdownMenuItem(
                              value: 'light',
                              child: Text('Light'),
                            ),
                            DropdownMenuItem(
                              value: 'medium',
                              child: Text('Medium'),
                            ),
                            DropdownMenuItem(
                              value: 'heavy',
                              child: Text('Heavy'),
                            ),
                            DropdownMenuItem(
                              value: 'recommended',
                              child: Text('Recommended by care guide'),
                            ),
                          ],
                          onChanged: (value) =>
                              setState(() => _starchLevel = value),
                        ),
                        if (_starchLevel == 'recommended')
                          Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 8),
                            child: Text(
                              GarmentCareGuidance.starchingRecommendation(
                                _material.text.trim(),
                              ),
                              style: AppTextStyles.bodySmall.copyWith(
                                color: GarmentCareColors.textHint,
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your selection',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$_quantity × ${_itemTypes[_itemTypeCode] ?? 'Garment'} · $_selectedServiceTitle',
                    ),
                    if (_includeHygieneWash && canAddHygiene)
                      const Text('Hygiene wash requested, if suitable.'),
                    if (widget.group ==
                            GarmentCareServiceGroup.specialTreatments ||
                        widget.group ==
                            GarmentCareServiceGroup.designerLuxury) ...[
                      const SizedBox(height: 5),
                      Text(
                        'Final treatment and price may require inspection and your approval.',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: GarmentCareColors.textHint,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
        bottomNavigationBar: serviceId == null
            ? null
            : SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF111111),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  onPressed: _itemTypes.containsKey(_itemTypeCode)
                      ? _submitSelection
                      : null,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add to cart'),
                ),
              ),
      ),
    );
  }

  Widget _quantityControl() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: GarmentCareColors.surface,
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: GarmentCareColors.divider),
    ),
    child: Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Quantity', style: TextStyle(fontWeight: FontWeight.w600)),
              Text(
                'Number of garments',
                style: TextStyle(
                  fontSize: 12,
                  color: GarmentCareColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        _quantityButton(
          Icons.remove_rounded,
          enabled: _quantity > 1 && _garmentId == null,
          onTap: () => setState(() => _quantity--),
          tooltip: 'Decrease quantity',
        ),
        SizedBox(
          width: 42,
          child: Text(
            '$_quantity',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ),
        _quantityButton(
          Icons.add_rounded,
          enabled: _quantity < _maxQuantity && _garmentId == null,
          onTap: () => setState(() => _quantity++),
          tooltip: 'Increase quantity',
        ),
      ],
    ),
  );

  Widget _quantityButton(
    IconData icon, {
    required bool enabled,
    required VoidCallback onTap,
    required String tooltip,
  }) => Tooltip(
    message: tooltip,
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: enabled ? onTap : null,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: enabled ? GarmentCareColors.divider : Colors.black12,
          ),
        ),
        child: Icon(
          icon,
          color: enabled ? GarmentCareColors.textSecondary : Colors.black26,
          size: 21,
        ),
      ),
    ),
  );

  String _groupDescription(GarmentCareServiceGroup group) => switch (group) {
    GarmentCareServiceGroup.washingCleaning =>
      'Select how you want your clothes cared for.',
    GarmentCareServiceGroup.pressingFinishing =>
      'Choose how you want your garments finished.',
    GarmentCareServiceGroup.specialTreatments =>
      'Special attention for stains, sarees and fabric care.',
    GarmentCareServiceGroup.designerLuxury =>
      'Expert care for your most precious outfits.',
    _ => '',
  };

  String _garmentQuestion(GarmentCareServiceGroup group) => switch (group) {
    GarmentCareServiceGroup.washingCleaning => 'What are we cleaning?',
    GarmentCareServiceGroup.pressingFinishing => 'What are we ironing?',
    GarmentCareServiceGroup.specialTreatments => 'What needs special care?',
    GarmentCareServiceGroup.designerLuxury =>
      'What would you like us to care for?',
    _ => 'What garment are we caring for?',
  };

  String _serviceTitle(String serviceId) => switch (serviceId) {
    'wash_fold' => 'Wash & Fold',
    'wash_iron' => 'Wash & Iron',
    'premium_wet_cleaning' => 'Gentle / Premium Clean',
    'dry_cleaning' => 'Dry Cleaning',
    'form_pressing' => 'Form Pressing',
    'advanced_stain_removal' => 'Stain Removal',
    'fabric_conditioning' => 'Fabric Softening',
    'couture_care' => 'Designer Wear',
    'bridal_care' => 'Bridal Wear',
    'embellishment_protection' => 'Zari & Embroidery',
    'leather_suede_fur_care' => 'Leather & Suede',
    _ => GarmentCareServiceCatalog.labelFor(serviceId),
  };

  String _serviceDescription(String serviceId) => switch (serviceId) {
    'wash_fold' => 'Clean, dry and fold',
    'wash_iron' => 'Clean, dry and press',
    'premium_wet_cleaning' => 'For delicate garments',
    'dry_cleaning' => 'Professional garment care',
    'steam_ironing' => 'Gentle steam press',
    'roll_pressing' => 'Smooth, crisp finish',
    'form_pressing' => 'Shape-friendly finish',
    'advanced_stain_removal' => 'Treat difficult stains',
    'fabric_starching' => 'Crisp fabric finish',
    'saree_polishing' => 'Refresh saree finish',
    'fabric_conditioning' => 'Gentle fabric care',
    'couture_care' => 'Premium garment care',
    'bridal_care' => 'Wedding outfits and sarees',
    'embellishment_protection' => 'Delicate detailing care',
    'leather_suede_fur_care' => 'Specialist material care',
    _ => 'Care selected for this garment',
  };
}

class _CareServiceOptionCard extends StatelessWidget {
  const _CareServiceOptionCard({
    required this.serviceId,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final String serviceId;
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    color: selected ? GarmentCareColors.selected : GarmentCareColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(
        color: selected ? GarmentCareColors.primary : GarmentCareColors.divider,
        width: selected ? 1.5 : 0.8,
      ),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _serviceEmoji(serviceId),
                  style: const TextStyle(fontSize: 24),
                ),
                const Spacer(),
                if (selected)
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    color: GarmentCareColors.primary,
                    size: 19,
                  ),
              ],
            ),
            const Spacer(),
            Text(
              title,
              maxLines: 2,
              style: AppTextStyles.titleMedium.copyWith(
                fontSize: 16,
                height: 1.18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              description,
              maxLines: 2,
              style: AppTextStyles.bodyMedium.copyWith(
                fontSize: 13,
                height: 1.2,
                color: GarmentCareColors.textHint,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  String _serviceEmoji(String id) => switch (id) {
    'wash_fold' => '🧺',
    'wash_iron' => '👔',
    'premium_wet_cleaning' => '🌸',
    'dry_cleaning' => '🧥',
    'steam_ironing' => '♨️',
    'roll_pressing' => '🧺',
    'form_pressing' => '👔',
    'advanced_stain_removal' => '✨',
    'fabric_starching' => '👕',
    'saree_polishing' => '👗',
    'fabric_conditioning' => '🌸',
    'couture_care' => '👗',
    'bridal_care' => '👘',
    'embellishment_protection' => '✨',
    'leather_suede_fur_care' => '🧥',
    _ => '👚',
  };
}

class _CustomerOrderActionNotice extends StatefulWidget {
  const _CustomerOrderActionNotice({required this.orderId, required this.data});

  final String orderId;
  final Map<String, dynamic> data;

  @override
  State<_CustomerOrderActionNotice> createState() =>
      _CustomerOrderActionNoticeState();
}

class _CustomerOrderActionNoticeState
    extends State<_CustomerOrderActionNotice> {
  bool _expanded = false;

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: GarmentCareService.customerJobs(widget.orderId),
    builder: (context, snapshot) {
      if (snapshot.hasError || !snapshot.hasData) {
        return const SizedBox.shrink();
      }
      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: GarmentCareService.customerShipments(widget.orderId),
        builder: (context, shipmentSnapshot) {
          if (shipmentSnapshot.hasError || !shipmentSnapshot.hasData) {
            return const SizedBox.shrink();
          }
          final jobs = snapshot.data!.docs;
          final alerts = <_CareCustomerAlert>[];
          final awaitingConsent = jobs
              .where((job) => job.data()['status'] == 'awaitingConsent')
              .length;
          final awaitingEdit = jobs
              .where((job) => job.data()['status'] == 'awaitingCustomerEdit')
              .length;
          final declinedServices = jobs
              .where((job) => job.data()['status'] == 'rejected')
              .length;

          if (awaitingConsent > 0) {
            alerts.add(
              _CareCustomerAlert(
                title: 'Review inspection and final price',
                message:
                    'Your Partner sent an inspection update. Approve or decline so care can continue.',
                requiresAction: true,
              ),
            );
          }
          if (awaitingEdit > 0) {
            alerts.add(
              _CareCustomerAlert(
                title: 'Choose how to continue',
                message:
                    'Your Partner requested a service change. Review the garment and choose an option.',
                requiresAction: true,
              ),
            );
          }

          final pickup = shipmentSnapshot.data!.docs.where(
            (shipment) => shipment.data()['shipmentType'] == 'customer_pickup',
          );
          if (pickup.isNotEmpty) {
            final pickupData = pickup.first.data();
            final rejectedGarments =
                (pickupData['rejectedGarmentIds'] as List<dynamic>? ?? const [])
                    .map((id) => id.toString())
                    .where((id) => id.isNotEmpty)
                    .toSet()
                    .length;
            if (rejectedGarments > 0 || pickupData['status'] == 'failed') {
              final count = rejectedGarments > 0 ? rejectedGarments : 1;
              alerts.add(
                _CareCustomerAlert(
                  title:
                      'Partner could not collect $count ${count == 1 ? 'garment' : 'garments'}',
                  message:
                      'These garments stayed with you and were removed from this order. We will not reassign them. Place a new order if you want care for them.',
                  requiresAction: false,
                ),
              );
            }
          }

          if (declinedServices > 0) {
            alerts.add(
              _CareCustomerAlert(
                title:
                    'Partner declined ${declinedServices == 1 ? 'a service' : '$declinedServices services'}',
                message:
                    'We are finding another Partner for this service. No action is needed right now.',
                requiresAction: false,
              ),
            );
          }

          final jobsByDeliveryGroup = <String, List<String>>{};
          for (final job in jobs) {
            final jobData = job.data();
            final groupId = jobData['deliveryGroupId']?.toString() ?? '';
            final status = jobData['status']?.toString() ?? '';
            if (groupId.isEmpty || status.isEmpty) continue;
            jobsByDeliveryGroup.putIfAbsent(groupId, () => []).add(status);
          }
          final hasCompletedSubOrder = jobsByDeliveryGroup.values.any(
            (statuses) =>
                statuses.isNotEmpty &&
                statuses.every(
                  (status) =>
                      ['completed', 'cancelled', 'blocked'].contains(status),
                ),
          );
          if (widget.data['paymentActionRequired'] == true &&
              hasCompletedSubOrder) {
            alerts.add(
              const _CareCustomerAlert(
                title: 'Payment is due for a completed garment',
                message:
                    'Pay the combined service-order invoice to unlock delivery for ready garments. Other garments can continue through care.',
                requiresAction: true,
              ),
            );
          }

          if (alerts.isEmpty) return const SizedBox.shrink();
          final needsAction = alerts.any((alert) => alert.requiresAction);
          final orderNumber =
              widget.data['orderNumber']?.toString().trim() ?? '';
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: needsAction ? const Color(0xFFFFF1F7) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: needsAction
                    ? GarmentCareColors.primary
                    : GarmentCareColors.divider,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Row(
                    children: [
                      Icon(
                        needsAction
                            ? Icons.notifications_active_outlined
                            : Icons.info_outline_rounded,
                        color: GarmentCareColors.primary,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              needsAction
                                  ? 'Needs your attention'
                                  : 'Care update',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              [
                                if (orderNumber.isNotEmpty)
                                  'Order $orderNumber',
                                alerts.first.title,
                                if (alerts.length > 1)
                                  '${alerts.length} updates',
                              ].join(' · '),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: GarmentCareColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.push(
                          '/garment-care/orders/${widget.orderId}',
                        ),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          minimumSize: const Size(48, 36),
                        ),
                        child: Text(needsAction ? 'Review' : 'View'),
                      ),
                      Icon(
                        _expanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        color: GarmentCareColors.textSecondary,
                      ),
                    ],
                  ),
                ),
                if (_expanded) ...[
                  const Divider(height: 16),
                  for (final alert in alerts)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8, left: 30),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            alert.title,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            alert.message,
                            style: const TextStyle(height: 1.25),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          );
        },
      );
    },
  );
}

class _CareCustomerAlert {
  const _CareCustomerAlert({
    required this.title,
    required this.message,
    required this.requiresAction,
  });

  final String title;
  final String message;
  final bool requiresAction;
}

class GarmentCareOrdersScreen extends StatefulWidget {
  const GarmentCareOrdersScreen({
    super.key,
    this.orderId,
    this.activeOnly = false,
  });
  final String? orderId;
  final bool activeOnly;

  @override
  State<GarmentCareOrdersScreen> createState() =>
      _GarmentCareOrdersScreenState();
}

class _GarmentCareOrdersScreenState extends State<GarmentCareOrdersScreen> {
  static const _pageSize = 10;
  final _searchController = TextEditingController();
  String _searchText = '';
  int _activeVisibleCount = _pageSize;
  int _pastVisibleCount = _pageSize;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.orderId != null) {
      return _CareOrderDetail(orderId: widget.orderId!);
    }
    final tabCount = widget.activeOnly ? 1 : 2;
    return DefaultTabController(
      length: tabCount,
      child: GarmentCareTheme(
        child: Scaffold(
          backgroundColor: GarmentCareColors.background,
          appBar: AppBar(
            title: Text(
              widget.activeOnly
                  ? 'Active Garment Care Orders'
                  : 'My Garment Care Orders',
            ),
          ),
          body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: GarmentCareService.customerOrders(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                  child: Text('Could not load your Garment Care orders.'),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final allOrders = snapshot.data!.docs;
              final activeOrders = allOrders.where((order) {
                final data = order.data();
                final status = data['statusProjection']?.toString();
                return !{'completed', 'cancelled'}.contains(status) ||
                    data['paymentActionRequired'] == true;
              }).toList()..sort(_compareActiveOrders);
              final pastOrders = allOrders
                  .where((order) {
                    final data = order.data();
                    final status = data['statusProjection']?.toString();
                    return {'completed', 'cancelled'}.contains(status) &&
                        data['paymentActionRequired'] != true;
                  })
                  .toList(growable: false);
              final query = _searchText.trim().toLowerCase();
              final filteredActive = _filterOrders(activeOrders, query);
              final filteredPast = _filterOrders(pastOrders, query);

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _searchText = value),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Search by order number',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _searchText.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchText = '');
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: widget.activeOnly
                        ? _buildOrderList(
                            context,
                            filteredActive,
                            isActive: true,
                            query: query,
                          )
                        : Column(
                            children: [
                              TabBar(
                                labelColor: GarmentCareColors.primary,
                                unselectedLabelColor:
                                    GarmentCareColors.textSecondary,
                                indicatorColor: GarmentCareColors.primary,
                                tabs: [
                                  Tab(text: 'Active (${activeOrders.length})'),
                                  Tab(
                                    text: 'Past orders (${pastOrders.length})',
                                  ),
                                ],
                              ),
                              Expanded(
                                child: TabBarView(
                                  children: [
                                    _buildOrderList(
                                      context,
                                      filteredActive,
                                      isActive: true,
                                      query: query,
                                    ),
                                    _buildOrderList(
                                      context,
                                      filteredPast,
                                      isActive: false,
                                      query: query,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              );
            },
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => context.push('/garment-care'),
            icon: const Icon(Icons.add_rounded),
            label: const Text('New Care Order'),
          ),
        ),
      ),
    );
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filterOrders(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> orders,
    String query,
  ) {
    if (query.isEmpty) return orders;
    return orders
        .where((order) {
          final orderNumber = order
              .data()['orderNumber']
              ?.toString()
              .toLowerCase();
          return orderNumber?.contains(query) == true;
        })
        .toList(growable: false);
  }

  int _compareActiveOrders(
    QueryDocumentSnapshot<Map<String, dynamic>> left,
    QueryDocumentSnapshot<Map<String, dynamic>> right,
  ) {
    int priority(QueryDocumentSnapshot<Map<String, dynamic>> order) {
      final data = order.data();
      final status = data['statusProjection']?.toString();
      if (data['paymentActionRequired'] == true ||
          {'customer_action_required', 'awaiting_payment'}.contains(status)) {
        return 0;
      }
      if (status == 'pickup_partial') return 1;
      return 2;
    }

    final priorityComparison = priority(left).compareTo(priority(right));
    if (priorityComparison != 0) return priorityComparison;
    final leftCreatedAt = left.data()['createdAt'];
    final rightCreatedAt = right.data()['createdAt'];
    final leftTime = leftCreatedAt is Timestamp
        ? leftCreatedAt
        : Timestamp(0, 0);
    final rightTime = rightCreatedAt is Timestamp
        ? rightCreatedAt
        : Timestamp(0, 0);
    return rightTime.compareTo(leftTime);
  }

  Widget _buildOrderList(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> orders, {
    required bool isActive,
    required String query,
  }) {
    if (orders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            query.isNotEmpty
                ? 'No orders match that order number.'
                : isActive
                ? 'No active orders. Your completed orders are in Past orders.'
                : 'No past orders yet.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final visibleLimit = isActive ? _activeVisibleCount : _pastVisibleCount;
    final visibleCount = orders.length < visibleLimit
        ? orders.length
        : visibleLimit;
    final hasMore = visibleCount < orders.length;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: visibleCount + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == visibleCount) {
          return Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            child: Center(
              child: OutlinedButton.icon(
                onPressed: () => setState(() {
                  if (isActive) {
                    _activeVisibleCount += _pageSize;
                  } else {
                    _pastVisibleCount += _pageSize;
                  }
                }),
                icon: const Icon(Icons.expand_more_rounded),
                label: Text(
                  isActive ? 'Load 10 more orders' : 'Load 10 older orders',
                ),
              ),
            ),
          );
        }

        final doc = orders[index];
        final data = doc.data();
        final group = GarmentCareServiceGroup.fromCode(
          data['serviceGroupCode']?.toString(),
        );
        final orderNumber = data['orderNumber']?.toString().isNotEmpty == true
            ? data['orderNumber'].toString()
            : 'Order number pending';
        final placedAt = data['createdAt'] is Timestamp
            ? _formatCareTimestamp(data['createdAt'] as Timestamp)
            : '';
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: GarmentCareService.customerJobs(doc.id),
          builder: (context, jobsSnapshot) {
            final jobs = jobsSnapshot.data?.docs ?? const [];
            final hasPendingDecision = jobs.any(
              (job) => [
                'awaitingConsent',
                'awaitingCustomerEdit',
              ].contains(job.data()['status']),
            );
            final needsAction =
                hasPendingDecision ||
                data['paymentActionRequired'] == true ||
                data['statusProjection'] == 'customer_action_required';
            return Card(
              color: Colors.white,
              child: ListTile(
                leading: const Icon(
                  Icons.local_laundry_service_outlined,
                  color: GarmentCareColors.primary,
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${group?.label ?? 'Garment Care'} · $orderNumber',
                      ),
                    ),
                    if (needsAction)
                      const Icon(
                        Icons.notification_important_outlined,
                        color: GarmentCareColors.primary,
                        size: 20,
                      ),
                  ],
                ),
                subtitle: Text(
                  [
                    '${data['itemCount'] ?? 0} garments · ${_projectionLabel(data['statusProjection']?.toString())}',
                    if (needsAction) 'Action needed · Review your order',
                    if (placedAt.isNotEmpty) 'Placed $placedAt',
                  ].join('\n'),
                ),
                trailing: needsAction
                    ? const Text(
                        'Review',
                        style: TextStyle(
                          color: GarmentCareColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/garment-care/orders/${doc.id}'),
              ),
            );
          },
        );
      },
    );
  }
}

class _CareOrderDetail extends StatefulWidget {
  const _CareOrderDetail({required this.orderId});
  final String orderId;

  @override
  State<_CareOrderDetail> createState() => _CareOrderDetailState();
}

class _CareOrderDetailState extends State<_CareOrderDetail> {
  String get orderId => widget.orderId;

  @override
  void initState() {
    super.initState();
    _ensureSubOrderNumbers();
  }

  @override
  void didUpdateWidget(covariant _CareOrderDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orderId != widget.orderId) _ensureSubOrderNumbers();
  }

  void _ensureSubOrderNumbers() {
    unawaited(
      GarmentCareService.ensureSubOrderNumbers(orderId).catchError((_) {}),
    );
  }

  @override
  Widget build(BuildContext context) => GarmentCareTheme(
    child: Scaffold(
      backgroundColor: GarmentCareColors.background,
      appBar: AppBar(title: const Text('Track Garment Care')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('garment_care_orders')
            .doc(orderId)
            .snapshots(),
        builder: (context, orderSnapshot) {
          if (orderSnapshot.hasError) {
            return const Center(child: Text('Could not load this order.'));
          }
          if (!orderSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = orderSnapshot.data!.data();
          if (data == null) {
            return const Center(child: Text('Order not found.'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'ORDER ${data['orderNumber']?.toString().isNotEmpty == true ? data['orderNumber'] : 'NUMBER PENDING'}',
                style: AppTextStyles.labelMedium.copyWith(
                  color: GarmentCareColors.textHint,
                  letterSpacing: .7,
                ),
              ),
              _CustomerPickupOrderTag(
                orderId: orderId,
                orderNumber: data['orderNumber']?.toString() ?? orderId,
              ),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: GarmentCareService.customerJobs(orderId),
                builder: (context, jobsSnapshot) {
                  if (!jobsSnapshot.hasData) return const SizedBox.shrink();
                  final statusesByGroup = <String, List<String>>{};
                  for (final job in jobsSnapshot.data!.docs) {
                    final groupId =
                        job.data()['deliveryGroupId']?.toString() ?? '';
                    final status = job.data()['status']?.toString() ?? '';
                    if (groupId.isEmpty || status.isEmpty) continue;
                    statusesByGroup
                        .putIfAbsent(groupId, () => <String>[])
                        .add(status);
                  }
                  return _CareInvoiceBatchSummary(
                    orderId: orderId,
                    orderNumber: data['orderNumber']?.toString() ?? orderId,
                    serviceJobStatusesByGroup: statusesByGroup,
                  );
                },
              ),
              const SizedBox(height: 8),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: GarmentCareService.customerJobs(orderId),
                builder: (context, jobsSnapshot) => StreamBuilder(
                  stream: GarmentCareService.customerShipments(orderId),
                  builder: (context, shipmentSnapshot) {
                    final shipments = shipmentSnapshot.data?.docs ?? const [];
                    final pickup = shipments.where(
                      (shipment) =>
                          shipment.data()['shipmentType'] == 'customer_pickup',
                    );
                    final returns = shipments.where(
                      (shipment) => _isCustomerFacingDelivery(shipment.data()),
                    );
                    final returnStatuses = returns
                        .map(
                          (shipment) =>
                              shipment.data()['status']?.toString() ?? '',
                        )
                        .where((status) => status.isNotEmpty)
                        .toList(growable: false);
                    final returnPaymentStatuses = returns
                        .map(
                          (shipment) =>
                              shipment
                                  .data()['paymentStatusAtDelivery']
                                  ?.toString() ??
                              '',
                        )
                        .where((status) => status.isNotEmpty)
                        .toList(growable: false);
                    final returnPaymentStatus =
                        returnPaymentStatuses.contains('requiresCustomerAction')
                        ? 'requiresCustomerAction'
                        : returnPaymentStatuses.contains('partiallyPaid')
                        ? 'partiallyPaid'
                        : returnPaymentStatuses.contains('invoice_pending')
                        ? 'invoice_pending'
                        : returnPaymentStatuses.contains('paid')
                        ? 'paid'
                        : 'not_due';
                    final shipmentReturnStatus =
                        returnStatuses.isNotEmpty &&
                            returnStatuses.every(
                              (status) => status == 'delivered',
                            )
                        ? 'delivered'
                        : returnStatuses.contains('inTransit')
                        ? 'inTransit'
                        : returnStatuses.contains('assigned')
                        ? 'assigned'
                        : returnStatuses.contains('planned')
                        ? 'planned'
                        : '';
                    final returnStatus =
                        shipmentReturnStatus.isEmpty &&
                            data['deliveryStatus'] == 'delivered'
                        ? 'delivered'
                        : shipmentReturnStatus;
                    final returnOnly =
                        returns.isNotEmpty &&
                        returns.every(
                          (shipment) => shipment.data()['returnOnly'] == true,
                        );
                    final jobs = jobsSnapshot.data?.docs ?? const [];
                    final jobsByDeliveryGroup = <String, List<String>>{};
                    for (final job in jobs) {
                      final groupId =
                          job.data()['deliveryGroupId']?.toString() ?? '';
                      final status = job.data()['status']?.toString() ?? '';
                      if (groupId.isEmpty || status.isEmpty) continue;
                      jobsByDeliveryGroup
                          .putIfAbsent(groupId, () => <String>[])
                          .add(status);
                    }
                    final hasCompletedSubOrder = jobsByDeliveryGroup.values.any(
                      (statuses) =>
                          statuses.isNotEmpty &&
                          statuses.every(
                            (status) => [
                              'completed',
                              'cancelled',
                              'blocked',
                            ].contains(status),
                          ),
                    );
                    return _CustomerCareProgressSummary(
                      fallback: data['statusProjection']?.toString(),
                      paymentStatus: data['paymentStatus']?.toString(),
                      paymentActionRequired:
                          data['paymentActionRequired'] == true,
                      hasCompletedSubOrder: hasCompletedSubOrder,
                      jobRecords: jobsSnapshot.data?.docs
                          .map(
                            (job) => <String, dynamic>{
                              'jobId': job.id,
                              ...job.data(),
                            },
                          )
                          .toList(growable: false),
                      pickupStatus: pickup.isEmpty
                          ? ''
                          : pickup.first.data()['status']?.toString() ?? '',
                      returnStatus: returnStatus,
                      returnPaymentStatus: returnPaymentStatus,
                      returnOnly: returnOnly,
                    );
                  },
                ),
              ),
              _CustomerPartnerNotes(orderId: orderId),
              const SizedBox(height: 8),
              const Text(
                'Any price or treatment change will appear here for your approval. Completed garments can be paid together on one service-order invoice; unfinished garments continue separately.',
              ),
              const SizedBox(height: 16),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: GarmentCareService.customerDeliveryGroups(orderId),
                builder: (context, groupsSnapshot) {
                  if (!groupsSnapshot.hasData ||
                      groupsSnapshot.data!.docs.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        groupsSnapshot.data!.docs.length > 1
                            ? 'Service orders in this checkout'
                            : 'This service order',
                        style: AppTextStyles.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      for (final group in groupsSnapshot.data!.docs)
                        _CareServiceOrderSummary(data: group.data()),
                    ],
                  );
                },
              ),
              StreamBuilder(
                stream: GarmentCareService.customerShipments(orderId),
                builder: (context, shipmentSnapshot) {
                  if (!shipmentSnapshot.hasData) return const SizedBox.shrink();
                  final returns = shipmentSnapshot.data!.docs
                      .where(
                        (shipment) =>
                            _isCustomerFacingDelivery(shipment.data()),
                      )
                      .toList();
                  if (returns.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pickup and delivery',
                        style: AppTextStyles.titleMedium,
                      ),
                      for (final shipment in returns)
                        _CareReturnShipmentCard(
                          data: shipment.data(),
                          deliveryPin: _customerDeliveryPin(data),
                        ),
                    ],
                  );
                },
              ),
              if (data['statusProjection'] == 'completed' &&
                  data['completedAt'] is Timestamp)
                _GarmentCareCompletionActions(orderId: orderId, data: data),
              StreamBuilder(
                stream: GarmentCareService.customerJobs(orderId),
                builder: (context, jobsSnapshot) {
                  if (!jobsSnapshot.hasData) {
                    return const LinearProgressIndicator();
                  }
                  return Column(
                    children: [
                      for (final job in jobsSnapshot.data!.docs)
                        _CustomerCareJobCard(jobId: job.id, data: job.data()),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    ),
  );
}

bool _isCustomerFacingDelivery(Map<String, dynamic> shipment) {
  if (shipment['shipmentType'] != 'customer_return') return false;
  final isStillAssignedToPartner =
      (shipment['toPartnerAccountId']?.toString().trim().isNotEmpty ?? false);
  return !(shipment['deliveryMode'] == 'other_partner' &&
      isStillAssignedToPartner);
}

class _CustomerCareProgressSummary extends StatelessWidget {
  const _CustomerCareProgressSummary({
    required this.fallback,
    required this.paymentStatus,
    required this.paymentActionRequired,
    required this.hasCompletedSubOrder,
    required this.jobRecords,
    required this.pickupStatus,
    required this.returnStatus,
    required this.returnPaymentStatus,
    required this.returnOnly,
  });

  final String? fallback;
  final String? paymentStatus;
  final bool paymentActionRequired;
  final bool hasCompletedSubOrder;
  final List<Map<String, dynamic>>? jobRecords;
  final String pickupStatus;
  final String returnStatus;
  final String returnPaymentStatus;
  final bool returnOnly;

  @override
  Widget build(BuildContext context) {
    final records = jobRecords ?? const <Map<String, dynamic>>[];
    final statuses = records
        .map((record) => record['status']?.toString() ?? '')
        .where((status) => status.isNotEmpty)
        .toList(growable: false);
    final countedServiceStatuses = statuses
        .where((status) => status != 'cancelled' && status != 'blocked')
        .toList(growable: false);
    final offerCount = statuses.where((status) => status == 'offered').length;
    final nextOfferCount = records
        .where(
          (record) =>
              record['status'] == 'offered' &&
              (record['dependsOnJobId']?.toString().trim().isNotEmpty ?? false),
        )
        .length;
    final initialOfferCount = offerCount - nextOfferCount;
    final queuedCount = statuses.where((status) => status == 'queued').length;
    final acceptedCount = statuses
        .where((status) => status == 'accepted')
        .length;
    final inspectionCount = statuses
        .where((status) => status == 'inspectionPending')
        .length;
    final reassignmentCount = statuses
        .where((status) => status == 'rejected')
        .length;
    final completedCount = statuses
        .where((status) => status == 'completed')
        .length;
    final notCollectedGarments = records
        .where(
          (record) =>
              record['pickupRejectionCode']?.toString().trim().isNotEmpty ==
              true,
        )
        .map((record) {
          final garmentId = record['garmentId']?.toString().trim() ?? '';
          return garmentId.isNotEmpty
              ? garmentId
              : record['jobId']?.toString() ?? '';
        })
        .where((garmentId) => garmentId.isNotEmpty)
        .toSet();
    final notCollectedCount = notCollectedGarments.length;
    final declinedCount = statuses
        .where((status) => status == 'blocked')
        .length;
    final careHasStarted = statuses.any(
      (status) => ['inProgress', 'qualityCheck', 'completed'].contains(status),
    );
    final allServicesComplete =
        statuses.isNotEmpty &&
        statuses.every(
          (status) => ['completed', 'cancelled', 'blocked'].contains(status),
        );
    final paymentReceived = [
      'paid',
      'fullyPaid',
      'captured',
    ].contains(paymentStatus);
    final pickupCouldNotComplete = pickupStatus == 'failed';
    final noPaymentDue =
        returnOnly ||
        (paymentStatus == 'not_due' &&
            (declinedCount > 0 ||
                notCollectedCount > 0 ||
                pickupCouldNotComplete));
    final nextServicePending = fallback == 'awaiting_next_service';
    final paymentDue =
        (paymentActionRequired || paymentStatus == 'requiresCustomerAction') &&
        hasCompletedSubOrder &&
        returnStatus != 'delivered';
    final customerActionPending = statuses.any(
      (status) =>
          status == 'awaitingCustomerEdit' || status == 'awaitingConsent',
    );
    String serviceProgressDetail() {
      final parts = <String>[];
      if (completedCount > 0) {
        parts.add(
          '$completedCount of ${countedServiceStatuses.length} care steps are complete across your garments.',
        );
      }
      if (inspectionCount > 0) {
        parts.add(
          '$inspectionCount ${inspectionCount == 1 ? 'service step is' : 'service steps are'} being inspected.',
        );
      }
      if (reassignmentCount > 0) {
        parts.add(
          'We are finding another Partner for $reassignmentCount ${reassignmentCount == 1 ? 'service step' : 'service steps'}.',
        );
      }
      if (nextOfferCount > 0) {
        parts.add(
          '$nextOfferCount next service ${nextOfferCount == 1 ? 'step is' : 'steps are'} waiting for the Partner to accept.',
        );
      }
      if (initialOfferCount > 0) {
        parts.add(
          '$initialOfferCount new service ${initialOfferCount == 1 ? 'request is' : 'requests are'} waiting for a Partner to accept.',
        );
      }
      if (acceptedCount > 0) {
        parts.add(
          '$acceptedCount ${acceptedCount == 1 ? 'service has' : 'services have'} been accepted; inspection is next.',
        );
      }
      if (queuedCount > 0) {
        parts.add('Later service steps open after earlier steps are complete.');
      }
      return parts.join(' ');
    }

    late final String title;
    late String detail;
    late final int activeStep;

    if (pickupStatus == 'failed') {
      title = 'Pickup could not be completed';
      detail =
          'The Partner could not accept these garments. Review the reason below and create a new order with a suitable service.';
    } else if (notCollectedCount > 0 && !allServicesComplete) {
      title = 'Pickup updated';
      detail =
          '$notCollectedCount garment${notCollectedCount == 1 ? '' : 's'} were not collected. Review the Partner’s reason below; the other garments continue through their service steps.';
    } else if (statuses.any((status) => status == 'awaitingCustomerEdit')) {
      title = 'Action needed from you';
      detail =
          'ACTION REQUIRED: Review the requested change and respond on the affected service card below.';
    } else if (statuses.any((status) => status == 'awaitingConsent')) {
      title = 'Review inspection and final price';
      detail =
          'ACTION REQUIRED: Review the finding and approve or decline on the service card below.';
    } else if (paymentDue && !allServicesComplete) {
      title = paymentStatus == 'partiallyPaid'
          ? 'Payment remaining for a ready garment'
          : 'Payment needed for a ready garment';
      detail =
          'ACTION REQUIRED: Pay the combined invoice for ready garments shown above. Other garment services will continue while this one is ready for delivery.';
    } else if (paymentStatus == 'partiallyPaid' &&
        hasCompletedSubOrder &&
        !allServicesComplete) {
      title = 'Payment recorded · other care continues';
      detail =
          'Payment for a completed garment sub-order is recorded. There is no new payment due now; remaining care will be invoiced when ready.';
    } else if (statuses.any(
      (status) => status == 'inProgress' || status == 'qualityCheck',
    )) {
      title = statuses.any((status) => status == 'qualityCheck')
          ? 'Garments are in quality check'
          : 'Garment care is in progress';
      detail = serviceProgressDetail().isNotEmpty
          ? serviceProgressDetail()
          : 'Your Partner is working on the selected services. We will update this order as they progress.';
    } else if (statuses.any((status) => status == 'readyToStart')) {
      title = 'Inspection complete · care is ready';
      detail =
          'No change is waiting for your approval. The Partner can begin the selected service.';
    } else if (statuses.any((status) => status == 'inspectionPending')) {
      title = 'Partner is inspecting your garments';
      detail =
          '${serviceProgressDetail()} Any finding, price change or approval choice will appear here.';
    } else if (allServicesComplete) {
      if (returnOnly && returnStatus == 'delivered') {
        title = 'Garment returned · no charge';
        detail =
            'The declined service was not billed. Your garment was returned.';
      } else if (returnOnly && returnStatus == 'inTransit') {
        title = 'Garment return is on the way';
        detail =
            'The declined service was not billed. Have your delivery PIN ready.';
      } else if (returnOnly && ['assigned', 'planned'].contains(returnStatus)) {
        title = 'Garment return is being arranged';
        detail =
            returnPaymentStatus == 'requiresCustomerAction' ||
                returnPaymentStatus == 'partiallyPaid'
            ? 'The declined service is not charged. Pay the earlier completed service invoice shown in its order before delivery.'
            : returnPaymentStatus == 'invoice_pending'
            ? 'The declined service is not charged. An earlier completed service invoice is being prepared before delivery.'
            : 'No payment is due for the declined service.';
      } else if (nextServicePending) {
        title = paymentDue
            ? 'Service complete · payment needed'
            : 'Another service is still in progress';
        detail = paymentDue
            ? 'ACTION REQUIRED: Pay this completed service invoice. Another booked service for this garment is still being handled.'
            : paymentReceived
            ? 'This service invoice is paid. Another booked service for this garment is still being handled; delivery follows after all services finish.'
            : 'Another booked service for this garment is still being handled. Delivery follows after all services finish.';
      } else if (returnStatus == 'delivered') {
        title = 'Garments delivered · payment complete';
        detail = 'Your delivery and final payment are recorded.';
      } else if (returnStatus == 'inTransit') {
        title = paymentReceived
            ? 'Out for delivery'
            : 'Delivery is waiting for payment';
        detail = paymentReceived
            ? 'Your garments are on the way. Have your delivery PIN ready for handover.'
            : 'ACTION REQUIRED: Pay the combined invoice shown above to unlock delivery.';
      } else if (returnStatus == 'assigned') {
        title = paymentReceived
            ? 'Delivery Partner assigned'
            : 'Delivery is waiting for payment';
        detail = paymentReceived
            ? 'Your garments are ready for dispatch. We will update you when delivery begins.'
            : 'ACTION REQUIRED: Pay the combined invoice shown above to unlock dispatch.';
      } else if (returnStatus == 'planned') {
        title = paymentReceived
            ? 'Paid · delivery is being arranged'
            : paymentStatus == 'partiallyPaid'
            ? 'Care complete · payment remaining'
            : 'Care complete · payment required';
        detail = paymentReceived
            ? 'All invoices are paid. We will update you when your garments are dispatched.'
            : paymentStatus == 'partiallyPaid'
            ? 'ACTION REQUIRED: Pay the remaining amount on the combined invoice shown above to arrange delivery.'
            : 'ACTION REQUIRED: Pay the combined invoice shown above to arrange delivery.';
      } else if (paymentReceived) {
        title = 'Care complete · paid';
        detail =
            'All service invoices are paid. Your delivery Partner can now prepare the handover.';
      } else if (paymentStatus == 'partiallyPaid') {
        title = 'Care complete · payment remaining';
        detail =
            'ACTION REQUIRED: Pay the remaining amount on the combined invoice shown above to arrange delivery.';
      } else {
        title = 'Care complete · payment required';
        detail =
            'ACTION REQUIRED: Pay the combined invoice shown above to arrange delivery.';
      }
    } else if (completedCount > 0 && offerCount > 0) {
      title = 'Garment care is progressing';
      detail = serviceProgressDetail();
    } else if (offerCount > 0) {
      title = 'Pickup received';
      detail = serviceProgressDetail();
    } else if (reassignmentCount > 0) {
      title = 'Finding another Partner';
      detail = serviceProgressDetail();
    } else if (acceptedCount > 0) {
      title = 'Partner accepted · inspection is next';
      detail =
          'Your Partner will inspect the garments and send the final price for approval.';
    } else if (queuedCount > 0) {
      title = 'Waiting for service assignment';
      detail = 'Some services start after an earlier step is complete.';
    } else {
      title = 'Current progress: ${_customerProgressLabel(fallback)}';
      detail = 'We will update this order as each service step moves forward.';
    }

    if (allServicesComplete && declinedCount > 0 && !returnOnly) {
      detail =
          '$detail Customer-declined garments are not billed and will be returned with completed garments.';
    }

    final inspectionComplete = statuses.any(
      (status) => [
        'awaitingConsent',
        'readyToStart',
        'inProgress',
        'qualityCheck',
        'completed',
      ].contains(status),
    );
    final delivered = returnStatus == 'delivered';
    final outForDelivery = returnStatus == 'inTransit';
    final journeyComplete = <bool>[
      true,
      pickupStatus == 'delivered' || pickupCouldNotComplete,
      inspectionComplete && !pickupCouldNotComplete,
      allServicesComplete && !pickupCouldNotComplete && !nextServicePending,
      !pickupCouldNotComplete &&
          !nextServicePending &&
          allServicesComplete &&
          (paymentReceived || noPaymentDue),
      outForDelivery || delivered,
      delivered,
    ];
    activeStep = pickupCouldNotComplete
        ? 1
        : paymentDue && allServicesComplete
        ? 4
        : nextServicePending
        ? 3
        : delivered
        ? 6
        : outForDelivery
        ? 5
        : paymentDue
        ? 4
        : allServicesComplete
        ? 5
        : careHasStarted
        ? 3
        : statuses.any(
            (status) => [
              'inspectionPending',
              'offered',
              'accepted',
              'awaitingConsent',
              'readyToStart',
            ].contains(status),
          )
        ? 2
        : pickupStatus == 'delivered'
        ? 2
        : pickupStatus == 'assigned' || pickupStatus == 'failed'
        ? 1
        : 0;
    final journeyLabels = [
      'Order Confirmed',
      pickupCouldNotComplete ? 'Pickup not completed' : 'Picked Up',
      pickupCouldNotComplete
          ? 'Inspection not started'
          : 'Inspection Completed',
      nextServicePending
          ? 'Another service in progress'
          : pickupCouldNotComplete
          ? 'Care not started'
          : allServicesComplete
          ? 'Care Completed'
          : 'Care in Progress',
      'Payment',
      'Out for Delivery',
      'Delivered',
    ];
    final journeyCaptions = <String?>[
      null,
      pickupCouldNotComplete
          ? 'No garments were collected. You can create a new order with a suitable service.'
          : pickupStatus == 'delivered'
          ? 'Garments received'
          : null,
      pickupCouldNotComplete
          ? 'Inspection did not start because no garments were collected'
          : statuses.contains('inspectionPending')
          ? 'Partner is inspecting the garments'
          : statuses.contains('awaitingConsent')
          ? 'Inspection is ready for your approval'
          : inspectionComplete
          ? 'Inspection recorded'
          : statuses.contains('accepted')
          ? 'Partner accepted; inspection is next'
          : statuses.contains('offered')
          ? 'Waiting for a Partner to accept'
          : null,
      nextServicePending
          ? 'A later booked service for this garment is still being handled'
          : pickupCouldNotComplete
          ? 'No care was performed'
          : statuses.contains('awaitingConsent')
          ? 'Care is paused until you approve the inspection'
          : statuses.contains('inProgress')
          ? 'Care is in progress'
          : statuses.contains('qualityCheck')
          ? 'Partner is checking the finished care'
          : allServicesComplete
          ? declinedCount > 0
                ? '$completedCount service steps completed; $declinedCount declined and ready to return'
                : 'All selected services are complete'
          : completedCount > 0
          ? '$completedCount of ${countedServiceStatuses.length} care steps are complete across your garments'
          : statuses.contains('readyToStart')
          ? 'Ready to start'
          : null,
      nextServicePending
          ? paymentDue
                ? 'ACTION REQUIRED: Pay this completed service invoice. The later service continues separately.'
                : 'Delivery starts after every booked service for this garment is complete.'
          : !allServicesComplete
          ? paymentDue
                ? 'ACTION REQUIRED: Pay the ready garment invoice above; later invoices appear as each sub-order finishes'
                : paymentStatus == 'partiallyPaid' && hasCompletedSubOrder
                ? 'Payment recorded for a completed sub-order; other care continues'
                : 'Invoices appear as each garment sub-order is completed'
          : noPaymentDue
          ? pickupCouldNotComplete
                ? 'No payment is due because no garments were collected'
                : 'No payment due for the declined service'
          : paymentReceived
          ? 'Final invoice paid'
          : 'ACTION REQUIRED: Pay the invoice shown above',
      outForDelivery
          ? 'Delivery in progress'
          : returnStatus == 'assigned'
          ? 'Delivery Partner assigned'
          : allServicesComplete && noPaymentDue
          ? 'No payment due'
          : allServicesComplete && paymentReceived
          ? 'Delivery is being arranged'
          : allServicesComplete && !delivered
          ? 'Delivery starts after payment'
          : null,
      delivered ? 'Handover confirmed' : null,
    ];

    final badgeText = pickupCouldNotComplete
        ? 'Pickup not completed'
        : delivered
        ? 'Complete'
        : paymentDue
        ? 'Payment due'
        : customerActionPending
        ? 'Action needed'
        : activeStep >= 4
        ? 'In progress'
        : activeStep == 0
        ? 'Confirmed'
        : 'In progress';
    final badgeBackground = delivered
        ? const Color(0xFFE8F5EC)
        : pickupCouldNotComplete || paymentDue || customerActionPending
        ? const Color(0xFFFFE8F1)
        : const Color(0xFFE8F1FF);
    final badgeForeground = delivered
        ? const Color(0xFF2C7A46)
        : pickupCouldNotComplete || paymentDue || customerActionPending
        ? GarmentCareColors.primary
        : const Color(0xFF3478D4);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: GarmentCareColors.divider),
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.headlineMedium.copyWith(
                    fontSize: 20,
                    height: 1.18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: badgeBackground,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  badgeText,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: badgeForeground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            detail,
            style: AppTextStyles.bodyLarge.copyWith(
              color: GarmentCareColors.textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Your order journey',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                'Step ${activeStep + 1} of ${journeyLabels.length}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: GarmentCareColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (var index = 0; index < journeyLabels.length; index++)
            _CustomerJourneyStep(
              label: journeyLabels[index],
              caption: journeyCaptions[index],
              completed: journeyComplete[index],
              active: index == activeStep && !journeyComplete[index],
              isLast: index == journeyLabels.length - 1,
            ),
        ],
      ),
    );
  }
}

class _CustomerJourneyStep extends StatelessWidget {
  const _CustomerJourneyStep({
    required this.label,
    required this.caption,
    required this.completed,
    required this.active,
    required this.isLast,
  });

  final String label;
  final String? caption;
  final bool completed;
  final bool active;
  final bool isLast;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 30,
          child: Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: completed
                      ? GarmentCareColors.primary
                      : Colors.transparent,
                  border: Border.all(
                    color: completed || active
                        ? GarmentCareColors.primary
                        : Colors.black26,
                    width: active ? 2 : 1.5,
                  ),
                ),
                child: completed
                    ? const Icon(Icons.check, size: 15, color: Colors.white)
                    : active
                    ? Center(
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: GarmentCareColors.primary,
                          ),
                        ),
                      )
                    : null,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    color: completed
                        ? GarmentCareColors.primary
                        : Colors.black12,
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 18, left: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: completed || active
                        ? FontWeight.w700
                        : FontWeight.w400,
                    color: completed || active
                        ? GarmentCareColors.textPrimary
                        : GarmentCareColors.textHint,
                  ),
                ),
                if (caption != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    caption!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: GarmentCareColors.textHint,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _CustomerPickupOrderTag extends StatelessWidget {
  const _CustomerPickupOrderTag({
    required this.orderId,
    required this.orderNumber,
  });

  final String orderId;
  final String orderNumber;

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: GarmentCareService.customerShipments(orderId),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text('Pickup and Partner details could not be loaded.'),
        );
      }
      final pickupDocs =
          snapshot.data?.docs
              .where(
                (shipment) =>
                    shipment.data()['shipmentType'] == 'customer_pickup',
              )
              .toList(growable: false) ??
          const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      if (pickupDocs.isEmpty) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Your order QR tag will be available after pickup is confirmed.',
          ),
        );
      }
      final pickup = pickupDocs.first;
      final pickupData = pickup.data();
      final received = pickupData['status'] == 'delivered';
      final rejectedGarmentIds =
          (pickupData['rejectedGarmentIds'] as List<dynamic>? ?? const [])
              .map((value) => value.toString())
              .where((value) => value.isNotEmpty)
              .toList(growable: false);
      final rejectionReasons = pickupData['pickupRejectionReasons'] is Map
          ? Map<String, dynamic>.from(
              pickupData['pickupRejectionReasons'] as Map,
            )
          : const <String, dynamic>{};
      final rejectionMessages = rejectedGarmentIds
          .map(
            (id) =>
                _pickupRejectionLabel(rejectionReasons[id]?.toString() ?? ''),
          )
          .toSet()
          .toList(growable: false);
      final assigned =
          (pickupData['toPartnerAccountId']?.toString() ?? '').isNotEmpty &&
          (pickupData['toPartnerProfileId']?.toString() ?? '').isNotEmpty;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (assigned)
            _CustomerPickupPartnerIdentity(
              shipmentId: pickup.id,
              data: pickupData,
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'We are matching your pickup with a Garment Care Partner.',
              ),
            ),
          if (rejectedGarmentIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${rejectedGarmentIds.length} garment${rejectedGarmentIds.length == 1 ? '' : 's'} not collected. ${rejectionMessages.join(' ')} Please create a new order for a suitable service; rejected garments will not be reassigned.',
              ),
            ),
          if (pickupData['status'] == 'failed' && rejectedGarmentIds.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'The Partner could not accept these garments. Please create a new order with a suitable service; they will not be reassigned.',
              ),
            ),
          const SizedBox(height: 8),
          if (received) OrderTrackingTag.button(context, orderNumber),
          if (received)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('This tag helps the Partner identify your order.'),
            )
          else if (pickupData['status'] == 'failed')
            const Text(
              'No order tag is available because no garments were collected.',
            )
          else
            const Text(
              'Your order QR tag will be available after the pickup Partner confirms receipt.',
            ),
        ],
      );
    },
  );
}

class _CustomerPickupPartnerIdentity extends StatefulWidget {
  const _CustomerPickupPartnerIdentity({
    required this.shipmentId,
    required this.data,
  });

  final String shipmentId;
  final Map<String, dynamic> data;

  @override
  State<_CustomerPickupPartnerIdentity> createState() =>
      _CustomerPickupPartnerIdentityState();
}

class _CustomerPickupPartnerIdentityState
    extends State<_CustomerPickupPartnerIdentity> {
  late Future<Map<String, dynamic>> _partnerDetails;

  @override
  void initState() {
    super.initState();
    _loadPartnerDetails();
  }

  @override
  void didUpdateWidget(covariant _CustomerPickupPartnerIdentity oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shipmentId != widget.shipmentId) _loadPartnerDetails();
  }

  void _loadPartnerDetails() {
    _partnerDetails = GarmentCareService.pickupPartnerDetails(
      widget.shipmentId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final storedName =
        widget.data['assignedPartnerName']?.toString().trim() ?? '';
    final storedPhone =
        widget.data['assignedPartnerContactPhone']?.toString().trim() ?? '';
    if (storedName.isNotEmpty && storedPhone.isNotEmpty) {
      return _details(storedName, storedPhone);
    }
    return FutureBuilder<Map<String, dynamic>>(
      future: _partnerDetails,
      builder: (context, snapshot) {
        final name = storedName.isNotEmpty
            ? storedName
            : snapshot.data?['name']?.toString() ?? '';
        final phone = storedPhone.isNotEmpty
            ? storedPhone
            : snapshot.data?['contactPhone']?.toString() ?? '';
        final alternatePhones =
            (snapshot.data?['additionalContactPhones'] as List<dynamic>? ??
                    const [])
                .map((value) => value.toString())
                .where((value) => value.isNotEmpty)
                .join(' · ');
        if (snapshot.hasError) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (name.isNotEmpty) _details(name, phone),
              Text(
                name.isEmpty
                    ? 'Pickup Partner details could not be loaded.'
                    : 'Partner contact details could not be loaded.',
              ),
              TextButton.icon(
                onPressed: () => setState(_loadPartnerDetails),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          );
        }
        if (name.isEmpty) {
          return const Text('Loading your pickup Partner details…');
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _details(name, phone, alternatePhones),
            if (phone.isEmpty) const Text('Loading Partner contact details…'),
          ],
        );
      },
    );
  }

  Widget _details(String name, String phone, [String alternatePhones = '']) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pickup Partner: $name'),
            if (phone.isNotEmpty) Text('Contact: $phone'),
            if (alternatePhones.isNotEmpty)
              Text('Alternate contact: $alternatePhones'),
          ],
        ),
      );
}

class _CustomerPartnerNotes extends StatelessWidget {
  const _CustomerPartnerNotes({required this.orderId});

  final String orderId;

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: GarmentCareService.customerPartnerNotes(orderId),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Text('Partner updates could not be loaded.');
      }
      final notes = [...?snapshot.data?.docs]
        ..sort((a, b) {
          final aAt = a.data()['at'];
          final bAt = b.data()['at'];
          final aDate = aAt is Timestamp ? aAt : Timestamp(0, 0);
          final bDate = bAt is Timestamp ? bAt : Timestamp(0, 0);
          return bDate.compareTo(aDate);
        });
      if (notes.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text('Updates from your Partner', style: AppTextStyles.titleMedium),
          const SizedBox(height: 6),
          for (final note in notes)
            Card(
              color: Colors.white,
              child: ListTile(
                leading: const Icon(Icons.message_outlined),
                title: Text(
                  note.data()['partnerName']?.toString() ??
                      'Garment Care Partner',
                ),
                subtitle: Text(
                  [
                    if ((note.data()['serviceName']?.toString() ?? '')
                        .isNotEmpty)
                      note.data()['serviceName'].toString(),
                    if ((note.data()['displayName']?.toString() ?? '')
                        .isNotEmpty)
                      note.data()['displayName'].toString(),
                    if (note.data()['at'] is Timestamp)
                      'Update ${_formatCareTimestamp(note.data()['at'] as Timestamp)}',
                    note.data()['message']?.toString() ?? '',
                  ].where((part) => part.isNotEmpty).join('\n'),
                ),
                isThreeLine: true,
              ),
            ),
        ],
      );
    },
  );
}

class _CareServiceOrderSummary extends StatelessWidget {
  const _CareServiceOrderSummary({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final group = GarmentCareServiceGroup.fromCode(
      data['serviceGroupCode']?.toString(),
    );
    final at = data['preferredPickupAt'];
    final pickupDate = at is Timestamp ? at.toDate() : null;
    final total = (data['estimatedGrandTotal'] as num?)?.toDouble();
    final subOrderNumber = data['pickupConfirmedAt'] is Timestamp
        ? data['subOrderNumber']?.toString().trim() ?? ''
        : '';
    final displayName = data['displayName']?.toString().trim() ?? '';
    return Card(
      color: GarmentCareColors.surface,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: GarmentCareColors.selected,
          child: Icon(
            Icons.local_laundry_service_outlined,
            color: GarmentCareColors.primary,
          ),
        ),
        title: Text(
          [
            if (subOrderNumber.isNotEmpty) 'Sub-order $subOrderNumber',
            displayName.isNotEmpty
                ? displayName
                : group?.label ?? 'Care service',
          ].join(' · '),
        ),
        subtitle: Text(
          [
            if (subOrderNumber.isNotEmpty && group != null) group.label,
            _projectionLabel(data['statusProjection']?.toString()),
            if (pickupDate != null)
              'Pickup ${pickupDate.day}/${pickupDate.month}/${pickupDate.year} · ${data['pickupSlot'] ?? ''}',
            if (total != null) 'Estimate ₹${total.toStringAsFixed(2)}',
          ].join(' · '),
        ),
        isThreeLine: true,
      ),
    );
  }
}

class _CustomerServicePartnerIdentity extends StatefulWidget {
  const _CustomerServicePartnerIdentity({
    required this.jobId,
    required this.data,
  });

  final String jobId;
  final Map<String, dynamic> data;

  @override
  State<_CustomerServicePartnerIdentity> createState() =>
      _CustomerServicePartnerIdentityState();
}

class _CustomerServicePartnerIdentityState
    extends State<_CustomerServicePartnerIdentity> {
  late Future<Map<String, dynamic>> _detailsFuture;
  late String _signature;

  String _currentSignature(Map<String, dynamic> data) => [
    data['assignedPartnerAccountId'],
    data['assignedPartnerProfileId'],
    data['assignedPartnerName'],
    data['assignedPartnerContactPhone'],
  ].map((value) => value?.toString() ?? '').join('|');

  @override
  void initState() {
    super.initState();
    _signature = _currentSignature(widget.data);
    _detailsFuture = _fetchDetails();
  }

  @override
  void didUpdateWidget(covariant _CustomerServicePartnerIdentity oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextSignature = _currentSignature(widget.data);
    if (nextSignature != _signature) {
      _signature = nextSignature;
      _detailsFuture = _fetchDetails();
    }
  }

  Future<Map<String, dynamic>> _fetchDetails() {
    final accountId = widget.data['assignedPartnerAccountId']?.toString() ?? '';
    final profileId = widget.data['assignedPartnerProfileId']?.toString() ?? '';
    if (accountId.isEmpty || profileId.isEmpty) {
      return Future<Map<String, dynamic>>.value(const <String, dynamic>{});
    }
    return GarmentCareService.customerServicePartnerDetails(widget.jobId);
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.data['status']?.toString() ?? '';
    if (status == 'offered') {
      return const Padding(
        padding: EdgeInsets.only(left: 16, bottom: 8),
        child: Text(
          'Partner contact appears here after they accept this service.',
        ),
      );
    }
    if (status == 'queued') {
      return const Padding(
        padding: EdgeInsets.only(left: 16, bottom: 8),
        child: Text(
          'This service starts after a Partner is assigned and earlier steps are complete.',
        ),
      );
    }
    if (status == 'rejected') {
      return const Padding(
        padding: EdgeInsets.only(left: 16, bottom: 8),
        child: Text('We are finding another Partner for this service.'),
      );
    }
    final storedName =
        widget.data['assignedPartnerName']?.toString().trim() ?? '';
    final storedPhone =
        widget.data['assignedPartnerContactPhone']?.toString().trim() ?? '';
    if (storedName.isNotEmpty && storedPhone.isNotEmpty) {
      return _line(storedName, storedPhone);
    }
    return FutureBuilder<Map<String, dynamic>>(
      future: _detailsFuture,
      builder: (context, snapshot) {
        final partner = snapshot.data ?? const <String, dynamic>{};
        final name = storedName.isNotEmpty
            ? storedName
            : partner['name']?.toString().trim() ?? '';
        final phone = storedPhone.isNotEmpty
            ? storedPhone
            : partner['contactPhone']?.toString().trim() ?? '';
        final isAssigned =
            partner['assigned'] == true ||
            widget.data['assignedPartnerAccountId'] != null;
        if (!isAssigned && !snapshot.hasError) return const SizedBox.shrink();
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (name.isNotEmpty) _line(name, phone),
                const Text('Inspection Partner contact could not be loaded.'),
                TextButton.icon(
                  onPressed: () =>
                      setState(() => _detailsFuture = _fetchDetails()),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        if (name.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(left: 16, bottom: 8),
            child: Text(
              'Inspection Partner details will appear after assignment.',
            ),
          );
        }
        return _line(name, phone);
      },
    );
  }

  Widget _line(String name, String phone) => Padding(
    padding: const EdgeInsets.only(left: 16, bottom: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Inspection Partner: $name'),
        if (phone.isNotEmpty) Text('Contact: $phone'),
      ],
    ),
  );
}

class _CustomerCareJobCard extends StatelessWidget {
  const _CustomerCareJobCard({required this.jobId, required this.data});
  final String jobId;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final quoteId = data['quoteVersionId']?.toString() ?? '';
    final consentId = data['consentId']?.toString() ?? '';
    final garmentName =
        data['displayName']?.toString().trim().isNotEmpty == true
        ? data['displayName'].toString().trim()
        : GarmentCareCatalogMetadata.itemLabel(
            data['serviceGroupCode']?.toString() ?? '',
            data['itemTypeCode']?.toString() ?? 'other',
          );
    final orderNumber = data['orderNumber']?.toString().trim() ?? '';
    final subOrderNumber = data['pickupConfirmedAt'] is Timestamp
        ? data['subOrderNumber']?.toString().trim() ?? ''
        : '';
    final subOrderType = GarmentCareServiceGroup.fromCode(
      data['serviceGroupCode']?.toString(),
    )?.label;
    final relevantTimestamp = data['updatedAt'] is Timestamp
        ? data['updatedAt'] as Timestamp
        : data['createdAt'] is Timestamp
        ? data['createdAt'] as Timestamp
        : null;
    final photoPaths = <String>{
      ...(data['conditionPhotoPaths'] as List<dynamic>? ?? const []).map(
        (value) => value.toString(),
      ),
      ...(data['inspectionEvidencePaths'] as List<dynamic>? ?? const []).map(
        (value) => value.toString(),
      ),
    }.where((path) => path.isNotEmpty).toList(growable: false);
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.checkroom_outlined),
              title: Text(
                '$garmentName · ${GarmentCareServiceCatalog.labelFor(data['serviceId']?.toString() ?? '')}',
              ),
              subtitle: Text(
                [
                  if (orderNumber.isNotEmpty) 'Order $orderNumber',
                  if (subOrderNumber.isNotEmpty)
                    'Sub-order $subOrderNumber${subOrderType == null ? '' : ' · $subOrderType'}',
                  _customerJobStatusLabel(data['status']?.toString()),
                  if (relevantTimestamp != null)
                    'Updated ${_formatCareTimestamp(relevantTimestamp)}',
                  if ((data['pickupRejectionCode']?.toString() ?? '')
                      .isNotEmpty)
                    'Pickup note: ${_pickupRejectionLabel(data['pickupRejectionCode'].toString())}',
                  if (data['status'] == 'blocked' &&
                      (data['customerDecisionNote']
                              ?.toString()
                              .trim()
                              .isNotEmpty ??
                          false))
                    'Customer decision: ${data['customerDecisionNote']}',
                  if (data['status'] == 'rejected' &&
                      (data['reassignmentReason']
                              ?.toString()
                              .trim()
                              .isNotEmpty ??
                          false))
                    'Partner decline: ${data['reassignmentReason']}',
                  if (data['acceptedAt'] is Timestamp)
                    'Partner accepted: ${_formatCareTimestamp(data['acceptedAt'] as Timestamp)}',
                  if (data['inspectionStartedAt'] is Timestamp)
                    'Inspection started: ${_formatCareTimestamp(data['inspectionStartedAt'] as Timestamp)}',
                ].join('\n'),
              ),
              isThreeLine: true,
            ),
            _CustomerServicePartnerIdentity(jobId: jobId, data: data),
            if (photoPaths.isNotEmpty) ...[
              const SizedBox(height: 6),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Garment photos',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final path in photoPaths)
                    _GarmentCareInspectionPhoto(path: path),
                ],
              ),
            ],
            if (data['status'] == 'readyToStart' &&
                (data['customerMessage']?.toString() ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 12, top: 4, bottom: 8),
                child: Text(data['customerMessage'].toString()),
              ),
            if (data['status'] == 'awaitingConsent' &&
                quoteId.isNotEmpty &&
                consentId.isNotEmpty)
              FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: FirebaseFirestore.instance
                    .collection('garment_care_quote_versions')
                    .doc(quoteId)
                    .get(),
                builder: (context, quoteSnapshot) {
                  final quote = quoteSnapshot.data?.data();
                  if (quote == null) {
                    return const Text('Loading the inspection quote…');
                  }
                  final amount =
                      (quote['customerTotal'] as num?)?.toDouble() ?? 0;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Inspection quote · ₹${amount.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        quote['customerMessage']?.toString() ??
                            quote['inspectionNotes']?.toString() ??
                            '',
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'This amount includes the revised service price and applicable charges.',
                      ),
                      if (((quote['additionalServiceFee'] as num?)
                                  ?.toDouble() ??
                              0) >
                          0) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Additional charge: ₹${(quote['additionalServiceFee'] as num).toDouble().toStringAsFixed(2)}',
                        ),
                        Text(
                          'Reason: ${quote['additionalServiceReason']?.toString() ?? 'Not provided'}',
                        ),
                      ],
                      if ((quote['conditionFindings']?.toString() ?? '')
                          .isNotEmpty)
                        Text('Condition: ${quote['conditionFindings']}'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  _respond(context, consentId, 'rejected'),
                              child: const Text('Decline'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: () =>
                                  _respond(context, consentId, 'accepted'),
                              child: const Text('Approve'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            if (data['status'] == 'awaitingCustomerEdit') ...[
              const Divider(),
              Text(
                'Partner requests a change: ${data['revisionReason'] ?? 'Please review this garment.'}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  OutlinedButton(
                    onPressed: () => _respondToRevision(context, 'keep'),
                    child: const Text('Find another partner'),
                  ),
                  OutlinedButton(
                    onPressed: () => _changeRevisionService(context),
                    child: const Text('Change service'),
                  ),
                  TextButton(
                    onPressed: () => _respondToRevision(context, 'remove'),
                    child: const Text('Remove item and return it'),
                  ),
                ],
              ),
            ],
            if (data['status'] == 'awaitingConsent' && quoteId.isEmpty)
              const Text('Waiting for an Admin-approved price version.'),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 6),
              title: const Text('Order references'),
              children: [
                SelectableText('Service job: $jobId'),
                if ((data['garmentId']?.toString() ?? '').isNotEmpty)
                  SelectableText('Garment reference: ${data['garmentId']}'),
                if ((data['orderId']?.toString() ?? '').isNotEmpty)
                  SelectableText('Order reference: ${data['orderId']}'),
                if ((data['deliveryGroupId']?.toString() ?? '').isNotEmpty)
                  SelectableText(
                    'Service order reference: ${data['deliveryGroupId']}',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _respondToRevision(
    BuildContext context,
    String decision, {
    String? replacementServiceId,
  }) async {
    final revisionId = data['revisionRequestId']?.toString() ?? '';
    if (revisionId.isEmpty) return;
    try {
      await GarmentCareService.respondToItemRevision(
        revisionId: revisionId,
        decision: decision,
        replacementServiceId: replacementServiceId,
      );
    } on FirebaseFunctionsException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message ?? 'Could not update this garment.'),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update this garment.')),
        );
      }
    }
  }

  Future<void> _changeRevisionService(BuildContext context) async {
    final group = GarmentCareServiceGroup.fromCode(
      data['serviceGroupCode']?.toString(),
    );
    if (group == null) return;
    final choices =
        GarmentCareServiceCatalog.serviceIdsByGroup[group.code] ??
        const <String>[];
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final serviceId in choices)
              if (serviceId != data['serviceId'])
                ListTile(
                  title: Text(GarmentCareServiceCatalog.labelFor(serviceId)),
                  onTap: () => Navigator.pop(sheetContext, serviceId),
                ),
          ],
        ),
      ),
    );
    if (!context.mounted || selected == null) return;
    await _respondToRevision(context, 'change', replacementServiceId: selected);
  }

  Future<void> _respond(
    BuildContext context,
    String consentId,
    String decision,
  ) async {
    try {
      await GarmentCareService.respondToConsent(
        consentId: consentId,
        decision: decision,
      );
    } on FirebaseFunctionsException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message ?? 'Could not save your decision.'),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save your decision.')),
        );
      }
    }
  }
}

String _formatCareTimestamp(Timestamp timestamp) {
  final value = timestamp.toDate().toLocal();
  final date =
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  final time =
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  return '$date · $time';
}

String _projectionLabel(String? value) => switch (value) {
  'awaiting_next_service' => 'Another service in progress',
  'awaiting_delivery' => 'Ready for delivery',
  'awaiting_payment' => 'Payment needed',
  'return_pending' => 'Return in progress',
  'pickup_partial' => 'Pickup partly accepted',
  'pickup_rejected' => 'Pickup not completed',
  'partially_delivered' => 'Partially delivered',
  'partner_assignment' => 'Waiting for a Partner',
  'cancelled' => 'Cancelled',
  _ =>
    (value ?? 'submitted')
        .replaceAll('_', ' ')
        .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
        .split(' ')
        .map(
          (part) => part.isEmpty
              ? part
              : '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join(' '),
};

String _customerProgressLabel(String? value) => switch (value) {
  'partner_assignment' => 'Waiting for service Partner',
  'awaiting_payment' => 'Waiting for payment',
  'awaiting_next_service' => 'Another service in progress',
  'customer_action_required' => 'Action needed from you',
  'return_pending' => 'Return delivery in progress',
  'pickup_partial' => 'Pickup partly accepted',
  'pickup_rejected' => 'Pickup rejected by Partner',
  'completed' => 'Complete',
  _ => _projectionLabel(value),
};

String _pickupRejectionLabel(String code) => switch (code) {
  'complex_care' => 'This garment needs a more specialized service.',
  'unsafe_condition' => 'The garment condition needs specialist review.',
  'service_mismatch' => 'The selected service does not suit this garment.',
  'service_unavailable' => 'This service is unavailable at pickup.',
  'garment_not_present' => 'The garment was not available at pickup.',
  _ => 'The Partner could not accept this garment.',
};

String _customerJobStatusLabel(String? value) => switch (value) {
  'offered' => 'Waiting for a Partner to accept',
  'queued' => 'Waiting for service assignment',
  'accepted' => 'Partner accepted · inspection is next',
  'inspectionPending' => 'Inspection in progress',
  'awaitingConsent' => 'Review inspection and final price',
  'readyToStart' => 'Inspection complete · treatment is next',
  'inProgress' => 'Care in progress',
  'qualityCheck' => 'Quality check',
  'awaitingCustomerEdit' => 'Action needed from you',
  'rejected' => 'Declined by Partner · finding another Partner',
  'cancelled' => 'Not collected at pickup',
  'completed' => 'Service complete',
  'blocked' => 'Declined by customer',
  _ => _projectionLabel(value),
};

class _GarmentCareInspectionPhoto extends StatelessWidget {
  const _GarmentCareInspectionPhoto({required this.path});
  final String path;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, right: 8),
    child: FutureBuilder<String>(
      future: FirebaseStorage.instance.ref(path).getDownloadURL(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            width: 96,
            height: 96,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            snapshot.data!,
            width: 96,
            height: 96,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const SizedBox(
              width: 96,
              height: 96,
              child: Center(child: Icon(Icons.broken_image_outlined)),
            ),
          ),
        );
      },
    ),
  );
}

class _CareReturnShipmentCard extends StatelessWidget {
  const _CareReturnShipmentCard({
    required this.data,
    required this.deliveryPin,
  });
  final Map<String, dynamic> data;
  final String deliveryPin;

  @override
  Widget build(BuildContext context) {
    final status = data['status']?.toString() ?? '';
    final hasInvoice = data['invoiceId']?.toString().trim().isNotEmpty == true;
    final careComplete = data['careComplete'] == true;
    final paymentPaid = data['paymentStatusAtDelivery'] == 'paid';
    final title = switch (status) {
      'planned' =>
        !careComplete
            ? 'Care in progress · no payment action yet'
            : !hasInvoice
            ? 'Garment care complete · invoice not ready'
            : paymentPaid
            ? 'Paid · ready for delivery'
            : 'Payment required · ready for delivery',
      'inTransit' => 'Out for delivery',
      'delivered' => 'Delivered · payment complete',
      _ => 'Delivery · ${_projectionLabel(status)}',
    };
    final name =
        data['deliveryPartnerName']?.toString() ??
        data['fromPartnerName']?.toString() ??
        'Garment Care Partner';
    final phone =
        data['deliveryPartnerContactPhone']?.toString() ??
        data['fromPartnerContactPhone']?.toString() ??
        '';
    final subOrderNumber =
        data['subOrderNumber']?.toString().trim().isNotEmpty == true
        ? data['subOrderNumber'].toString().trim()
        : (data['subOrderNumbersByGarmentId'] is Map &&
              (data['garmentId']?.toString() ?? '').isNotEmpty)
        ? (data['subOrderNumbersByGarmentId'] as Map)[data['garmentId']]
                  ?.toString() ??
              ''
        : '';
    final order = data['orderNumber']?.toString().trim() ?? '';
    return Card(
      color: GarmentCareColors.surface,
      child: ListTile(
        leading: const Icon(
          Icons.local_shipping_outlined,
          color: GarmentCareColors.primary,
        ),
        title: Text(title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (order.isNotEmpty || subOrderNumber.isNotEmpty)
              Text(
                [
                  if (order.isNotEmpty) 'Order $order',
                  if (subOrderNumber.isNotEmpty) 'Sub-order $subOrderNumber',
                ].join(' · '),
              ),
            Text(name),
            if (phone.isNotEmpty) Text('Contact $phone'),
            if (status == 'planned' && !careComplete)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Care is still in progress for this garment sub-order. No payment is due yet.',
                ),
              )
            else if (status == 'planned' && !hasInvoice)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'No payment is due yet. Your invoice and next step will appear here when ready.',
                ),
              )
            else if (status == 'planned' && hasInvoice && !paymentPaid)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'ACTION REQUIRED: Pay this garment sub-order invoice above before delivery.',
                ),
              ),
            if (status == 'inTransit' && deliveryPin.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Your delivery PIN: $deliveryPin',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const Text(
                'Share this PIN with the delivery Partner to confirm handover.',
              ),
            ] else if (status == 'inTransit') ...[
              const SizedBox(height: 8),
              const Text(
                'Your registered phone number is unavailable. Please contact support before handover.',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _customerDeliveryPin(Map<String, dynamic> orderData) {
  final address = orderData['pickupAddressSnapshot'];
  final addressData = address is Map
      ? Map<String, dynamic>.from(address)
      : const <String, dynamic>{};
  final phone = (addressData['mobileNumber'] ?? orderData['customerPhone'])
      ?.toString();
  final digits = (phone ?? '').replaceAll(RegExp(r'\D'), '');
  return digits.length >= 4 ? digits.substring(digits.length - 4) : '';
}

class _GarmentCareCompletionActions extends StatefulWidget {
  const _GarmentCareCompletionActions({
    required this.orderId,
    required this.data,
  });
  final String orderId;
  final Map<String, dynamic> data;

  @override
  State<_GarmentCareCompletionActions> createState() =>
      _GarmentCareCompletionActionsState();
}

class _GarmentCareCompletionActionsState
    extends State<_GarmentCareCompletionActions> {
  final _feedback = TextEditingController();
  int _rating = 5;
  bool _saving = false;

  @override
  void dispose() {
    _feedback.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final completedAt = (widget.data['completedAt'] as Timestamp).toDate();
    final warrantyOpen = DateTime.now().isBefore(
      completedAt.add(const Duration(days: 5)),
    );
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How was your care service?',
              style: AppTextStyles.titleMedium,
            ),
            if (widget.data['feedbackSubmittedAt'] != null)
              Text(
                'Thank you for your ${widget.data['feedbackRating'] ?? ''}-star feedback.',
              )
            else ...[
              Row(
                children: [
                  for (var score = 1; score <= 5; score++)
                    IconButton(
                      onPressed: _saving
                          ? null
                          : () => setState(() => _rating = score),
                      icon: Icon(
                        score <= _rating
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: GarmentCareColors.primary,
                      ),
                    ),
                ],
              ),
              TextField(
                controller: _feedback,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Feedback (optional)',
                ),
              ),
              FilledButton(
                onPressed: _saving ? null : _submitFeedback,
                child: const Text('Send feedback'),
              ),
            ],
            if (widget.data['warrantyClaimStatus'] == 'open')
              const Text('Your five-day care issue report is open.')
            else if (warrantyOpen)
              TextButton.icon(
                onPressed: _saving ? null : _reportIssue,
                icon: const Icon(Icons.report_problem_outlined),
                label: const Text('Report a care issue · 5-day warranty'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitFeedback() async {
    setState(() => _saving = true);
    try {
      await GarmentCareService.submitFeedback(
        orderId: widget.orderId,
        rating: _rating,
        feedback: _feedback.text.trim(),
      );
    } on FirebaseFunctionsException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message ?? 'Could not submit feedback.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reportIssue() async {
    final controller = TextEditingController();
    final description = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Report a garment-care issue'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          maxLength: 1500,
          decoration: const InputDecoration(hintText: 'Describe the issue'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (description == null || description.length < 5) return;
    setState(() => _saving = true);
    try {
      await GarmentCareService.reportWarrantyIssue(
        orderId: widget.orderId,
        description: description,
      );
    } on FirebaseFunctionsException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message ?? 'Could not report the issue.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _CareInvoiceBatchSummary extends StatefulWidget {
  const _CareInvoiceBatchSummary({
    required this.orderId,
    required this.orderNumber,
    required this.serviceJobStatusesByGroup,
  });

  final String orderId;
  final String orderNumber;
  final Map<String, List<String>> serviceJobStatusesByGroup;

  @override
  State<_CareInvoiceBatchSummary> createState() =>
      _CareInvoiceBatchSummaryState();
}

class _CareInvoiceBatchSummaryState extends State<_CareInvoiceBatchSummary> {
  late final Future<ShopPayoutConfig> _paymentConfig;
  bool _paying = false;

  @override
  void initState() {
    super.initState();
    _paymentConfig = PayoutConfigService.fetch();
  }

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: GarmentCareService.customerInvoices(widget.orderId),
    builder: (context, snapshot) {
      if (snapshot.hasError) return _invoiceReadError(context);
      if (!snapshot.hasData) return const SizedBox.shrink();
      final invoices = snapshot.data!.docs.where((invoice) {
        final status = invoice.data()['invoiceStatus']?.toString();
        return status == 'issued' || status == 'paid';
      }).toList();
      if (invoices.isEmpty) return const SizedBox.shrink();

      bool careComplete(String groupId) {
        final statuses = widget.serviceJobStatusesByGroup[groupId] ?? const [];
        return statuses.isNotEmpty &&
            statuses.every(
              (status) =>
                  ['completed', 'cancelled', 'blocked'].contains(status),
            );
      }

      final readyInvoices = invoices
          .where(
            (invoice) =>
                invoice.data()['invoiceStatus'] == 'issued' &&
                careComplete(
                  invoice.data()['deliveryGroupId']?.toString() ?? '',
                ),
          )
          .toList();
      final payableInvoiceIds = readyInvoices
          .map((invoice) => invoice.id)
          .toList();
      final amountDue = readyInvoices.fold<double>(
        0,
        (runningTotal, invoice) => runningTotal +
            ((invoice.data()['grandTotal'] as num?)?.toDouble() ?? 0),
      );
      final paidAmount = invoices
          .where((invoice) => invoice.data()['invoiceStatus'] == 'paid')
          .fold<double>(
            0,
            (runningTotal, invoice) => runningTotal +
                ((invoice.data()['grandTotal'] as num?)?.toDouble() ?? 0),
          );
      final allPaid = invoices.every(
        (invoice) => invoice.data()['invoiceStatus'] == 'paid',
      );
      final displayedInvoices = allPaid ? invoices : readyInvoices;

      return FutureBuilder<ShopPayoutConfig>(
        future: _paymentConfig,
        builder: (context, configSnapshot) {
          final sandboxMode = configSnapshot.data?.sandboxMode == true;
          return Card(
            color: allPaid ? Colors.white : const Color(0xFFFFF5F8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: allPaid
                    ? GarmentCareColors.divider
                    : GarmentCareColors.primary,
                width: allPaid ? 1 : 1.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        allPaid
                            ? Icons.check_circle_outline_rounded
                            : Icons.receipt_long_outlined,
                        color: allPaid
                            ? const Color(0xFF2C7A46)
                            : GarmentCareColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          allPaid
                              ? 'Combined invoice paid'
                              : 'Combined service-order invoice',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: allPaid
                                    ? const Color(0xFF2C7A46)
                                    : GarmentCareColors.primary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Order ${widget.orderNumber}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    allPaid
                        ? 'Total paid'
                        : 'Ready garments · ${readyInvoices.length} ${readyInvoices.length == 1 ? 'sub-order' : 'sub-orders'}',
                  ),
                  Text(
                    '₹${(allPaid ? paidAmount : amountDue).toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(
                    'Services ₹${displayedInvoices.fold<double>(0, (runningTotal, invoice) => runningTotal + ((invoice.data()['serviceSubtotal'] as num?)?.toDouble() ?? 0)).toStringAsFixed(2)} · '
                    'Tax ₹${displayedInvoices.fold<double>(0, (runningTotal, invoice) => runningTotal + ((invoice.data()['taxTotal'] as num?)?.toDouble() ?? 0)).toStringAsFixed(2)} · '
                    'Pickup/return ₹${displayedInvoices.fold<double>(0, (runningTotal, invoice) => runningTotal + ((invoice.data()['logisticsTotal'] as num?)?.toDouble() ?? 0)).toStringAsFixed(2)}',
                  ),
                  if (!allPaid && paidAmount > 0)
                    Text(
                      'Already paid for other garments: ₹${paidAmount.toStringAsFixed(2)}',
                    ),
                  if (invoices.length > 1)
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(bottom: 8),
                      title: Text(
                        'Invoice details · ${invoices.length} garment sub-orders',
                      ),
                      children: [
                        for (final invoice in invoices)
                          _CareInvoiceBatchLine(
                            invoice: invoice.data(),
                            paid: invoice.data()['invoiceStatus'] == 'paid',
                            careComplete: careComplete(
                              invoice.data()['deliveryGroupId']?.toString() ??
                                  '',
                            ),
                          ),
                      ],
                    )
                  else
                    for (final invoice in invoices)
                      _CareInvoiceBatchLine(
                        invoice: invoice.data(),
                        paid: invoice.data()['invoiceStatus'] == 'paid',
                        careComplete: careComplete(
                          invoice.data()['deliveryGroupId']?.toString() ?? '',
                        ),
                      ),
                  if (!allPaid && amountDue > 0) ...[
                    const SizedBox(height: 6),
                    const Text(
                      'One payment covers the ready garment sub-orders listed here. Garments still in care will be billed when ready.',
                    ),
                    if (configSnapshot.connectionState != ConnectionState.done)
                      const LinearProgressIndicator()
                    else if (sandboxMode)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _paying
                              ? null
                              : () => _pay(amountDue, payableInvoiceIds),
                          icon: _paying
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.payment_rounded),
                          label: Text('Pay ₹${amountDue.toStringAsFixed(2)}'),
                        ),
                      )
                    else
                      const Text(
                        'Online payment is not configured yet. Delivery remains locked until the full invoice is paid.',
                      ),
                  ] else if (allPaid)
                    const Text('Test payment recorded. No money was moved.'),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  Widget _invoiceReadError(BuildContext context) => Card(
    color: const Color(0xFFFFF5F8),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Text(
        'We could not load this invoice. Please refresh the order; if it still does not appear, contact support.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    ),
  );

  Future<void> _pay(double amount, List<String> invoiceIds) async {
    final method = await showDialog<OnlinePaymentMethod>(
      context: context,
      builder: (dialogContext) {
        var selected = OnlinePaymentMethod.upi;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const Text('Complete test payment'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '₹${amount.toStringAsFixed(2)} · test mode · no money will be charged.',
                ),
                const SizedBox(height: 8),
                RadioGroup<OnlinePaymentMethod>(
                  groupValue: selected,
                  onChanged: (value) {
                    if (value != null) setDialogState(() => selected = value);
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final method in OnlinePaymentMethod.values)
                        RadioListTile<OnlinePaymentMethod>(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(method.label),
                          value: method,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, selected),
                child: const Text('Pay in test mode'),
              ),
            ],
          ),
        );
      },
    );
    if (method == null || !mounted) return;
    setState(() => _paying = true);
    try {
      await GarmentCareService.payFinalInvoices(
        invoiceIds: invoiceIds,
        method: method,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test payment complete. No money was moved.'),
          ),
        );
      }
    } on FirebaseFunctionsException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message ?? 'Could not complete payment.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not complete payment. Check the connection and retry.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }
}

class _CareInvoiceBatchLine extends StatelessWidget {
  const _CareInvoiceBatchLine({
    required this.invoice,
    required this.paid,
    required this.careComplete,
  });

  final Map<String, dynamic> invoice;
  final bool paid;
  final bool careComplete;

  @override
  Widget build(BuildContext context) {
    final rawLines = invoice['lines'];
    final lines = rawLines is List
        ? rawLines
              .whereType<Map>()
              .map((line) => Map<String, dynamic>.from(line))
              .toList()
        : const <Map<String, dynamic>>[];
    final firstLine = lines.isNotEmpty
        ? lines.first
        : const <String, dynamic>{};
    final dna = firstLine['garmentDna'] is Map
        ? Map<String, dynamic>.from(firstLine['garmentDna'] as Map)
        : const <String, dynamic>{};
    final subOrder = firstLine['subOrderNumber']?.toString().trim() ?? '';
    final name = dna['displayName']?.toString().trim() ?? '';
    final total = (invoice['grandTotal'] as num?)?.toDouble() ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  [
                    if (subOrder.isNotEmpty) 'Sub-order $subOrder',
                    if (name.isNotEmpty) name,
                  ].join(' · '),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                paid
                    ? 'Paid'
                    : careComplete
                    ? 'Ready'
                    : 'Care in progress',
              ),
              const SizedBox(width: 8),
              Text('₹${total.toStringAsFixed(2)}'),
            ],
          ),
          if (lines.isNotEmpty)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              title: const Text('Care and inspection details'),
              children: [
                for (final line in lines) _CareInvoiceLineReport(line: line),
              ],
            ),
          const Divider(height: 8),
        ],
      ),
    );
  }
}

class _CareInvoiceSummary extends StatefulWidget {
  const _CareInvoiceSummary({
    required this.orderId,
    required this.deliveryGroupId,
    required this.serviceJobStatuses,
  });
  final String orderId;
  final String deliveryGroupId;
  final List<String> serviceJobStatuses;

  @override
  State<_CareInvoiceSummary> createState() => _CareInvoiceSummaryState();
}

class _CareInvoiceSummaryState extends State<_CareInvoiceSummary> {
  late final Future<ShopPayoutConfig> _paymentConfig;
  bool _paying = false;

  @override
  void initState() {
    super.initState();
    _paymentConfig = PayoutConfigService.fetch();
  }

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance
        .collection('garment_care_orders')
        .doc(widget.orderId)
        .collection('delivery_groups')
        .doc(widget.deliveryGroupId)
        .snapshots(),
    builder: (context, groupSnapshot) {
      if (groupSnapshot.hasError) {
        return _invoiceReadError(context);
      }
      final group = groupSnapshot.data?.data();
      final invoiceId = group?['invoiceId']?.toString().trim() ?? '';
      if (invoiceId.isEmpty) return const SizedBox.shrink();
      return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('garment_care_invoices')
            .doc(invoiceId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _invoiceReadError(context);
          }
          final invoice = snapshot.data?.data();
          if (invoice == null) return const SizedBox.shrink();
          final total = (invoice['grandTotal'] as num?)?.toDouble() ?? 0;
          final paid = invoice['invoiceStatus'] == 'paid';
          final careComplete =
              widget.serviceJobStatuses.isNotEmpty &&
              widget.serviceJobStatuses.every(
                (status) =>
                    ['completed', 'cancelled', 'blocked'].contains(status),
              );
          final paymentMethod = invoice['paymentMethod']?.toString() ?? '';
          final rawLines = invoice['lines'];
          final lines = rawLines is List
              ? rawLines
                    .whereType<Map>()
                    .map((line) => Map<String, dynamic>.from(line))
                    .toList()
              : const <Map<String, dynamic>>[];
          final orderNumber = invoice['orderNumber']?.toString().trim() ?? '';
          final subOrderNumber = lines
              .map((line) => line['subOrderNumber']?.toString().trim() ?? '')
              .firstWhere((value) => value.isNotEmpty, orElse: () => '');
          return FutureBuilder<ShopPayoutConfig>(
            future: _paymentConfig,
            builder: (context, configSnapshot) {
              final sandboxMode = configSnapshot.data?.sandboxMode == true;
              return Card(
                color: paid ? Colors.white : const Color(0xFFFFF5F8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: paid
                        ? GarmentCareColors.divider
                        : GarmentCareColors.primary,
                    width: paid ? 1 : 1.5,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            paid
                                ? Icons.check_circle_outline_rounded
                                : Icons.priority_high_rounded,
                            color: paid
                                ? const Color(0xFF2C7A46)
                                : GarmentCareColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              paid
                                  ? 'Final invoice paid'
                                  : careComplete
                                  ? 'PAYMENT REQUIRED BEFORE DELIVERY'
                                  : 'CARE IN PROGRESS · PAYMENT NOT DUE',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: paid
                                        ? const Color(0xFF2C7A46)
                                        : GarmentCareColors.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (orderNumber.isNotEmpty || subOrderNumber.isNotEmpty)
                        Text(
                          [
                            if (orderNumber.isNotEmpty) 'Order $orderNumber',
                            if (subOrderNumber.isNotEmpty)
                              'Sub-order $subOrderNumber',
                          ].join(' · '),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      Text(
                        '₹${total.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(
                        'Services ₹${((invoice['serviceSubtotal'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)} · Tax ₹${((invoice['taxTotal'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)} · Pickup/return ₹${((invoice['logisticsTotal'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}',
                      ),
                      if (lines.isNotEmpty)
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          childrenPadding: const EdgeInsets.only(bottom: 8),
                          title: const Text(
                            'Garment DNA, inspection & care report',
                          ),
                          children: [
                            for (final line in lines)
                              _CareInvoiceLineReport(line: line),
                          ],
                        ),
                      if (!paid && careComplete) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'ACTION NEEDED: Pay this invoice to unlock delivery.',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                      const SizedBox(height: 6),
                      if (paid)
                        Text(
                          !careComplete
                              ? 'Payment is recorded, but this garment still has service steps in progress. Delivery unlocks after care is complete.'
                              : paymentMethod.startsWith('sandbox_')
                              ? 'Test payment recorded. No money was moved.'
                              : 'Payment is complete. Your delivery Partner can now hand over the garments.',
                        )
                      else if (!careComplete)
                        const Text(
                          'This invoice cannot be paid yet. The Partner must complete every service step for this garment sub-order first.',
                        )
                      else if (configSnapshot.connectionState !=
                          ConnectionState.done)
                        const LinearProgressIndicator()
                      else if (sandboxMode) ...[
                        const Text(
                          'Test mode · no real money will be charged.',
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _paying
                                ? null
                                : () => _pay(total, invoiceId),
                            icon: _paying
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.payment_rounded),
                            label: Text('Pay ₹${total.toStringAsFixed(2)}'),
                          ),
                        ),
                      ] else
                        const Text(
                          'Online payment is not configured yet. Delivery remains locked until the full invoice is paid.',
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    },
  );

  Widget _invoiceReadError(BuildContext context) => Card(
    color: const Color(0xFFFFF5F8),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Text(
        'We could not load this garment invoice. Please refresh the order; if it still does not appear, contact support.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    ),
  );

  Future<void> _pay(double amount, String invoiceId) async {
    final method = await showDialog<OnlinePaymentMethod>(
      context: context,
      builder: (dialogContext) {
        var selected = OnlinePaymentMethod.upi;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const Text('Complete test payment'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '₹${amount.toStringAsFixed(2)} · test mode · no money will be charged.',
                ),
                const SizedBox(height: 8),
                RadioGroup<OnlinePaymentMethod>(
                  groupValue: selected,
                  onChanged: (value) {
                    if (value != null) setDialogState(() => selected = value);
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final method in OnlinePaymentMethod.values)
                        RadioListTile<OnlinePaymentMethod>(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(method.label),
                          value: method,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, selected),
                child: const Text('Pay in test mode'),
              ),
            ],
          ),
        );
      },
    );
    if (method == null || !mounted) return;
    setState(() => _paying = true);
    try {
      await GarmentCareService.payFinalInvoice(
        invoiceId: invoiceId,
        method: method,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test payment complete. No money was moved.'),
          ),
        );
      }
    } on FirebaseFunctionsException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message ?? 'Could not complete payment.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not complete payment. Check the connection and retry.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }
}

class _CareInvoiceLineReport extends StatelessWidget {
  const _CareInvoiceLineReport({required this.line});

  final Map<String, dynamic> line;

  @override
  Widget build(BuildContext context) {
    final dna = line['garmentDna'] is Map
        ? Map<String, dynamic>.from(line['garmentDna'] as Map)
        : const <String, dynamic>{};
    final inspection = line['inspection'] is Map
        ? Map<String, dynamic>.from(line['inspection'] as Map)
        : const <String, dynamic>{};
    final treatment = line['treatmentRecord'] is Map
        ? Map<String, dynamic>.from(line['treatmentRecord'] as Map)
        : const <String, dynamic>{};
    final observations =
        (inspection['observations'] as List<dynamic>? ?? const [])
            .map((value) => value.toString())
            .where((value) => value.trim().isNotEmpty)
            .join(', ');
    String value(dynamic raw) => raw?.toString().trim() ?? '';
    final dnaFacts = <String>[
      if (value(dna['brand']).isNotEmpty) 'Brand: ${value(dna['brand'])}',
      if (value(dna['material']).isNotEmpty)
        'Material: ${value(dna['material'])}',
      if (value(dna['colour']).isNotEmpty) 'Colour: ${value(dna['colour'])}',
      if (value(dna['pattern']).isNotEmpty) 'Pattern: ${value(dna['pattern'])}',
      if (value(dna['careLabel']).isNotEmpty)
        'Care label: ${value(dna['careLabel'])}',
      'DNA version: ${dna['dnaVersion'] ?? 1}',
    ];
    final treatmentRecorded = value(treatment['methodUsed']).isNotEmpty;
    return Card(
      color: const Color(0xFFFFF8FB),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              [
                if (value(line['subOrderNumber']).isNotEmpty)
                  'Sub-order ${value(line['subOrderNumber'])}',
                value(dna['displayName']).isNotEmpty
                    ? value(dna['displayName'])
                    : 'Garment',
              ].join(' · '),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Service: ${value(line['serviceName']).isNotEmpty ? value(line['serviceName']) : 'Garment care'}',
            ),
            const SizedBox(height: 6),
            const Text(
              'Garment DNA',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(dnaFacts.join(' · ')),
            const SizedBox(height: 6),
            const Text(
              'Inspection',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              [
                    if (value(inspection['condition']).isNotEmpty)
                      value(inspection['condition']),
                    if (observations.isNotEmpty) observations,
                    if (value(inspection['customerMessage']).isNotEmpty)
                      value(inspection['customerMessage']),
                  ].join(' · ').isEmpty
                  ? 'Inspection details were not recorded.'
                  : [
                      if (value(inspection['condition']).isNotEmpty)
                        value(inspection['condition']),
                      if (observations.isNotEmpty) observations,
                      if (value(inspection['customerMessage']).isNotEmpty)
                        value(inspection['customerMessage']),
                    ].join(' · '),
            ),
            const SizedBox(height: 6),
            const Text(
              'Treatment performed',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              treatmentRecorded
                  ? [
                      value(treatment['methodUsed']),
                      if (value(treatment['processDetails']).isNotEmpty)
                        value(treatment['processDetails']),
                      if (value(treatment['finishingDetails']).isNotEmpty)
                        'Finishing: ${value(treatment['finishingDetails'])}',
                      if (value(treatment['qualityNotes']).isNotEmpty)
                        'Quality check: ${value(treatment['qualityNotes'])}',
                    ].join(' · ')
                  : 'Treatment details were not recorded for this older service.',
            ),
          ],
        ),
      ),
    );
  }
}

class GarmentCareDnaScreen extends StatelessWidget {
  const GarmentCareDnaScreen({super.key});

  @override
  Widget build(BuildContext context) => GarmentCareTheme(
    child: Scaffold(
      backgroundColor: GarmentCareColors.background,
      appBar: AppBar(title: const Text('My Garment DNA')),
      body: FutureBuilder<List<GarmentCareIdentity>>(
        future: GarmentCareService.savedGarments(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Could not load your garment records.'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final garments = snapshot.data!;
          if (garments.isEmpty) {
            return const Center(
              child: Text(
                'Garment DNA records will appear here as you add garments to Care orders.',
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Each physical garment keeps one identity across services, orders and Partner handovers.',
              ),
              const SizedBox(height: 12),
              for (final garment in garments)
                Card(
                  color: Colors.white,
                  child: ExpansionTile(
                    leading: const Icon(
                      Icons.checkroom_outlined,
                      color: GarmentCareColors.primary,
                    ),
                    title: Text(garment.displayName),
                    subtitle: Text(
                      [
                            garment.itemTypeCode,
                            garment.material,
                            'DNA v${garment.dnaVersion}',
                          ]
                          .whereType<String>()
                          .where((value) => value.isNotEmpty)
                          .join(' · '),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: StreamBuilder(
                          stream: GarmentCareService.customerGarmentHistory(
                            garment.garmentId,
                          ),
                          builder: (context, historySnapshot) {
                            if (historySnapshot.hasError) {
                              return const Text(
                                'Care history is temporarily unavailable.',
                              );
                            }
                            if (!historySnapshot.hasData) {
                              return const LinearProgressIndicator();
                            }
                            final events = historySnapshot.data!.docs;
                            if (events.isEmpty) {
                              return const Text(
                                'No completed Care services are recorded yet.',
                              );
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final event in events)
                                  Builder(
                                    builder: (context) {
                                      final data = event.data();
                                      final delivered =
                                          data['eventType'] ==
                                          'delivery_completed';
                                      final amount =
                                          (data['paidAmount'] as num?)
                                              ?.toDouble();
                                      final subtitle = delivered
                                          ? [
                                              'Order ${data['orderNumber'] ?? data['orderId'] ?? ''}',
                                              if (amount != null && amount > 0)
                                                'Payment received · ₹${amount.toStringAsFixed(2)}',
                                            ].join(' · ')
                                          : [
                                                  'Order ${data['orderNumber'] ?? data['orderId'] ?? ''}',
                                                  if (data['partnerName'] !=
                                                      null)
                                                    'Partner: ${data['partnerName']}',
                                                  if (data['customerMessage'] !=
                                                      null)
                                                    data['customerMessage']
                                                        .toString(),
                                                  if (data['qualityResult'] ==
                                                      'passed')
                                                    'Quality check passed',
                                                ]
                                                .where(
                                                  (value) => value.isNotEmpty,
                                                )
                                                .join(' · ');
                                      return ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: Icon(
                                          delivered
                                              ? Icons.local_shipping_outlined
                                              : Icons.check_circle_outline,
                                        ),
                                        title: Text(
                                          delivered
                                              ? 'Garment delivered'
                                              : data['serviceName']
                                                        ?.toString() ??
                                                    'Garment Care service',
                                        ),
                                        subtitle: Text(
                                          subtitle,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    },
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}
